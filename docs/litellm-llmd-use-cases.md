# LiteLLM And llm-d Use Cases

## Short Decision

For the first version, run LiteLLM in front of one vLLM service.

Keep llm-d as an optional phase-2 serving layer. With only one model and one vLLM service, llm-d can be deployed, but it will not add much value yet because its strongest benefits come from routing and optimizing traffic across multiple workers, replicas, or distributed serving patterns.

## LiteLLM Use Cases We Can Build Now

### 1. Terraform Code Model Gateway

Expose one stable endpoint for Terraform generation:

- `terraform-code-fast`
- `terraform-rag-answer`
- `terraform-eval`

The future LangChain agent calls LiteLLM only. LiteLLM decides which backend model serves the request.

### 2. Provider And Backend Abstraction

Hide the real backend from clients.

Possible backends:

- local vLLM.
- llm-d later.
- hosted fallback provider.
- separate embedding endpoint.

This lets us change models or serving engines without changing agent code.

### 3. Terraform RAG Embeddings Gateway

Expose embeddings through LiteLLM for future RAG ingestion and retrieval.

Future documents:

- Terraform provider docs.
- internal Terraform modules.
- cloud architecture standards.
- platform runbooks.
- security policy docs.

### 4. Model Aliasing By Task

Use task names instead of raw model names.

Recommended aliases:

- `terraform-code-fast`
- `terraform-code-deep`
- `terraform-rag-answer`
- `terraform-embed`
- `terraform-review`
- `terraform-policy-explain`

### 5. Fallback And Resilience

Configure fallback paths:

```text
terraform-code-fast -> vLLM
terraform-code-deep -> llm-d later
terraform-rag-answer -> vLLM, fallback to external provider
```

This is useful for demos because we can show that the gateway protects the agent from backend outages.

### 6. Budget And Rate Control

Terraform agents can burn tokens quickly because they retrieve context, plan, revise, and validate.

LiteLLM should enforce:

- per-key budgets.
- requests per minute.
- tokens per minute.
- model access rules.
- separate dev and prod limits.

### 7. Multi-Tenant Platform Demo

Create multiple logical consumers:

- `terraform-agent-dev`
- `terraform-agent-prod`
- `eval-runner`
- `platform-admin`

Each gets different models, budgets, and rate limits.

### 8. Observability And Evaluation

Use LiteLLM logs and callbacks to track:

- prompts.
- selected model.
- latency.
- token usage.
- cost estimates.
- fallback events.
- errors.

Later, this can feed Langfuse, Prometheus, Grafana, or another observability stack.

### 9. Caching For Repeated Terraform Queries

Useful cache examples:

- common module examples.
- provider resource explanations.
- repeated documentation Q&A.
- common error explanations.

Avoid caching prompts that include secrets, customer data, or private infrastructure details.

### 10. Guardrail Boundary

LiteLLM can provide gateway-level controls before the agent layer exists.

Initial guardrails:

- reject obvious secrets in prompts.
- redact sensitive outputs.
- restrict model access by key.
- require JSON output for selected evaluation tasks.

Terraform-specific validation still belongs later in the agent/runtime layer.

### 11. MCP Gateway Readiness

Keep MCP as a future integration, but align the gateway around the same access-control model.

Future MCP servers:

- GitHub MCP.
- docs/files MCP.
- Terraform Registry MCP.
- cloud docs MCP.
- policy tools MCP.
- CI/CD MCP.

LiteLLM can become the common control point for LLMs, MCP access, keys, teams, and usage tracking.

## llm-d Use Cases We Can Build Later

### 1. Multiple vLLM Replicas For The Same Model

When traffic grows, run several vLLM workers serving the same model.

llm-d can then help with:

- intelligent request routing.
- load-aware scheduling.
- cache-aware routing.
- saturation handling.

### 2. Prefix-Cache-Aware Routing

Terraform RAG often has repeated prefixes:

- system prompts.
- coding standards.
- provider docs.
- module context.
- policy instructions.

With multiple workers, llm-d can route similar-prefix requests to the worker most likely to reuse cache.

### 3. Autoscaling Inference Pools

Use llm-d when we need model-serving autoscaling rather than one static vLLM deployment.

Good trigger:

- multiple concurrent users.
- CI eval jobs.
- batch code-review workloads.
- latency-sensitive agent traffic.

### 4. Prefill/Decode Disaggregation

Useful for long-context RAG prompts where prefill cost dominates.

This is likely phase 3 or later, not first deployment.

### 5. Fairness And Flow Control

Useful when multiple workloads share the same model pool:

- interactive agent requests.
- batch evals.
- Terraform module generation.
- documentation Q&A.

llm-d can help separate high-priority interactive traffic from lower-priority batch work.

### 6. Multi-Node Or Multi-GPU Serving

Use llm-d when the chosen model or traffic pattern needs more than a single vLLM pod.

Examples:

- larger code model.
- higher concurrency.
- multi-GPU tensor parallelism.
- multi-host serving.
- mixture-of-experts serving.

## Should We Use llm-d With One Model And One vLLM Service?

### Practical Answer

Not for the first version.

With one model and one vLLM service, LiteLLM plus vLLM is enough:

```text
Client / Future LangChain Agent
    |
    v
LiteLLM
    |
    v
vLLM
```

llm-d can technically sit between LiteLLM and vLLM, but with only one backend worker there is almost nothing meaningful to route, balance, or optimize.

### Better First Architecture

```text
Ingress
    |
    v
LiteLLM
    |
    +--> vLLM chat/code model
    +--> embedding model
```

### When To Add llm-d

Add llm-d when one of these becomes true:

- we run two or more vLLM replicas.
- we need cache-aware routing.
- we need inference-specific autoscaling.
- we need fairness between agent, eval, and batch jobs.
- we serve a model across multiple GPUs or nodes.
- we want to test prefill/decode disaggregation.

## Recommended Project Path

### Phase 1

- k3s on RunPod.
- vLLM model service.
- embedding service.
- LiteLLM gateway.
- ingress only to LiteLLM.
- API keys, aliases, budgets, rate limits.
- basic logs and smoke tests.

### Phase 2

- add a second vLLM replica or second model.
- introduce llm-d routing.
- compare direct LiteLLM-to-vLLM versus LiteLLM-to-llm-d.
- measure latency, throughput, and failure handling.

### Phase 3

- add prefix-cache-aware routing.
- add autoscaling.
- add batch/eval workloads.
- add distributed serving if needed.

## Recommended Decision For This Repo

Document llm-d as a planned scaling layer, not a required dependency for the first demo.

The strongest initial use case is:

```text
LiteLLM inference gateway for a future Terraform RAG agent,
served by vLLM now,
designed so llm-d can be inserted later when scale requires it.
```

## References

- LiteLLM gateway docs: <https://docs.litellm.ai/>
- llm-d project: <https://llm-d.ai/>
- llm-d Kubernetes/distributed inference overview: <https://llm-d.ai/docs/0.7>
- llm-d no-Kubernetes deployment notes: <https://llm-d.ai/docs/infrastructure/no-kubernetes-deployment>
- vLLM Kubernetes deployment docs: <https://docs.vllm.ai/en/latest/deployment/k8s/>
