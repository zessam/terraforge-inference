# Observability & Evaluation

| Source | Measures | Reaches Grafana / Langfuse via |
|---|---|---|
| LiteLLM `/metrics` | requests, errors, latency, tokens, spend, backend health | Prometheus scrapes (ServiceMonitor) |
| vLLM engine `/metrics` | tokens/s, TTFT, e2e latency, queue, KV cache | Prometheus scrapes (ScrapeConfig) |
| **lm-eval** | quality — accuracy on 4 task suites | pushes `lm_eval_score` → Pushgateway |
| **GuideLLM** | performance under 5 controlled load shapes | pushes `guidellm_metric` → Pushgateway |
| **LiteLLM OTel** | per-request traces: prompt, response, cost, latency | OTLP → Langfuse |

```
LiteLLM /metrics ─┐
vLLM /metrics ────┼─▶ Prometheus ─▶ Grafana (one dashboard, four rows)
Pushgateway ──────┘
   ▲
lm-eval  ── push scores ──┤
GuideLLM ── push report ──┘

LiteLLM ── OTLP ──▶ Langfuse ─▶ Cloud SQL + Memorystore + GCS + ClickHouse
```

Metrics tell you the error rate rose. Evals tell you the model got worse after a
change. Only a trace tells you what it actually said — to Prometheus, a
confidently wrong answer is indistinguishable from a correct one.

## Files

| File | What it is |
|---|---|
| `kube-prom-stack-values.yaml` | values for the upstream Prometheus/Grafana chart |
| `pushgateway.yaml` | Deployment + Service + ServiceMonitor — sink for batch metrics |
| `servicemonitor-litellm.yaml` | scrape LiteLLM `/metrics` + scoped RBAC for the master key |
| `scrapeconfig-vllm.yaml` | scrape the RunPod engine; needs the pod host filled in |
| `dashboard.yaml` | the Grafana dashboard |
| `eval-scripts.yaml` | push logic, mounted by every eval Job |
| `lm-eval-job.yaml` | 4 quality suites, one Job each |
| `guidellm-job.yaml` | 5 performance profiles, one Job each |
| `langfuse.yaml` | Langfuse ServiceAccount + SecretStore + ExternalSecret |
| `langfuse-values.yaml` | values for the upstream Langfuse chart |

## Deploy

Via the pipeline: **Actions → Observability → Run workflow**, pick `deploy`,
then approve on `production`. The `action` dropdown also offers `run-eval` and
`uninstall`.

Manual equivalent:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prom-stack prometheus-community/kube-prometheus-stack \
  --version 87.17.0 -n observability --create-namespace \
  -f observability/kube-prom-stack-values.yaml --wait

kubectl apply -f observability/pushgateway.yaml
kubectl apply -f observability/servicemonitor-litellm.yaml
kubectl apply -f observability/dashboard.yaml
kubectl apply -f observability/eval-scripts.yaml
kubectl apply -f observability/langfuse.yaml
```

kube-prometheus-stack goes first: it owns the ServiceMonitor, PrometheusRule,
and ScrapeConfig CRDs the rest are instances of.

Langfuse itself is deployed by its own pipeline (**Actions → Langfuse Deploy**)
from `langfuse-values.yaml` — it runs database migrations on upgrade and holds a
ClickHouse PVC, so it does not belong in a monitoring redeploy.

For the engine scrape, put the RunPod pod host in `scrapeconfig-vllm.yaml` and
apply it. It is left out of the deploy above on purpose: as shipped it carries a
placeholder that would scrape nothing forever.

## Running the evaluations

**After** vLLM is serving and LiteLLM has the model registered.

```bash
kubectl create -n observability -f observability/lm-eval-job.yaml    # all 4 quality suites
kubectl create -n observability -f observability/guidellm-job.yaml   # all 5 load profiles
kubectl logs -n observability -l eval/kind=lm-eval -f
```

**`create`, never `apply`.** Every Job uses `generateName`, so each run produces
a new object with a unique suffix — which is how you re-run without deleting
anything. A finished Job is immutable, and `apply` does not work with
`generateName` at all.

Or from the pipeline: **Observability → `run-eval`**, with `all` or one name
(`code`, `reasoning`, `instruction`, `truthfulness`, `chat-steady`,
`rag-longprompt`, `codegen-longoutput`, `burst-poisson`, `sweep-capacity`).

Nothing is scheduled. Evals put real load on the model and the gateway, so
running them is a decision.

## Tracing with OpenTelemetry

LiteLLM exports traces over OTLP; Langfuse ingests OTLP directly at
`/api/public/otel`. One standard protocol rather than a vendor callback, so
swapping Langfuse for another backend later is an endpoint change.

Two-step, because Langfuse issues its own keys and Terraform cannot generate
them:

1. Deploy Langfuse, port-forward the UI, sign up, create a project, copy the
   public and secret keys.
2. Store the endpoint and auth header, then uncomment the `otel` callback in
   `gke/litellm/values.yaml` and the `OTEL_*` entries in
   `gke/litellm/secrets.yaml`:

```bash
printf 'pk-lf-...:sk-lf-...' | base64 -w0            # -> AUTH
printf 'Authorization=Basic <AUTH>' | gcloud secrets create \
  terraforge-dev-langfuse-otel-headers --data-file=- --project trisec-lab
```

Enabling the callback before the credentials exist stops the proxy from
starting, so do it in that order.

Langfuse holds full prompt and response text. To keep the metadata and drop the
content, set `turn_off_message_logging: True` in `litellm_settings`.

## Reaching the UIs

```bash
kubectl get svc kube-prom-stack-grafana -n observability   # wait for EXTERNAL-IP
kubectl get secret kube-prom-stack-grafana -n observability \
  -o jsonpath="{.data.admin-password}" | base64 -d; echo

kubectl -n observability port-forward svc/langfuse-web 3000:3000
```

Grafana user is `admin`; the dashboard is **LLM Quality & Performance**. Langfuse
is not exposed — it stores every prompt, so it stays behind a port-forward
unless you deliberately expose it (see `langfuse-values.yaml`).

## Requirements that are easy to miss

- **LiteLLM emits no metrics without `callbacks: ["prometheus"]`** in its proxy
  config. The Gateway row is then empty rather than zero, because the series do
  not exist at all.
- **That `/metrics` endpoint needs a bearer token** from LiteLLM v1.85.0 onward,
  and its ingress routes `/metrics` publicly. The ServiceMonitor authenticates
  with the master key, which is why it lives in `llm-system` — the Prometheus
  operator resolves `bearerTokenSecret` in the ServiceMonitor's own namespace.
- **Jobs are immutable.** Use `kubectl create`, not `apply`.
- **The Pushgateway keeps its last value forever.** A flat line on the quality
  panels means nobody ran an eval, not a stable score. Check the run-timestamp
  panel first.
- **Eval limits are samples** — 50-100 per task catches a regression; it is not
  enough to publish a number.

## Security

Grafana is a public LoadBalancer with a chart-generated admin password. The
Pushgateway is **ClusterIP with no auth** — anything in the cluster can write
arbitrary metrics, including forged eval results, so it must not be exposed. The
eval Jobs `pip install` at runtime with pinned versions; a prebuilt image would
be the hardened form, at the cost of needing a registry.

Alert rules are not included. Prometheus is scraping and Alertmanager is running
from the chart, but nothing routes anywhere — add rules and a receiver when you
know which thresholds are worth waking up for.
