# Load tests and bottlenecks

## Local buying and catalog workloads

Tested November 20, 2026 with k6 1.5.0 and Docker Compose. Each measured run lasted 15 seconds with 10 virtual users and a 100 ms pause between operations. Setup created a disposable authenticated account and a test product. The detail comparison used two runs per cache setting after a 6-second warm-up.

All timed traffic went through Gateway on the local Docker network. The order workload used USD. The measurements exclude setup requests and do not exercise the PTAX API.

Product was at `668bac8` and Order-service at `ae05a60`. Gateway and Exchange used the local integration changes.

| Scenario | Requests | Requests/s | p95 | Errors |
| --- | ---: | ---: | ---: | ---: |
| Product detail, cache disabled (1) | 1266 | 79.1 | 31.04 ms | 0.00% |
| Product detail, cache disabled (2) | 1330 | 84.6 | 18.32 ms | 0.00% |
| Product detail, Redis (1) | 1360 | 87.0 | 13.96 ms | 0.00% |
| Product detail, Redis (2) | 1364 | 87.3 | 13.87 ms | 0.00% |
| Catalog list | 1292 | 82.6 | 18.55 ms | 0.00% |
| Create order (USD) | 1036 | 66.3 | 58.09 ms | 0.00% |

[Download the six measured k6 summaries](evidence/compose-k6.json).

## Cache comparison

- Disabled mean of the two run p95 values was 24.68 ms. Redis reported 0 hits during the measured runs.
- Redis mean of the two run p95 values was 13.91 ms. Redis reported 2,724 hits during the measured runs.

These measurements apply to this short, single-host workload. The EKS run below exercises a different endpoint.

## Exchange under concurrent load

Each Exchange process caches Bacen bulletins by currency for 300 seconds. A lock per currency lets one caller refresh while others reuse its result. Different currency codes can refresh independently. After a provider timeout, Exchange serves the last quote if available and retries after 30 seconds. With a cold cache, a provider failure returns 502. Rates and timestamps come from Bacen. Each new replica starts with a cold cache.

The Exchange tests simulate the clock and a Bacen timeout. The production check requested USD/BRL through both Gateway routes and observed a cache hit. These checks cover provider calls and fallback behavior. The table above measures a separate cache in Product. [Exchange source and tests](https://github.com/pato-nego/Exchange)

## Gateway autoscaling on EKS

On November 20, 2026, k6 ran inside the São Paulo cluster. It targeted HTTPS `GET /health-check` on the Spring Boot Gateway at 180 scheduled requests per second for two minutes, with up to 24 virtual users. The HPA targeted 50% utilization of a 250m CPU request, with a minimum of one and a maximum of three replicas. Kubernetes reported a CPU-triggered resize from one to three, and all three Gateway pods became ready.

| Completed HTTP requests | HTTP failures | Delivered rate | p95 | Dropped scheduled iterations |
| ---: | ---: | ---: | ---: | ---: |
| 21,553 | 0 | 179.60/s | 39.03 ms | 48 |

The generator dropped 48 iterations before sending an HTTP request. The success rate applies to requests it sent. This in-cluster workload measures Gateway health handling and scale-out. The EC2 purchase and EKS authentication checks exercise other services separately.

[Watch the 80-second recording of k6, the HPA and the pods](evidence/eks-hpa.webm) · [Read the k6 summary](evidence/eks-k6.txt).
