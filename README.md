# nego-pato

The gateway exposes the Bacen PTAX Exchange API at `GET /exchange/{from}/{to}`.
The plural `/exchanges/{from}/{to}` path also works. Exchange
runs on the private Compose network and accepts the account ID forwarded by the
gateway after it validates the login cookie.

The `api/` folder holds the backend submodules and local Compose stack.
From the parent repo, initialize submodules and build the Java services with
JDK 25 and Maven.

```sh
git submodule update --init --recursive
mvn -f api/account/pom.xml install
mvn -f api/auth/pom.xml install
mvn -f api/order/pom.xml install
mvn -f api/account-service/pom.xml package
mvn -f api/auth-service/pom.xml package
mvn -f api/gateway-service/pom.xml package
mvn -f api/order-service/pom.xml package
export JWT_SECRET_KEY="$(openssl rand -base64 32)"
docker compose -f api/compose.yaml up --build
```

Register and log in through the gateway using `POST /auth/register` and
`POST /auth/login`. Send the resulting `__store_jwt_token` cookie to
`GET http://localhost:8080/exchange/USD/BRL`. A successful response contains
`sell`, `buy`, `date`, and `id-account`.
If port 8080 is in use, set `GATEWAY_PORT` before starting Compose and use it in
the request URL.

Exchange builds, tests, and releases through its
[GitHub Actions workflow](https://github.com/pato-nego/Exchange/blob/main/.github/workflows/ci-cd.yml).
The [Exchange README](https://github.com/pato-nego/Exchange#cicd) documents the
Docker Hub and EKS settings.

The [production EC2 workflow](.github/workflows/production-ec2.yml) builds and
deploys the Exchange and Gateway revisions pinned in this repository.

AI assisted with the Exchange handler, provider error handling, Gateway and
Compose integration, the EC2 release workflow, and verification.
