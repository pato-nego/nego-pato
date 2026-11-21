# Kubernetes deployment

The Pato Nego EKS cluster uses sa-east-1. The CloudFormation stack creates a managed control plane, a shared worker in one Availability Zone and a dedicated Exchange worker in another. Both workers use private subnets and the existing NAT gateway. The Kubernetes API accepts connections from the VPC and the administrator’s configured IP. The EC2 application has a separate gateway and continues serving its original users.

| Workload | Kubernetes service | Deployment inputs |
| --- | --- | --- |
| Gateway | gateway, HTTPS 443 | Gateway TLS Secret and routing ConfigMap |
| Auth | auth, HTTP 8080 | JWT signing Secret and token lifetime |
| Account | account, HTTP 8080 | Dedicated database credentials and regional RDS CA |
| Exchange | exchange, HTTP 8000 | PTAX timeout and cache durations |

Each service has its own setup file at `api/<repo>/k8s/k8s.yaml`. Account, Auth and Gateway consume Secrets whose values are provisioned directly in the namespace. Exchange consumes public Bacen data and uses the authenticated account ID forwarded by Gateway. Internal calls resolve services by their Kubernetes DNS names. Exchange runs on the node labeled `workload=exchange`.

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

## Product and Order handoff

The Product and Order owners control their releases. The exercise calls for each owner to add their own manifest, then deploy into the same namespace. Gateway expects `product:8080` and `order:8080`. Order should call `exchange:8000` and `product:8080`. Each owner needs an authorized AWS identity and a network path to the private or IP-restricted API. Each workload should have a ready endpoint before recording the five-service demo. The owners manage any additional dedicated workers.

## Delivery pipeline

Exchange GitHub Actions builds the container, runs the Python tests inside it, starts the server and checks the health and authentication responses. The workflow supports Docker Hub publication and an EKS rollout by digest when the registry and EKS settings are configured. The configured release publishes to private ECR, and CodeBuild runs inside the VPC. On November 20 the [GitHub release](https://github.com/pato-nego/Exchange/actions/runs/44851111950) and CodeBuild both succeeded. The running pod image matched the ECR digest `sha256:1a9d314ec0e5ad83e187893f4e877feb8cbe8cd9e9223d8d739c090ac8c89878`. Docker Hub publication requires separate registry credentials. [Exchange workflow](https://github.com/pato-nego/Exchange/actions)
