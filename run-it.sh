#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORDER_DIR="${ORDER_SERVICE_DIR:-/Users/satya/Git/order-service}"
INVENTORY_DIR="${INVENTORY_SERVICE_DIR:-/Users/satya/Git/inventory-service}"
SHIPPING_DIR="${SHIPPING_SERVICE_DIR:-/Users/satya/Git/shipping-service}"
SERVICES_FILE="${SERVICES_FILE:-$SCRIPT_DIR/services.properties}"

prop() {
  local key="$1"
  local value
  value="$(grep -E "^${key}=" "$SERVICES_FILE" | tail -n1 | cut -d= -f2-)"
  if [[ -z "$value" ]]; then
    echo "Missing $key in $SERVICES_FILE" >&2
    exit 1
  fi
  printf '%s' "$value"
}

ORDER_URL="$(prop order.service.url)"
INVENTORY_URL="$(prop inventory.service.url)"
SHIPPING_URL="$(prop shipping.service.url)"

echo "========================================"
echo "Multi-Service Integration Test Runner"
echo "========================================"

echo ""
echo "[1/4] Building sibling services..."
mvn -f "$SHIPPING_DIR/pom.xml" clean package -DskipTests
mvn -f "$INVENTORY_DIR/pom.xml" clean package -DskipTests
mvn -f "$ORDER_DIR/pom.xml" clean package -DskipTests

echo ""
echo "[2/4] Starting shipping-service..."
java -jar "$SHIPPING_DIR/target/shipping-service-1.0-SNAPSHOT.jar" &
SHIPPING_PID=$!
sleep 3

echo ""
echo "[3/4] Starting inventory-service..."
java -jar "$INVENTORY_DIR/target/inventory-service-1.0-SNAPSHOT.jar" &
INVENTORY_PID=$!
sleep 5

echo ""
echo "[4/4] Starting order-service..."
java -jar "$ORDER_DIR/target/order-service-1.0-SNAPSHOT.jar" &
ORDER_PID=$!
sleep 5

cleanup() {
  kill $ORDER_PID 2>/dev/null || true
  kill $INVENTORY_PID 2>/dev/null || true
  kill $SHIPPING_PID 2>/dev/null || true
}
trap cleanup EXIT

echo ""
echo "Verifying services (from $SERVICES_FILE)..."
curl -s "$SHIPPING_URL/eta/TEST-SKU" > /dev/null && echo "✓ Shipping ready ($SHIPPING_URL)"
curl -s "$INVENTORY_URL/stock/TEST-SKU" > /dev/null && echo "✓ Inventory ready ($INVENTORY_URL)"
curl -s -X POST "$ORDER_URL/orders" -H "Content-Type: application/json" -d '{"sku":"TEST","quantity":1}' > /dev/null && echo "✓ Order ready ($ORDER_URL)"

echo ""
echo "========================================"
echo "Running Integration Tests"
echo "========================================"
mvn -f "$SCRIPT_DIR/pom.xml" test
TEST_EXIT_CODE=$?

echo ""
echo "========================================"
echo "Cleaning up services..."
echo "========================================"
cleanup
trap - EXIT
echo "✓ All services stopped"

exit $TEST_EXIT_CODE
