# nego-pato

The gateway exposes the Bacen PTAX Exchange API at `GET /exchange/{from}/{to}`.
The plural `/exchanges/{from}/{to}` path also works. Exchange
runs on the private Compose network and accepts the account ID forwarded by the
gateway after it validates the login cookie.

From the parent repo, initialize submodules and build the Java services with JDK 25
and Maven:

```sh
git submodule update --init --recursive
mvn -f services/Account/pom.xml install
mvn -f services/Auth/pom.xml install
mvn -f services/Account-service/pom.xml package
mvn -f services/Auth-service/pom.xml package
mvn -f services/Gateway-service/pom.xml package
export JWT_SECRET_KEY="$(openssl rand -base64 32)"
docker compose up --build
```

Register and log in through the gateway using `POST /auth/register` and
`POST /auth/login`. Send the resulting `__store_jwt_token` cookie to
`GET http://localhost:8080/exchange/USD/BRL`. A successful response contains
`sell`, `buy`, `date`, and `id-account`.
If port 8080 is in use, set `GATEWAY_PORT` before starting Compose and use it in
the request URL.

For the five-host São Paulo layout, see the [EC2 deployment guide](deploy/ec2/README.md).

AI assisted with the Exchange handler, provider error handling, gateway and
Compose wiring, and verification.
