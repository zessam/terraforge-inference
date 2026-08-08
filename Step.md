# Build Steps

Architecture and rationale live in [PLAN.md](PLAN.md). This file is the ordered checklist only.

Legend: `~~done~~` · `*in progress*` · plain = not started

## A. Model plane — RunPod

1. ~~Create repo
   Use project name terraforge-inference.~~
2. ~~Prepare RunPod
   Choose GPU pod, persistent storage, and SSH access. Record the GPU model and VRAM — it decides the chat model.~~
3. *Install k3s
   Install Kubernetes on the RunPod pod. Disable Traefik and the ServiceLB; nothing on this plane is publicly served.*
4. Enable GPU
   Install the NVIDIA device plugin and confirm Kubernetes reports `nvidia.com/gpu` on the node.
5. Create namespaces
   Add `models` and `monitoring`.
6. Create secrets
   Add `HF_TOKEN`, `VLLM_API_KEY`, `EMBEDDING_API_KEY`, and `TS_AUTHKEY`.
7. Create storage
   Add the model cache PVC. Confirm whether it survives pod recreation and record the answer.
8. Deploy vLLM
   Serve the Terraform chat/code model on the GPU. Internal ClusterIP only. Test from inside the cluster.
9. Deploy the embedding model
   Serve the RAG embedding model. GPU if VRAM allows, otherwise CPU. Internal ClusterIP only.
10. Add GPU and host metrics
    Deploy the NVIDIA DCGM exporter and node-exporter. Do not expose them publicly.

## B. Control plane — GKE

11. Create the GKE cluster
    Pick the region nearest RunPod. Autopilot, or Standard with 2–3 `e2-standard` nodes.
12. Create namespaces
    Add `llm-system`, `observability`, and `mcp`. Leave `mcp` empty.
13. Create Cloud SQL
    Smallest shared-core PostgreSQL instance, public IP. Create a `litellm` database and a `langfuse` database.
14. Create secrets
    Add `LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY`, `DATABASE_URL`, `VLLM_API_KEY`, `EMBEDDING_API_KEY`, `TS_AUTHKEY`, and `LANGFUSE_SECRET`.
15. Create storage
    Add PVCs for Grafana and Prometheus.

## C. Join the two planes

16. Set up Tailscale on both planes
    Join the RunPod pod to the tailnet; install the Tailscale operator on GKE.
17. Expose the RunPod backends to the tailnet
    Make vLLM and the embedding service reachable by tailnet name — and by nothing else.
18. Create egress services on GKE
    Give LiteLLM ordinary in-cluster DNS names that forward to the tailnet targets.
19. Verify the link
    Confirm a GKE pod can reach both backends, and that neither answers from the public internet.

## D. Gateway

20. Deploy LiteLLM
    Add the Cloud SQL Auth Proxy sidecar, register both RunPod backends, configure aliases, master key, virtual keys, budgets, and rate limits.
21. Expose LiteLLM
    Add the GKE ingress or external LoadBalancer. This is the only public endpoint in the system.
22. Configure TLS
    Managed certificate if a domain exists; otherwise LB IP with `nip.io` or self-signed, and revisit later.

## E. Observability

23. Deploy the monitoring stack
    Prometheus, Grafana, and kube-state-metrics on GKE.
24. Add cross-tailnet scrape configs
    Point Prometheus at vLLM metrics, DCGM, and node-exporter on RunPod.
25. Deploy Langfuse
    Connect it to its Cloud SQL database and wire LiteLLM callbacks to it.
26. Add dashboards
    Cluster health for both planes, GPU usage, LiteLLM traffic, vLLM latency, embeddings, cross-cloud link health, token usage.
27. Add alerts
    GPU memory, pod restarts, LiteLLM errors and availability, high latency, Cloud SQL failure, disk usage, budget exceeded, and **tailnet link down**.

## F. Automation and handover

28. Add CI/CD
    GitHub Actions: lint and validate manifests, SSH-deploy the RunPod plane, `kubectl` deploy the GKE plane, wait for rollouts, run smoke tests.
29. Run smoke tests
    `GET /v1/models`, `POST /v1/chat/completions`, `POST /v1/embeddings`, a LangChain call, and a negative test proving vLLM is not publicly reachable.
30. Add runbooks
    Bootstrap either plane, redeploy, rotate keys, restart vLLM, update models, debug GPU and pods, restore Cloud SQL, diagnose a broken link.
31. Prepare MCP only
    Write `gke/mcp/README.md` and keep the namespace empty. Do not deploy MCP tools.
32. Freeze phase-1 scope
    No LangChain agent, no vector DB, no MCP servers, no llm-d. Document each as a later phase.
