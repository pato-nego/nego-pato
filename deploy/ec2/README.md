# São Paulo EC2 deployment

| Host | Services | Access |
| --- | --- | --- |
| Gateway | Caddy and Gateway | Public HTTPS |
| Identity | Auth and Account | Private ports 8080 and 8081 from Gateway |
| Exchange | Exchange API with the Exchange-service library | Private port 8000 from Gateway |
| Product | Product API and Redis | Private port 8080 from Gateway |
| Order | Dedicated host for the team's Order API | SSH through Gateway until Order is published |

One private RDS PostgreSQL instance hosts `store` and `product`. Account
and Product connect with different credentials and verify the database's TLS
certificate. The private hosts share one NAT gateway for outbound internet access.

## Provision

Deploy `stack.yaml` in `sa-east-1`. Pass the existing gateway stack's VPC,
public subnet, gateway security group and SSH key name. Use an Ubuntu 24.04
x86-64 AMI and two available zones. The default subnet CIDRs fit the project
VPC (`10.42.0.0/24`). The stack outputs the private host IPs, database
endpoint and the ARN of the RDS-managed administrator secret.

```sh
aws cloudformation deploy --region sa-east-1 \
  --stack-name pato-nego-private-services \
  --template-file deploy/ec2/stack.yaml \
  --parameter-overrides "VpcId=$VPC_ID" "PublicSubnetId=$PUBLIC_SUBNET_ID" \
    "GatewaySecurityGroupId=$GATEWAY_SECURITY_GROUP_ID" "KeyName=$KEY_NAME" \
    "UbuntuAmi=$UBUNTU_AMI" "PrimaryZone=$PRIMARY_ZONE" "SecondaryZone=$SECONDARY_ZONE"
```

## Release

Build the archives with JDK 25 and Maven, then copy each archive to its
matching host using the gateway as the SSH jump host for private machines.
Verify the new SSH host keys using the EC2 console output.

```sh
git submodule update --init --recursive
bash deploy/ec2/build-release.sh /tmp/pato-nego-release
```

Extract the archives in `/opt/pato-nego-distributed` on each host. In each
`deploy/ec2` directory, create a root-only `.env` with the local settings.

| Profile | Settings |
| --- | --- |
| `gateway` | `PUBLIC_HOST`, `IDENTITY_IP`, `EXCHANGE_IP`, `PRODUCT_IP` |
| `identity` | `DATABASE_HOST`, `ACCOUNT_DB_PASSWORD`, `JWT_SECRET_KEY` |
| `exchange` | Empty |
| `product` | `DATABASE_HOST`, `PRODUCT_DB_PASSWORD` |

Download the [São Paulo RDS CA bundle](https://truststore.pki.rds.amazonaws.com/sa-east-1/sa-east-1-bundle.pem)
as `rds-ca.pem` beside the Compose file on Identity and Product. On Identity,
use the RDS administrator credentials in a PostgreSQL client to run
`init-databases.sql` against the `postgres` database. Pass
`ACCOUNT_DB_PASSWORD` and `PRODUCT_DB_PASSWORD` to the client environment.
Generate distinct passwords on first deployment and retain them for reruns.

For a migration, preserve the current JWT signing key, stop writes to the
source Account service, and import a fresh `pg_dump` into RDS as `account_app`
before starting the new Account service. Keep the source database for recovery.
Reuse the existing `pato-nego_caddy-data` and `pato-nego_caddy-config` volumes.
Stop the old ingress before starting the new gateway profile so it can bind
ports 80 and 443.

On each host, open a root shell in `/opt/pato-nego-distributed/deploy/ec2`
and set `PROFILE` to that host's profile.

```sh
docker compose --project-name pato-nego-distributed --profile "$PROFILE" up -d --build
docker compose --project-name pato-nego-distributed --profile "$PROFILE" ps
```

Verify the public `/health-check` over HTTPS, register and log in with a
disposable account, and call `/products` and `/exchange/USD/BRL` with the
login cookie. Private services should be reachable through Gateway only.
