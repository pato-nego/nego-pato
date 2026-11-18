#!/usr/bin/env bash
set -euo pipefail
umask 077

if [[ $# != 1 ]]; then
    printf 'Usage: bash deploy/ec2/build-release.sh OUTPUT_DIRECTORY\n' >&2
    exit 2
fi
output=$(realpath -m "$1")
cd "$(git rev-parse --show-toplevel)"

for service in account account-service auth auth-service gateway-service exchange exchange-service product; do
    pinned=$(git rev-parse "HEAD:api/$service")
    actual=$(git -C "api/$service" rev-parse HEAD)
    if [[ "$actual" != "$pinned" ]] || [[ -n "$(git -C "api/$service" status --porcelain)" ]]; then
        printf 'Expected a clean checkout of %s at %s\n' "$service" "$pinned" >&2
        exit 1
    fi
done

maven=${MAVEN:-mvn}
for service in account auth; do
    "$maven" -B -ntp -f "api/$service/pom.xml" install
done
for service in account-service auth-service gateway-service product; do
    "$maven" -B -ntp -f "api/$service/pom.xml" package
done

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
for role in gateway identity exchange product; do
    mkdir -p "$staging/$role/deploy/ec2/artifacts"
    cp deploy/ec2/{compose.yaml,Caddyfile,gateway-routes.yaml,init-databases.sql} "$staging/$role/deploy/ec2/"
done
cp api/gateway-service/target/gateway-service-*.jar "$staging/gateway/deploy/ec2/artifacts/gateway.jar"
cp api/account-service/target/account-service-*.jar "$staging/identity/deploy/ec2/artifacts/account.jar"
cp api/auth-service/target/auth-service-*.jar "$staging/identity/deploy/ec2/artifacts/auth.jar"
cp api/product/target/product-*.jar "$staging/product/deploy/ec2/artifacts/product.jar"

for service in exchange exchange-service; do
    destination="$staging/exchange/api/$service"
    mkdir -p "$destination"
    git -C "api/$service" archive HEAD | tar -x -C "$destination"
done
mkdir -p "$output"
for role in gateway identity exchange product; do
    tar -czf "$output/$role.tar.gz" -C "$staging/$role" deploy
done
tar -czf "$output/exchange.tar.gz" -C "$staging/exchange" deploy api
