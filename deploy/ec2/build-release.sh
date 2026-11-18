#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $# != 1 ]]; then
    printf 'Usage: bash deploy/ec2/build-release.sh OUTPUT_DIRECTORY\n' >&2
    exit 2
fi
output=$(realpath -m "$1")
cd "$(git rev-parse --show-toplevel)"

for service in Account Account-service Auth Auth-service Gateway-service Exchange Exchange-service Product; do
    pinned=$(git rev-parse "HEAD:services/$service")
    actual=$(git -C "services/$service" rev-parse HEAD)
    if [[ "$actual" != "$pinned" ]] || [[ -n "$(git -C "services/$service" status --porcelain)" ]]; then
        printf 'Expected a clean checkout of %s at %s\n' "$service" "$pinned" >&2
        exit 1
    fi
done

maven=${MAVEN:-mvn}
for service in Account Auth; do
    "$maven" -B -ntp -f "services/$service/pom.xml" install
done
for service in Account-service Auth-service Gateway-service Product; do
    "$maven" -B -ntp -f "services/$service/pom.xml" package
done

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
for role in gateway identity exchange product; do
    mkdir -p "$staging/$role/deploy/ec2/artifacts"
    cp deploy/ec2/{compose.yaml,Caddyfile,gateway-routes.yaml,init-databases.sql} "$staging/$role/deploy/ec2/"
done
cp services/Gateway-service/target/gateway-service-*.jar "$staging/gateway/deploy/ec2/artifacts/gateway.jar"
cp services/Account-service/target/account-service-*.jar "$staging/identity/deploy/ec2/artifacts/account.jar"
cp services/Auth-service/target/auth-service-*.jar "$staging/identity/deploy/ec2/artifacts/auth.jar"
cp services/Product/target/product-*.jar "$staging/product/deploy/ec2/artifacts/product.jar"

for service in Exchange Exchange-service; do
    destination="$staging/exchange/services/$service"
    mkdir -p "$destination"
    git -C "services/$service" archive HEAD | tar -x -C "$destination"
done
mkdir -p "$output"
for role in gateway identity exchange product; do
    tar -czf "$output/$role.tar.gz" -C "$staging/$role" deploy
done
tar -czf "$output/exchange.tar.gz" -C "$staging/exchange" deploy services
