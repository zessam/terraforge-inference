# Project Name: terraforge-inference

## 1. Objective

`terraforge-inference` is the inference foundation for a future LangChain RAG agent that writes, explains, reviews, and validates Terraform code.

This project does not build the agent yet. It builds the production-style inference layer the agent will consume later.

The phase-1 platform includes:

- RunPod GPU compute.
- k3s as the Kubernetes runtime.
- LiteLLM as the public inference gateway.
- vLLM serving one chat/code LLM.
- one embedding model service for future RAG.
- PostgreSQL for LiteLLM persistence.
- monitoring and observability.
- ingress or RunPod public access.
- CI/CD deployment.
- smoke tests.
- security, secrets, storage, and runbooks.

## 2. Final Phase-1 Architecture

```text
User / Future LangChain RAG Agent
    |
    v
RunPod HTTP Proxy or k3s Traefik Ingress
    |
    v
LiteLLM Gateway
    |
    +--> vLLM Service
    |       |
    |       v
    |   Terraform Chat/Code LLM
    |
    +--> Embedding Service
            |
            v
        RAG Embedding Model
```

Only LiteLLM should be reachable from outside the cluster.

Private services:

- vLLM.
- embedding service.
- PostgreSQL.
- Prometheus.
- model cache storage.

Optionally public:

- Grafana, only with authentication.

## 3. Core Design Decisions

### LiteLLM

Use LiteLLM as the inference control plane.

LiteLLM provides:

- OpenAI-compatible API.
- stable model aliases.
- API keys.
- virtual keys.
- per-key model access.
- budgets.
- rate limits.
- usage tracking.
- logging.
- future fallback routing.
- future observability callbacks.

The future LangChain agent must call LiteLLM only. It should not call vLLM or the embedding model directly.

### vLLM

Use vLLM to serve the primary chat/code model.

Use cases:

- Terraform generation.
- Terraform explanation.
- Terraform review.
- RAG answer generation.
- cloud provider and module guidance.

Suggested LiteLLM aliases:

- `terraform-code-fast`
- `terraform-rag-answer`
- `terraform-review`

### Embedding Model

Use a separate embedding service behind LiteLLM.

Use cases later:

- Terraform provider documentation embeddings.
- internal module embeddings.
- security policy embeddings.
- architecture standards embeddings.
- runbook embeddings.

Suggested LiteLLM alias:

- `terraform-embed`

The vector database and document ingestion pipeline are not included in phase 1.

### llm-d

Do not deploy llm-d in phase 1.

With one LLM model and one vLLM service, llm-d is overengineering. It becomes useful when there are multiple vLLM replicas, high concurrency, distributed serving, cache-aware routing, or multi-GPU/multi-node serving.

Keep llm-d as phase 2 or phase 3:

```text
LiteLLM
    |
    v
llm-d
    |
    +--> vLLM worker 1
    +--> vLLM worker 2
    +--> vLLM worker N
```

Add llm-d only when metrics show a real need.

### MCP

Do not implement MCP servers in phase 1.

MCPs are tool interfaces for the future agent. Prepare for them, but do not build them until the LangChain RAG agent exists.

Prepare now:

- `mcp/README.md`.
- `mcp` namespace.
- future MCP candidate list.
- private-service assumption.

Future MCP candidates:

- GitHub MCP.
- filesystem/docs MCP.
- Terraform Registry MCP.
- cloud docs MCP.
- tflint/checkov/policy MCP.
- CI/CD MCP.

## 4. Required Runtime Components

The minimum working platform needs these components:

- RunPod GPU pod.
- k3s.
- Traefik ingress, included by default in k3s.
- NVIDIA device plugin.
- LiteLLM.
- PostgreSQL.
- vLLM.
- embedding service.
- persistent volumes.
- Kubernetes secrets.
- Prometheus.
- Grafana.
- NVIDIA DCGM exporter.
- kube-state-metrics.
- node-exporter.
- CI/CD workflow.
- smoke test scripts.

Optional later components:

- Loki or Grafana Alloy for centralized logs.
- Langfuse for LLM traces and prompt analytics.
- cert-manager when a domain exists.
- llm-d when scaling is needed.
- vector database when RAG ingestion starts.

