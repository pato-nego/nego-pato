#!/usr/bin/env bash
set -euo pipefail

release=$1
product_ip=$2
order_ip=$3
payload=$PWD
cd /opt/pato-nego-distributed/deploy/ec2
compose=(docker compose --project-name pato-nego-distributed -f compose.yaml)

if [[ "$release" == exchange ]]; then
    current=$("${compose[@]}" --profile exchange ps -q exchange)
    old_image=$(docker inspect --format '{{.Image}}' "$current")
    image=$(docker inspect --format '{{.Config.Image}}' "$current")
    docker load --input "$payload/exchange-image.tar.gz"
    docker tag exchange:ci "$image"
    if "${compose[@]}" --profile exchange up -d --no-build --no-deps --force-recreate exchange &&
        curl -fsS --retry 12 --retry-all-errors --retry-delay 2 --max-time 3 http://127.0.0.1:8000/exchange/health-check; then
        exit 0
    fi
    docker tag "$old_image" "$image"
    "${compose[@]}" --profile exchange up -d --no-build --no-deps --force-recreate exchange
    exit 1
fi

test "$release" = gateway
curl -fsS --max-time 5 "http://$product_ip:8080/products/health-check"
curl -fsS --max-time 5 "http://$order_ip:8080/orders/health-check"
current=$("${compose[@]}" --profile gateway ps -q gateway)
ingress=$("${compose[@]}" --profile gateway ps -q ingress)
jar=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/app.jar"}}{{.Source}}{{end}}{{end}}' "$current")
release_dir="$PWD/.release"
previous=("${compose[@]}")
slot=a
case "$jar" in
    "$release_dir/gateway-a.jar") slot=b; previous+=(-f "$release_dir/gateway-a.yaml") ;;
    "$release_dir/gateway-b.jar") previous+=(-f "$release_dir/gateway-b.yaml") ;;
    "$PWD/artifacts/gateway.jar") ;;
    *) echo "Unknown Gateway artifact mount" >&2; exit 1 ;;
esac
install -d -m 750 "$release_dir"
install -m 644 "$payload/gateway.jar" "$release_dir/gateway-$slot.jar"
overlay="$release_dir/gateway-$slot.yaml"
cat > "$overlay" <<EOF
services:
  gateway:
    environment:
      SPRING_CONFIG_ADDITIONAL_LOCATION: optional:file:/etc/gateway/ci-routes.yaml
      PRODUCT_URL: http://$product_ip:8080
      ORDER_URL: http://$order_ip:8080
    volumes:
      - $release_dir/gateway-$slot.jar:/app.jar:ro
EOF

gateway_ready() {
    for attempt in {1..15}; do
        if docker exec "$ingress" wget -T 3 -q -O /dev/null http://gateway:8080/exchange/health-check; then
            return 0
        fi
        sleep 2
    done
    return 1
}

if "${compose[@]}" -f "$overlay" --profile gateway up -d --no-deps --force-recreate gateway && gateway_ready; then
    exit 0
fi
"${previous[@]}" --profile gateway up -d --no-deps --force-recreate gateway
exit 1
