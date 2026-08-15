# LiteLLM on GKE

Step 20 of [Step.md](../../Step.md). The componentized `litellm` chart runs
`gateway` (:4000, LLM traffic), `backend` (:4001, management API), and `ui`
(:3000, dashboard) as separate Deployments behind one GKE Ingress.

Everything it depends on already exists in Terraform — Cloud SQL, Memorystore,
the static IP, the certificate, the Google service account, and the Secret
Manager entries. Nothing here changes any of it.

| | |
|---|---|
| Chart | `oci://ghcr.io/berriai/litellm/chart/litellm` 1.96.2 |
| Postgres | Cloud SQL `10.192.0.3`, private IP |
| Redis | Memorystore `10.192.59.227:6379` |
| Endpoint | `https://8.232.205.26.nip.io` |
| Model backend | vLLM on a RunPod GPU pod, called on its public proxy URL |

The model itself runs on RunPod. Nothing on GKE holds a model or needs a GPU —
LiteLLM authenticates callers, enforces budgets and rate limits against Cloud
SQL, resolves an alias, and forwards the request to vLLM.

## Secrets

Terraform generates every value into Secret Manager. External Secrets Operator
syncs them into Kubernetes on a one-hour timer. Nothing is copied by hand.

| Kubernetes Secret | Key | Secret Manager entry |
|---|---|---|
| `litellm-masterkey` | `masterkey` | `terraforge-dev-litellm-master-key` |
| `litellm-db` | `password` | `terraforge-dev-db-password` |
| `litellm-redis` | `password` | `terraforge-dev-redis-password` |
| `litellm-env` | `LITELLM_SALT_KEY` | `terraforge-dev-litellm-salt-key` |
| `litellm-env` | `VLLM_API_KEY` | `terraforge-dev-vllm-api-key` |
| `litellm-env` | `EMBEDDING_API_KEY` | `terraforge-dev-embedding-api-key` |

**To change a value**, add a new version to the Secret Manager entry rather than
editing Terraform:

```bash
printf 'sk-my-own-key' | gcloud secrets versions add \
  terraforge-dev-vllm-api-key --project trisec-lab --data-file=-
```

Terraform keeps managing only the version it created, and every consumer reads
`latest`, so the two do not fight and a later `terraform apply` will not revert
you. ESO picks it up within the refresh interval; force it sooner with
`kubectl -n llm-system annotate externalsecret litellm-env force-sync=$(date +%s) --overwrite`.

The one value never to change is `LITELLM_SALT_KEY`. It encrypts provider
credentials stored in Postgres, so a new version makes every model already
registered unreadable.

Only `terraforge-dev-tailscale-authkey` and `terraforge-dev-hf-token` are still
empty, because Tailscale and Hugging Face issue those — Terraform cannot
generate them.

ESO is needed because the chart takes Secret *references* and cannot read a
mounted file, so a Kubernetes Secret has to exist before the first pod starts.
The GKE Secret Manager CSI add-on only materialises a Secret while a pod is
already mounting the volume, which is too late here.

## Deploy

```bash
kubectl apply -f gke/namespaces.yaml

helm upgrade --install external-secrets \
  oci://ghcr.io/external-secrets/charts/external-secrets \
  --version 2.9.0 -n external-secrets --create-namespace --wait

kubectl apply -f gke/litellm/secrets.yaml

# All four must say SecretSynced before continuing.
kubectl -n llm-system get externalsecret

helm upgrade --install litellm oci://ghcr.io/berriai/litellm/chart/litellm \
  --version 1.96.2 -n llm-system \
  -f gke/litellm/values.yaml --wait --timeout 10m
```

## Verify

```bash
MASTER_KEY=$(gcloud secrets versions access latest \
  --project trisec-lab --secret terraforge-dev-litellm-master-key)

curl -s https://8.232.205.26.nip.io/v1/models -H "Authorization: Bearer $MASTER_KEY"
```

The load balancer takes 5-10 minutes to program, and the managed certificate
15-60 minutes more. Until the cert is `ACTIVE`, use `http://`:

```bash
gcloud compute ssl-certificates describe terraforge-dev-litellm-cert \
  --global --project trisec-lab --format='value(managed.status)'
```

