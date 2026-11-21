# São Paulo operating costs

The estimate uses 730 hours per month, USD on-demand rates and the November 20, 2026 inventory in sa-east-1. The four public IPv4 addresses cover the existing gateway, the two teammates’ public hosts and the NAT gateway. The RDS instance has seven-day backup retention. These are list-price projections before credits, taxes, usage-based charges and discounts.

| EC2 deployment | Quantity and rate | USD/month |
| --- | --- | ---: |
| Product, Order and Exchange compute | 3 × t3.micro at 0.0168/hour | 36.79 |
| Identity compute | 1 × t3.small at 0.0336/hour | 24.53 |
| Gateway compute | 1 × t3.medium at 0.0672/hour | 49.06 |
| EC2 disks | 86 GB gp3 at 0.152/GB-month | 13.07 |
| PostgreSQL compute | Single-AZ db.t4g.micro at 0.034/hour | 24.82 |
| PostgreSQL disk | 20 GB gp3 at 0.219/GB-month | 4.38 |
| Outbound network | 1 NAT at 0.093/hour | 67.89 |
| Public IPv4 | 4 at 0.005/hour | 14.60 |
| **Existing fixed-cost estimate** | | **235.14** |

| Additional EKS deployment | USD/month |
| --- | ---: |
| Standard-support control plane at 0.10/hour | 73.00 |
| Two t3.medium workers | 98.11 |
| Two 20 GB worker disks at 0.152/GB-month if gp3 | 6.08 |
| One load balancer at 0.034/hour | 24.82 |
| **Incremental estimate before usage** | **202.01** |

An internet-facing load balancer with two public IPv4 addresses adds about USD 7.30/month. An internal load balancer uses private addresses. NAT adds USD 0.093 per GB processed. Load-balancer capacity or processed bytes, registry storage, cross-AZ traffic, internet egress, burst credits and excess backup storage depend on usage. The existing VPC, NAT and RDS are shared across the two environments. Reproduce the estimate with the São Paulo region and the quantities above. [AWS Pricing Calculator](https://calculator.aws/) · [AWS Price List](https://aws.amazon.com/aws-cost-management/aws-price-list-api/) · [EKS pricing](https://aws.amazon.com/eks/pricing/)

The account’s AWS Pricing Calculator workload estimate `Pato-Nego-Sao-Paulo-EC2-and-EKS` returned **USD 444.45/month** for 13 line items. This includes the two public load-balancer addresses. Find the saved workload estimate in Billing and Cost Management → Pricing Calculator. Cost Explorer reported preliminary São Paulo regional unblended costs of USD 0.90 on November 18 and USD 7.06 on November 19, before EKS provisioning. Those are account-wide daily observations. CodeBuild deployment minutes and ECR image storage add usage charges.

## Managed services and availability

RDS manages PostgreSQL backups and patching. EKS operates the Kubernetes control plane. The group remains responsible for application rollouts, database migrations, worker capacity and recovery. The EC2 app has single service hosts and a single-AZ database. A database outage can stop purchases even when Gateway and Exchange are healthy.

A proposed course-demo objective is 99% successful authenticated reads per month and p95 below 500 ms for cached catalog reads at ten concurrent users. Count unexpected 5xx responses and timeouts as failures. Exclude deliberately invalid test requests. At 99% availability a 30-day month allows 7 hours 12 minutes of downtime. The short local measurements support the latency target under that workload. A monthly availability claim needs continuous end-to-end measurements. [Load-test results](performance.md)
