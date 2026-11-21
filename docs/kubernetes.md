# Kubernetes deployment

The Pato Nego EKS cluster uses sa-east-1. The CloudFormation stack creates a managed control plane, a shared worker in one Availability Zone and a dedicated Exchange worker in another. Both workers use private subnets and the existing NAT gateway. The Kubernetes API accepts connections from the VPC and the administrator’s configured IP. The EC2 application has a separate gateway and continues serving its original users.

| Workload | Kubernetes service | Deployment inputs |
| --- | --- | --- |
| Gateway | gateway, HTTPS 443 | Gateway TLS Secret and routing ConfigMap |
| Auth | auth, HTTP 8080 | JWT signing Secret and token lifetime |
| Account | account, HTTP 8080 | Dedicated database credentials and regional RDS CA |
| Exchange | exchange, HTTP 8000 | PTAX timeout and cache durations |
| Product | product, HTTP 8080 | Product database credentials, RDS CA and Redis address |
| Order | order, HTTP 8080 | Order database credentials, RDS CA and Product/Exchange addresses |
| Redis | product-redis, TCP 6379 | In-memory Product detail cache |

Each service keeps its Kubernetes resources in its own repository’s `k8s/` directory. Order splits its Deployment, Service and autoscaler into three files. Account, Auth and Gateway consume Secrets whose values are provisioned directly in the namespace. Exchange consumes public Bacen data and uses the authenticated account ID forwarded by Gateway. Internal calls resolve services by their Kubernetes DNS names. Exchange runs on the node labeled `workload=exchange`.

## Verify the cluster

With an authorized AWS identity and network path to the API, use the following commands.

```sh
aws eks update-kubeconfig --region sa-east-1 --name pato-nego
kubectl get nodes -L workload,topology.kubernetes.io/zone
kubectl -n pato-nego get deployments,services,hpa
kubectl -n pato-nego get endpointslices
kubectl -n pato-nego rollout status deployment/exchange
kubectl -n pato-nego top pods
```

The cluster deployment uses the built service images in private ECR by digest. The checked-in image tags ending in `:local` are for locally built images. For deployment, override the image name and digest with Kustomize. Generate the JWT key outside Git. For Account, populate its Secret with the RDS hostname, database, username and password and put the regional RDS certificate bundle in the `rds-ca` ConfigMap under `bundle.pem`. For Gateway, create the `gateway-tls` TLS Secret before applying the manifest.

## HTTPS demo

Gateway terminates TLS behind an internet-facing Network Load Balancer. The EKS demonstration uses its own self-signed **public certificate**, valid through May 20, 2027. Download the [certificate](evidence/gateway.pem) and use it to verify the HTTPS connection. Browsers require an explicit trust decision for this certificate. For ongoing public use, the group can install a publicly trusted certificate for a domain it controls. Reissue the certificate if the load-balancer hostname changes.

```sh
curl --cacert gateway.pem https://a696ab569ad9e4c62ae41bd9b2743a49-970d0868192873ca.elb.sa-east-1.amazonaws.com/health-check
```

The EKS namespace has an independent JWT key and an isolated database on the existing RDS instance. The public load-balancer smoke test passed with certificate verification, and the original EC2 gateway also returned 200 after the EKS release. Account verifies the RDS hostname and regional CA. Connectivity tests covered registration, login, account lookup, a live USD/BRL quote, the quote cache, logout and anonymous access control.

## Product and Order on the shared worker

Gateway routes to `product:8080` and `order:8080`. Order fetches product prices from Product and the USD/BRL quote from `exchange:8000`. Product caches repeated catalog detail reads in `product-redis:6379`. Only Gateway has a public load balancer.

The parent repository pins both service revisions and their ECR image digests. Its Kustomize overlay reads the pinned manifests directly from the two submodules. It assigns Product, Order and Redis to the existing shared worker. Exchange stays on its dedicated worker. Reapply from the parent checkout with its submodules initialized:

```sh
kubectl kustomize --load-restrictor LoadRestrictionsNone infra/k8s/store |
  kubectl apply --server-side --field-manager=pato-store -f -
kubectl -n pato-nego rollout status deployment/product-redis
kubectl -n pato-nego rollout status deployment/product
kubectl -n pato-nego rollout status deployment/order
```

The render command reads files outside the overlay directory from the pinned local submodules. On a fresh namespace, provision the `rds-ca` ConfigMap with key `bundle.pem` and populate the following Secrets before deploying. Each application's login owns its own EKS database on the existing PostgreSQL instance. The overlay maps the CA bundle to the filename required by each service.

| Secret | Required keys | Database |
| --- | --- | --- |
| `product-credentials` | `DATABASE_HOST`, `DATABASE_NAME`, `DATABASE_USERNAME`, `DATABASE_PASSWORD` | `pato_eks_product` |
| `order-secrets` | `DATABASE_HOST`, `DATABASE_USERNAME`, `DATABASE_PASSWORD` | `pato_eks_order`, selected in `order-config` |

A rollout initially exhausted PostgreSQL connections when overlapping replicas opened their default pools. Each EKS Product and Order replica now keeps one idle connection and can use up to three. Both apps request 125m CPU. Their autoscalers target 100% of that request, preserving the original 125m CPU threshold. A supervised scale check brought Product and Order to two Ready replicas each at the same time on the shared worker. The autoscalers were then restored to their normal range of one to three. Simultaneous scale-out across several services is limited by the capacity of the shared worker.

[Watch the cluster and purchase demonstration](evidence/eks-purchase.webm).

## Delivery pipeline

Exchange GitHub Actions builds the container, runs the Python tests inside it, starts the server and checks the health and authentication responses. The workflow supports Docker Hub publication and an EKS rollout by digest when the registry and EKS settings are configured. The configured release publishes to private ECR, and CodeBuild runs inside the VPC. On November 20 the [GitHub release](https://github.com/pato-nego/Exchange/actions/runs/44851111950) and CodeBuild both succeeded. The running pod image matched the ECR digest `sha256:1a9d314ec0e5ad83e187893f4e877feb8cbe8cd9e9223d8d739c090ac8c89878`. Docker Hub publication requires separate registry credentials. [Exchange workflow](https://github.com/pato-nego/Exchange/actions)
