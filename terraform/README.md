# Infrastructure

Two clouds. GPUs are expensive and RunPod is cheap for them, so **the models live on RunPod**. Everything else — the gateway, the database, the dashboards — lives on **GKE**.

## The big picture

```mermaid
flowchart LR
    user["User / Agent"]

    subgraph gke["GKE — Google Cloud"]
        lb["Load Balancer"]
        litellm["LiteLLM<br/>the gateway"]
        db[("Cloud SQL<br/>keys, budgets, usage")]
        obs["Prometheus<br/>Grafana / Langfuse"]
    end

    subgraph rp["RunPod — GPU"]
        vllm["vLLM<br/>chat/code model"]
        embed["Embedding model"]
    end

    user -->|HTTPS| lb --> litellm
    litellm --> db
    litellm --> obs
    litellm -->|private tunnel| vllm
    litellm -->|private tunnel| embed
```

**Only the load balancer is public.** The models have no public address at all — the only way to reach them is through LiteLLM, which is what makes API keys, budgets, and rate limits actually enforceable. If the models were public, anyone with the URL could skip all of that.

## Who creates what

A common surprise: **Terraform does not create the load balancer.** Terraform reserves the IP address; GKE builds the load balancer later when you install LiteLLM.

```mermaid
flowchart TB
    subgraph tf["Terraform builds this"]
        net["VPC + Cloud NAT"]
        cluster["GKE cluster"]
        sql["Cloud SQL"]
        ip["Static IP address"]
        iam["Service accounts"]
    end

    subgraph kc["kubectl builds this"]
        pods["LiteLLM, Grafana, etc."]
        ing["Ingress"]
    end

    glb["Load Balancer<br/>(GKE creates it)"]

    ip -.->|"referenced by name"| ing
    ing --> glb
    cluster --> pods
```

So the order is: `terraform apply` reserves the IP → you install LiteLLM → GKE sees the Ingress and builds the load balancer on that IP. The address is known and stable before LiteLLM ever starts.

## What a request looks like

```mermaid
sequenceDiagram
    participant U as User
    participant L as LiteLLM
    participant D as Cloud SQL
    participant V as vLLM (RunPod)

    U->>L: "write me a Terraform module" + API key
    L->>D: is this key valid? under budget?
    D-->>L: yes
    L->>V: forward over private tunnel
    V-->>L: streamed answer
    L->>D: record tokens + cost
    L-->>U: streamed answer
```

## What Terraform creates


| Resource                             | Why                                                                                      |
| ------------------------------------ | ---------------------------------------------------------------------------------------- |
| VPC + subnet                         | Private network for the cluster                                                          |
| **Cloud NAT**                        | Private nodes have no public IP — without NAT they can't pull images**or reach RunPod** |
| GKE cluster (zonal)                  | Runs LiteLLM and observability. Zonal = free management tier                             |
| Node pool, 2× e2-standard-4         | No GPUs; models are on RunPod                                                            |
| Cloud SQL Postgres                   | LiteLLM state + Langfuse                                                                 |
| Static IP                            | The stable public address                                                                |
| Service accounts + Workload Identity | Lets LiteLLM reach the database with no password file                                    |
| Secret Manager                       | Generated DB password and LiteLLM keys                                                   |

## Two things that will bite you

**1. Streaming gets cut off at 30 seconds.** Google's load balancer defaults to a 30s backend timeout. LiteLLM streams answers token by token, and a long Terraform generation runs past that — the connection drops mid-answer and looks like a model bug. Fix is a `BackendConfig` with `timeoutSec: 3600` on the LiteLLM Service.

**2. A GCP load balancer has no DNS name.** Unlike an AWS ELB, which hands you `app-lb-123.eu-west-2.elb.amazonaws.com`, GCP gives you an IP and nothing else. Google-managed certificates can't be issued for a bare IP, so that would normally mean no HTTPS until you buy a domain.

The workaround is wildcard DNS: `nip.io` resolves `34.1.2.3.nip.io` to `34.1.2.3` — no registration, no records to manage. The IP is reserved and static, so the hostname is stable too, and a managed certificate *can* be issued for it because validation only requires the name to resolve to this load balancer.

Terraform derives it for you:

```
litellm_endpoint = "https://34.1.2.3.nip.io"
```

Set `domain` in `terraform.tfvars` when you have a real one and it takes precedence automatically.

## Rough cost


| Item                             | Per month |
| -------------------------------- | --------- |
| 2× e2-standard-4 nodes          | ~$100     |
| Cloud SQL`db-g1-small`           | ~$28      |
| Load balancer                    | ~$18      |
| Cloud NAT                        | ~$32      |
| GKE management (zonal free tier) | $0        |
| **GKE total**                    | **~$180** |

RunPod GPU is billed separately by the hour — stop the pod when you're not using it.

## How the Terraform is organised

Seven small modules, wired together by one root `main.tf`.

```mermaid
flowchart TD
    ps["project-services<br/>enable APIs"]
    net["network<br/>VPC + NAT"]
    sa1["service-account<br/>(nodes)"]
    sa2["service-account<br/>(LiteLLM)"]
    gke["gke<br/>cluster + nodes"]
    sql["cloud-sql<br/>Postgres"]
    sec["secrets<br/>Secret Manager"]
    lb["load-balancer<br/>static IP"]

    ps --> net & sa1 & sa2 & sql & lb
    net --> gke
    sa1 --> gke
    sql -->|password| sec
    sa2 -->|can read| sec
```

`service-account` is used twice — once for the nodes, once for LiteLLM — which is the point of writing it as a module.

## Running it

```bash
cd terraform
terraform init
terraform plan
terraform apply

# then point kubectl at the new cluster
$(terraform output -raw get_credentials)
```

Details and design rationale: [PLAN.md](PLAN.md). Build order: [Step.md](Step.md).