Once it is active, set `kubernetes.io/ingress.allow-http: "false"` in
`values.yaml` and re-run the upgrade.

## Adding the RunPod model

`values.yaml` ships only `smoke-test`. The real model is added after deploying,
from the Admin UI, and `STORE_MODEL_IN_DB` writes it to Cloud SQL encrypted with
`LITELLM_SALT_KEY` — so it survives restarts and redeploys, and this repo never
carries a pod id that changes whenever the pod is recreated.

Reach the UI. Try the Ingress first, and fall back to a port-forward if the
login loops (see the `/*.txt` note below):

```bash
kubectl -n llm-system port-forward svc/litellm-ui 3000:3000   # then http://localhost:3000
```

Log in with the master key:

```bash
gcloud secrets versions access latest \
  --project trisec-lab --secret terraforge-dev-litellm-master-key
```

Then **Models → Add Model**:

| Field | Value |
|---|---|
| Provider | OpenAI-Compatible |
| Model name (public) | `terraform-code-fast` |
| LiteLLM model name | `openai/<what the pod reports at GET /v1/models>` |
| API base | `https://<POD_ID>-8000.proxy.runpod.net/v1` |
| API key | `os.environ/VLLM_API_KEY` |

Set the API key to that **literal string** rather than pasting the secret. The
value is already in the pod environment, straight from Secret Manager, so the
credential never passes through a browser.

The same thing over the management API, if the UI is unreachable:

```bash
MASTER_KEY=$(gcloud secrets versions access latest \
  --project trisec-lab --secret terraforge-dev-litellm-master-key)

curl -X POST https://8.232.205.26.nip.io/model/new \
  -H "Authorization: Bearer $MASTER_KEY" -H 'Content-Type: application/json' \
  -d '{
        "model_name": "terraform-code-fast",
        "litellm_params": {
          "model": "openai/<SERVED_MODEL_NAME>",
          "api_base": "https://<POD_ID>-8000.proxy.runpod.net/v1",
          "api_key": "os.environ/VLLM_API_KEY"
        }
      }'
```

Models added this way are additive to `model_list`, so `smoke-test` stays. Once
the RunPod path is confirmed working, consider moving the model into
`values.yaml` so the repo describes what is actually running.

## Things to know

- **Start vLLM with the generated key.** The RunPod proxy URL is public, so
  `--api-key` is the only thing standing between the internet and your GPU.
  Without it, anyone with the pod id can use the model.

  ```bash
  gcloud secrets versions access latest \
    --project trisec-lab --secret terraforge-dev-vllm-api-key
  ```

  LiteLLM presents the same value as `os.environ/VLLM_API_KEY`, which is already
  in the pod environment.

- **PLAN.md sections 3 and 9 are stale.** They describe reaching vLLM over a
  Tailscale mesh with the backends unreachable from the public internet. What is
  actually deployed calls the RunPod proxy URL directly, egressing through Cloud
  NAT. That is a real difference in posture: the model endpoint is on the
  internet and protected by a bearer token rather than by network isolation.
  Steps 16-19 of Step.md do not apply as written.

- **No embedding model.** `terraform-embed` from PLAN.md section 9 is not
  configured, because only one vLLM pod exists. `EMBEDDING_API_KEY` is in the
  environment already for when one does.
- **The UI may not work behind this Ingress.** The chart's path map is written
  for the AWS Load Balancer Controller and includes `/*.txt`, which GCE cannot
  match (only a trailing `/*` is a wildcard). Requests for the dashboard's
  `.txt` payloads will 404 and the login may loop. The gateway and management
  API are unaffected. If it loops, use
  `kubectl -n llm-system port-forward svc/litellm-ui 3000:3000` and keep the
  public host serving the API only — which is the better posture anyway.
  If GCE rejects the rule outright, the Ingress will not sync at all and
  `kubectl -n llm-system describe ingress litellm` will say so.
- **`LITELLM_SALT_KEY` must never change.** It encrypts provider credentials in
  Postgres; a new value makes every registered model unreadable.
- **Redis is not encrypted in transit.** AUTH is on and traffic stays inside the
  VPC. Deliberate, and documented in `terraform/modules/memorystore/main.tf`.