## 5. Public Access And Ingress

LiteLLM does not provide ingress. It is an LLM gateway, not a Kubernetes ingress controller.

Because there is no domain right now, start with RunPod HTTP proxy.

Example phase-1 endpoint:

```text
https://<pod-id>-4000.proxy.runpod.net
```

API paths:

```text
POST https://<pod-id>-4000.proxy.runpod.net/v1/chat/completions
POST https://<pod-id>-4000.proxy.runpod.net/v1/embeddings
GET  https://<pod-id>-4000.proxy.runpod.net/v1/models
```

If two logical links are wanted later, keep both routed through LiteLLM:

```text
https://llm.example.com/v1/chat/completions
https://embed.example.com/v1/embeddings
```

Without a domain, use one RunPod URL and separate traffic by API path plus LiteLLM model alias.

Later options:

- Traefik ingress with temporary DNS such as `sslip.io` or `nip.io`.
- Cloudflare Tunnel.
- real domain plus cert-manager TLS.

## 6. Storage Requirements

Use persistent storage for:

- Hugging Face model cache.
- vLLM model cache.
- embedding model cache.
- PostgreSQL data.
- Grafana dashboards and configuration.
- Prometheus data, if metrics retention matters.

Recommended volumes:

```text
model-cache-pvc
postgres-pvc
grafana-pvc
prometheus-pvc
```

If RunPod storage is not persistent, document that the environment must be bootstrapped again after pod recreation.

## 7. Secrets Requirements

Do not commit real secrets.

Kubernetes secrets:

- `HF_TOKEN`
- `LITELLM_MASTER_KEY`
- `LITELLM_SALT_KEY`
- `DATABASE_URL`
- `POSTGRES_PASSWORD`
- `VLLM_API_KEY`, if used internally.
- `EMBEDDING_API_KEY`, if used internally.

GitHub Actions secrets:

- `RUNPOD_HOST`
- `RUNPOD_SSH_USER`
- `RUNPOD_SSH_PRIVATE_KEY`
- `LITELLM_MASTER_KEY`
- `LITELLM_SALT_KEY`
- `HF_TOKEN`
- `POSTGRES_PASSWORD`

Add only `*.example.yaml` secret templates to the repo.

## 8. Model Selection

Choose the model based on actual GPU VRAM.

Suggested first LLM options:

- `Qwen/Qwen2.5-Coder-7B-Instruct`
- `Qwen/Qwen2.5-7B-Instruct`
- `mistralai/Mistral-7B-Instruct`
- `meta-llama/Llama-3.1-8B-Instruct`, if access and memory allow.

Suggested embedding model options:

- `BAAI/bge-small-en-v1.5`
- `BAAI/bge-base-en-v1.5`
- `intfloat/e5-base-v2`
- `sentence-transformers/all-MiniLM-L6-v2`

Resource guidance:

- prioritize GPU for vLLM.
- run embeddings on CPU first if GPU memory is limited.
- move embeddings to GPU only if embedding latency becomes a bottleneck.

## 9. LiteLLM Configuration

Required aliases:

- `terraform-code-fast`
- `terraform-rag-answer`
- `terraform-review`
- `terraform-embed`

Required key types:

- `admin-key`
- `agent-dev-key`
- `agent-prod-key`
- `eval-key`
- `embedding-key`

Recommended access policy:

- `admin-key`: all models and management access.
- `agent-dev-key`: `terraform-code-fast`, `terraform-rag-answer`, `terraform-embed`.
- `agent-prod-key`: production aliases only.
- `eval-key`: review/eval aliases.
- `embedding-key`: `terraform-embed` only.

Required controls:

- per-key request limits.
- per-key token limits.
- model allowlists.
- monthly budget values.
- usage logging.

## 10. Monitoring And Observability

Base stack:

```text
Prometheus
Grafana
kube-state-metrics
node-exporter
NVIDIA DCGM exporter
vLLM metrics scrape
LiteLLM metrics/logs
```

Add later:

```text
Loki or Grafana Alloy
Langfuse
OpenTelemetry
```

Dashboards:

- Cluster Health.
- GPU Utilization.
- LiteLLM Gateway.
- vLLM Serving.
- Embedding Service.
- Ingress/API Traffic.
- Cost And Token Usage.

