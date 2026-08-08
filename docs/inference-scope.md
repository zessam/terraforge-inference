# Inference Scope

## Target Future Use Case

The future application is an agentic RAG system built with LangChain that helps write Terraform code.

This phase does not build the agent. It builds the inference platform the agent will call later.

## What We Build Now

The current project should expose one production-style inference gateway:

```text
LangChain agent, later
    |
    v
LiteLLM Gateway
    |
    +--> code/chat model on vLLM
    +--> code/chat model on llm-d
    +--> embedding model for RAG
    +--> optional fallback provider
```

LiteLLM is the main control plane. The agent should never call vLLM, llm-d, or external providers directly.

## LiteLLM Integrations To Implement

### 1. OpenAI-Compatible Gateway

Expose LiteLLM through `/v1/chat/completions`, `/v1/responses`, and `/v1/embeddings` where supported.

Why this matters:

- LangChain can call the platform through a standard LLM interface.
- Client code can switch models without changing endpoint logic.
- vLLM and llm-d remain private Kubernetes services.

### 2. vLLM Backend

Register vLLM as the first self-hosted model backend.

Recommended role:

- Fast code assistant model.
- Terraform generation.
- Terraform explanation.
- Small-to-medium RAG answer generation.

Suggested LiteLLM alias:

- `terraform-code-fast`

### 3. llm-d Backend

Register llm-d as a second self-hosted backend.

Recommended role:

- Larger or distributed serving path.
- Higher-concurrency model endpoint.
- Fallback from vLLM when vLLM is overloaded.

Suggested LiteLLM alias:

- `terraform-code-scaled`

### 4. Embeddings Backend For RAG

Add an embedding model behind LiteLLM.

Recommended role:

- Terraform docs embeddings.
- Internal module embeddings.
- Cloud provider documentation embeddings.
- Runbook and platform documentation embeddings.

Suggested LiteLLM alias:

- `terraform-embed`

The vector database is not part of LiteLLM. For the later RAG system, use something like Qdrant, pgvector, Milvus, Weaviate, or OpenSearch. In this phase, only expose a stable embedding endpoint.

### 5. Model Aliases

Use task-based names instead of provider-specific names.

Recommended aliases:

- `terraform-code-fast`
- `terraform-code-scaled`
- `terraform-rag-answer`
- `terraform-embed`
- `terraform-eval`

This lets the future LangChain code call stable names while the platform team changes the actual backend models.

### 6. Routing And Fallbacks

Configure LiteLLM routing so the gateway can handle backend failure or capacity limits.

Recommended routing behavior:

- Primary: vLLM for normal Terraform code generation.
- Secondary: llm-d for high load or larger model needs.
- Optional fallback: external provider for emergency continuity.

Example behavior:

```text
terraform-code-fast -> vLLM
terraform-code-scaled -> llm-d
terraform-rag-answer -> vLLM, fallback to llm-d
```

### 7. Virtual Keys And Access Control

Use LiteLLM virtual keys for future consumers.

Recommended keys:

- `agent-dev-key`
- `agent-prod-key`
- `eval-key`
- `admin-key`

Add model access restrictions:

- Dev agent can access lower-cost aliases.
- Prod agent can access production aliases.
- Eval jobs can access eval aliases.
- Admin key can manage gateway configuration.

### 8. Budgets And Rate Limits

Set budgets even before the agent exists.

Recommended controls:

- per-key token budget.
- per-key request rate.
- per-model limits.
- monthly reset for demos.

This is a strong LiteLLM use case because Terraform-writing agents can become expensive if retrieval or planning loops are not controlled.

### 9. Observability

Capture inference behavior from day one.

Track:

- request count.
- token usage.
- latency.
- errors.
- selected model alias.
- fallback events.
- key/team usage.

Good later integrations:

- Langfuse for LLM traces.
- Prometheus and Grafana for platform metrics.
- Loki for gateway and model logs.

### 10. Caching

Add response caching or semantic caching after the basic gateway works.

Useful cache candidates:

- Terraform explanation prompts.
- documentation Q&A.
- repeated module examples.
- common cloud resource snippets.

Do not cache sensitive prompts or secrets.

### 11. Guardrails

Add simple guardrails at the gateway level.

Recommended initial checks:

- block secrets in prompts and outputs where possible.
- reject requests asking to expose credentials.
- tag generated Terraform as generated content.
- require structured output for code review/evaluation tasks.

Deep Terraform validation should happen later in the agent layer using `terraform fmt`, `terraform validate`, policy checks, and sandboxed plans.

### 12. MCP Readiness

Do not build MCP tools yet, but design the inference gateway so MCP-enabled agents can use it later.

Future MCP integrations:

- GitHub MCP for reading Terraform modules and pull requests.
- filesystem or document MCP for repo knowledge.
- cloud documentation MCP.
- Terraform registry MCP or search tool.
- policy/checkov/tflint MCP wrapper.

For this phase, document the intended MCP namespace and keep MCP servers private. The agent can later combine MCP tool calls with LiteLLM inference.

## Minimal Inference Deliverable

The first usable milestone should include:

- LiteLLM deployed on k3s.
- HTTPS ingress to LiteLLM only.
- vLLM backend registered.
- llm-d backend registered or stubbed.
- embedding model endpoint registered.
- model aliases configured.
- virtual keys configured.
- basic budgets and rate limits.
- logs and metrics enabled.
- OpenAI-compatible smoke tests.
- LangChain-compatible smoke test using the LiteLLM endpoint.

## Example LiteLLM Model Map

```yaml
model_list:
  - model_name: terraform-code-fast
    litellm_params:
      model: openai/local-code-model
      api_base: http://vllm.models.svc.cluster.local:8000/v1
      api_key: os.environ/VLLM_API_KEY

  - model_name: terraform-code-scaled
    litellm_params:
      model: openai/local-scaled-code-model
      api_base: http://llmd.models.svc.cluster.local:8000/v1
      api_key: os.environ/LLMD_API_KEY

  - model_name: terraform-embed
    litellm_params:
      model: openai/local-embedding-model
      api_base: http://embedding.models.svc.cluster.local:8000/v1
      api_key: os.environ/EMBEDDING_API_KEY
```

## Later Agent Flow

```text
User asks for Terraform
    |
    v
LangChain agent
    |
    +--> retrieve docs from vector DB
    +--> call MCP tools for repo/cloud context
    +--> call LiteLLM alias terraform-rag-answer
    +--> validate generated Terraform
    +--> return code plus explanation
```

## Out Of Scope For This Phase

- No LangChain agent implementation.
- No Terraform code execution service.
- No vector database ingestion pipeline.
- No MCP server implementation.
- No UI.
- No cloud credentials automation.

## Reference Docs

- LiteLLM gateway, proxy, routing, budgets, callbacks, and OpenAI-compatible endpoints: <https://docs.litellm.ai/>
- LangChain LiteLLM integration: <https://docs.langchain.com/oss/python/integrations/providers/litellm>
- LangChain ChatLiteLLM and ChatLiteLLMRouter: <https://docs.langchain.com/oss/python/integrations/chat/litellm>
