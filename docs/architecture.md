# Main Architecture

```mermaid
flowchart TB
    user["Users / Apps"]
    agent["MCP-Enabled Agents"]
    dns["DNS: api.example.com"]
    ingress["HTTPS Ingress\nTraefik or NGINX"]
    cert["cert-manager\nTLS Certificates"]

    subgraph runpod["RunPod GPU Instance"]
        subgraph k3s["k3s Cluster"]
            subgraph llmSystem["Namespace: llm-system"]
                litellm["LiteLLM Gateway\nOpenAI-Compatible API"]
                litellmDb["PostgreSQL\nLiteLLM State"]
                secrets["Kubernetes Secrets\nAPI Keys / Tokens"]
            end

            subgraph models["Namespace: models"]
                vllmSvc["vLLM Service"]
                vllmPod["vLLM Pod\nModel A"]
                llmdSvc["llm-d Service"]
                llmdPod["llm-d Pods\nModel B / Distributed Serving"]
                embedSvc["Embedding Service\nRAG Embeddings"]
                gpu["NVIDIA GPU\nDevice Plugin"]
                modelCache["Persistent Volume\nModel Cache"]
            end

            subgraph mcp["Namespace: mcp"]
                mcpGateway["MCP Gateway / Registry"]
                githubMcp["GitHub MCP"]
                dbMcp["Database MCP"]
                docsMcp["Docs / Files MCP"]
            end

            subgraph obs["Namespace: observability"]
                prom["Prometheus"]
                grafana["Grafana"]
                logs["Loki / Logs"]
            end
        end
    end

    external["Optional External LLM Providers"]

    user --> dns
    agent --> dns
    dns --> ingress
    cert --> ingress
    ingress --> litellm

    litellm --> secrets
    litellm --> litellmDb
    litellm --> vllmSvc
    litellm --> llmdSvc
    litellm --> embedSvc
    litellm -. fallback / overflow .-> external

    vllmSvc --> vllmPod
    llmdSvc --> llmdPod
    vllmPod --> gpu
    llmdPod --> gpu
    embedSvc --> modelCache
    vllmPod --> modelCache
    llmdPod --> modelCache

    agent --> mcpGateway
    mcpGateway --> githubMcp
    mcpGateway --> dbMcp
    mcpGateway --> docsMcp
    agent --> litellm

    litellm --> prom
    vllmPod --> prom
    llmdPod --> prom
    prom --> grafana
    litellm --> logs
    vllmPod --> logs
    llmdPod --> logs
```

## Traffic Flow

1. Users and agents call `https://api.example.com`.
2. Ingress terminates HTTPS and forwards traffic to LiteLLM.
3. LiteLLM handles API keys, routing, model aliases, budgets, logs, and fallbacks.
4. LiteLLM sends inference requests to private vLLM or llm-d services.
5. MCP-enabled agents use MCP servers for tools and LiteLLM for model inference.
6. Observability collects gateway, model, GPU, and cluster signals.

## Security Boundary

- Public: DNS and HTTPS ingress.
- Public API surface: LiteLLM only.
- Private: vLLM, llm-d, MCP servers, databases, model cache, and observability tools.