Critical alerts:

- GPU memory above 90%.
- vLLM pod restarts.
- LiteLLM unavailable.
- LiteLLM error rate above 5%.
- p95 latency too high.
- embedding failure rate above 5%.
- PostgreSQL unavailable.
- disk usage above 80%.
- model cache nearly full.
- API key budget exceeded.

## 11. CI/CD

Use GitHub Actions for phase 1.

Recommended workflow:

```text
push to main
    |
    +--> lint YAML
    +--> validate Kubernetes manifests
    +--> build custom images, if any
    +--> push images to registry, if any
    +--> SSH into RunPod
    +--> kubectl apply -f manifests/
    +--> wait for rollouts
    +--> run smoke tests
```

Assumptions:

- RunPod pod is already running.
- k3s is already installed.
- SSH is available.
- kubeconfig works on the RunPod host.

Smoke tests:

- `GET /v1/models`.
- `POST /v1/chat/completions` using `terraform-code-fast`.
- `POST /v1/embeddings` using `terraform-embed`.

## 12. Security

Security rules:

- expose LiteLLM only.
- require LiteLLM API keys.
- keep raw model services private.
- keep PostgreSQL private.
- keep Prometheus private.
- protect Grafana with authentication if exposed.
- never commit real secrets.
- do not log secrets in prompts.
- use separate keys for chat, embeddings, eval, and admin.
- rotate keys through LiteLLM and Kubernetes secrets.

## 13. Backup And Recovery

Back up:

- LiteLLM PostgreSQL data.
- LiteLLM config.
- Kubernetes manifests.
- Grafana dashboards.
- Prometheus alert rules.

Model cache does not need backup if models can be downloaded again, but losing it will slow recovery.

Required runbooks:

- bootstrap RunPod and k3s.
- redeploy all manifests.
- rotate LiteLLM keys.
- restart vLLM.
- update LLM model.
- update embedding model.
- check GPU usage.
- debug failed pods.
- restore PostgreSQL.
- rerun smoke tests.

## 14. Repository Structure

```text
terraforge-inference/
    README.md
    PLAN.md
    docs/
        architecture.md
        observability.md
        inference-scope.md
        litellm-config.md
        llmd-decision.md
        mcp-readiness.md
        runpod-networking.md
        cicd.md
        runbooks.md
        demo-script.md
    infra/
        k3s-bootstrap.md
        runpod-setup.md
    manifests/
        namespaces.yaml
        storage/
        ingress/
        observability/
        postgres/
    litellm/
        config.yaml
        deployment.yaml
        service.yaml
        secrets.example.yaml
    models/
        vllm-deployment.yaml
        vllm-service.yaml
        embedding-deployment.yaml
        embedding-service.yaml
    mcp/
        README.md
    scripts/
        deploy.sh
        smoke-litellm.sh
        smoke-embeddings.sh
        check-gpu.sh
    .github/
        workflows/
            deploy-runpod.yml
```

## 15. Deployment Order

Deploy in this order:

1. RunPod pod.
2. k3s.
3. NVIDIA device plugin.
4. namespaces.
5. secrets.
6. persistent volumes.
7. PostgreSQL.
8. vLLM.
9. embedding service.
10. LiteLLM.
11. public access through RunPod proxy or ingress.
12. Prometheus and Grafana.
13. dashboards and alerts.
14. CI/CD workflow.
15. smoke tests.

## 16. Step-By-Step Build Plan

### Step 1: Create Repo

- Create repo as `terraforge-inference`.
- Add the folder structure.
- Add `README.md`.
- Add `PLAN.md`.
- Add architecture and decision docs.

### Step 2: Prepare RunPod

- Select a GPU pod based on the chosen LLM.
- Enable enough persistent storage for model cache.
- Confirm SSH access.
- Decide which external port maps to LiteLLM.
- Record the RunPod proxy URL.

### Step 3: Install k3s

- Install k3s.
- Keep default Traefik for now.
- Confirm `kubectl get nodes`.
- Confirm CoreDNS and Traefik pods are running.

### Step 4: Add GPU Support

- Install NVIDIA device plugin.
- Confirm GPU resources are visible to Kubernetes.
- Run a GPU test pod if needed.

### Step 5: Add Namespaces And Secrets

- Create namespaces:
  - `llm-system`
  - `models`
  - `observability`
  - `mcp`
- Create Kubernetes secrets from local values or CI/CD.

### Step 6: Add Persistent Storage

- Create PVCs for:
  - model cache.
  - PostgreSQL.
  - Grafana.
  - Prometheus.

### Step 7: Deploy PostgreSQL

- Deploy PostgreSQL for LiteLLM.
- Attach persistent storage.
- Keep it private.
- Verify LiteLLM can connect.

### Step 8: Deploy vLLM

- Deploy the selected chat/code model.
- Mount model cache.
- Request GPU resources.
- Expose as internal service only.
- Test from inside the cluster.

### Step 9: Deploy Embedding Service

- Deploy selected embedding model.
- Start CPU-first unless GPU capacity is available.
- Expose as internal service only.
- Test embeddings from inside the cluster.

### Step 10: Deploy LiteLLM

- Register vLLM backend.
- Register embedding backend.
- configure aliases.
- configure master key.
- configure virtual keys.
- configure budgets.
- configure rate limits.
- connect to PostgreSQL.

### Step 11: Configure Public Access

- Expose LiteLLM through RunPod HTTP proxy first.
- If needed, add Traefik ingress.
- Do not expose vLLM or embeddings directly.

### Step 12: Add Monitoring

- Deploy Prometheus.
- Deploy Grafana.
- Deploy kube-state-metrics.
- Deploy node-exporter.
- Deploy NVIDIA DCGM exporter.
- Add vLLM scrape config.
- Add LiteLLM dashboard.
- Add GPU dashboard.
- Add alerts.

### Step 13: Add CI/CD

- Add GitHub Actions deploy workflow.
- Store secrets in GitHub Actions.
- SSH into RunPod.
- Apply manifests.
- Wait for rollouts.
- Run smoke tests.

### Step 14: Add Runbooks

- Add operations documentation.
- Include restart, recovery, debugging, key rotation, and model update instructions.

### Step 15: Freeze Phase-1 Scope

- Do not build LangChain agent.
- Do not build vector DB ingestion.
- Do not build MCP servers.
- Do not deploy llm-d.
- Document all of these as later phases.

## 17. Success Criteria

Phase 1 is complete when:

- RunPod is running k3s.
- Kubernetes can see the GPU.
- vLLM serves the selected chat/code model.
- the embedding service serves embeddings.
- LiteLLM exposes both through OpenAI-compatible endpoints.
- LiteLLM requires API keys.
- model aliases work.
- budgets and rate limits are configured.
- PostgreSQL persists LiteLLM state.
- vLLM and embeddings are not public.
- LiteLLM is reachable through RunPod proxy or ingress.
- Prometheus and Grafana show cluster, GPU, LiteLLM, and vLLM health.
- CI/CD can deploy manifests.
- smoke tests pass for models, chat, and embeddings.

## 18. Future Phases

### Phase 2: RAG Foundation

- choose vector database.
- build document ingestion.
- index Terraform docs and internal modules.
- test retrieval quality.

### Phase 3: Agent

- build LangChain RAG agent.
- connect to LiteLLM.
- connect to vector DB.
- add Terraform validation.
- add repo-aware context.

### Phase 4: MCP Tools

- deploy MCP servers.
- connect agent to MCP tools.
- add GitHub/docs/Terraform Registry integrations.

### Phase 5: Scale With llm-d

- add multiple vLLM replicas.
- evaluate llm-d.
- test routing, fairness, and cache-aware scheduling.
- add autoscaling if metrics justify it.

## 19. Final Recommended First Build

Build this first:

```text
RunPod GPU Pod
    |
    v
k3s
    |
    +--> LiteLLM + PostgreSQL
    |       |
    |       +--> vLLM chat/code model
    |       |
    |       +--> embedding model service
    |
    +--> Prometheus
    +--> Grafana
    +--> NVIDIA DCGM exporter
```

This is the cleanest useful foundation. It is strong enough for a future Terraform RAG agent, but it avoids premature complexity from llm-d, MCP tools, and vector ingestion.
