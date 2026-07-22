#!/usr/bin/env bash
# CI-side runner: plain hcli htx -- mvn test (no hcli flags).
# IT env vars make hcli download/wire QA Unified agents automatically.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "CI hcli integration tests (QA agents)"
echo "========================================"

# libicu required by native TI agent (ti-agent.so / NativeAOT)
if ! ldconfig -p 2>/dev/null | grep -q libicu; then
  echo "libicu not found — installing..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || true
    apt-get install -y libicu74 2>/dev/null \
      || apt-get install -y libicu72 2>/dev/null \
      || apt-get install -y libicu 2>/dev/null \
      || echo "WARNING: Could not install libicu." >&2
  fi
fi

if [[ -z "${HCLI_BIN:-}" ]]; then
  if [[ -x "$SCRIPT_DIR/bin/hcli-linux" ]]; then
    HCLI_BIN="$SCRIPT_DIR/bin/hcli-linux"
  else
    HCLI_BIN="$(command -v hcli || true)"
  fi
fi
if [[ -z "$HCLI_BIN" || ! -x "$HCLI_BIN" ]]; then
  echo "hcli not found. Set HCLI_BIN or place bin/hcli-linux in the repo." >&2
  exit 1
fi
chmod +x "$HCLI_BIN" 2>/dev/null || true

ORDER_SERVICE_URL="${ORDER_SERVICE_URL:-$(grep -E '^order.service.url=' "$SCRIPT_DIR/services.properties" | cut -d= -f2-)}"
INVENTORY_SERVICE_URL="${INVENTORY_SERVICE_URL:-$(grep -E '^inventory.service.url=' "$SCRIPT_DIR/services.properties" | cut -d= -f2-)}"
SHIPPING_SERVICE_URL="${SHIPPING_SERVICE_URL:-$(grep -E '^shipping.service.url=' "$SCRIPT_DIR/services.properties" | cut -d= -f2-)}"

ORDER_SERVICE_HOST="${ORDER_SERVICE_HOST:-$(printf '%s' "$ORDER_SERVICE_URL" | sed -E 's|^https?://||; s|/.*||')}"
INVENTORY_SERVICE_HOST="${INVENTORY_SERVICE_HOST:-$(printf '%s' "$INVENTORY_SERVICE_URL" | sed -E 's|^https?://||; s|/.*||')}"
SHIPPING_SERVICE_HOST="${SHIPPING_SERVICE_HOST:-$(printf '%s' "$SHIPPING_SERVICE_URL" | sed -E 's|^https?://||; s|/.*||')}"

TI_DATA_DIR="${TI_DATA_DIR:-$SCRIPT_DIR/ti-it}"
mkdir -p "$TI_DATA_DIR"

# Use provided services file, or generate one from service host env vars
if [[ -z "${HARNESS_TI_SERVICES_FILE:-}" ]]; then
  HARNESS_TI_SERVICES_FILE="$TI_DATA_DIR/services.yaml"
  cat > "$HARNESS_TI_SERVICES_FILE" <<EOF
services:
  - $ORDER_SERVICE_HOST
  - $INVENTORY_SERVICE_HOST
  - $SHIPPING_SERVICE_HOST
EOF
fi

export CI_ENABLE_HCLI_FOR_INTEGRATION_TESTS=true
export CI_ENABLE_RUNTESTV2_JAVA_V2_FF=true
export HARNESS_TI_QA_ENV=QA_ENV_ENABLED
export HARNESS_TI_SERVICES_FILE

cd "$SCRIPT_DIR"

# If TRAMPOLINE_OVERRIDE_PATH is set, pre-download + pre-setup agents, then
# copy the override JAR over the QA trampoline before running tests with
# --setup-agents=false so hcli reuses the pre-setup agents.
if [[ -n "${TRAMPOLINE_OVERRIDE_PATH:-}" ]]; then
  echo "Pre-downloading agents for trampoline override..."
  "$HCLI_BIN" agents download --ti-data-dir "$TI_DATA_DIR" 2>/dev/null || true
  "$HCLI_BIN" agents setup --ti-data-dir "$TI_DATA_DIR" 2>/dev/null || true

  # Find the unzipped trampoline JAR and override it
  TRAMPOLINE_FOUND=0
  while IFS= read -r -d '' f; do
    echo "Overriding trampoline: $f"
    cp "$TRAMPOLINE_OVERRIDE_PATH" "$f"
    TRAMPOLINE_FOUND=1
  done < <(find "$TI_DATA_DIR" -type f -name 'java-agent-trampoline.jar' -print0 2>/dev/null)

  if [[ "$TRAMPOLINE_FOUND" -eq 0 ]]; then
    echo "WARNING: Could not find trampoline JAR to override. Falling back to normal mode." >&2
  fi

  # Override the native ti-agent.so with the freshly built one
  if [[ -n "${NATIVE_AGENT_OVERRIDE_PATH:-}" && -f "$NATIVE_AGENT_OVERRIDE_PATH" ]]; then
    NATIVE_FOUND=0
    while IFS= read -r -d '' f; do
      echo "Overriding native agent: $f"
      cp "$NATIVE_AGENT_OVERRIDE_PATH" "$f"
      NATIVE_FOUND=1
    done < <(find "$TI_DATA_DIR" -type f -name 'ti-agent.so' -print0 2>/dev/null)
    if [[ "$NATIVE_FOUND" -eq 0 ]]; then
      echo "WARNING: Could not find ti-agent.so to override." >&2
    fi
  fi
fi

TEST_EXIT=0
SETUP_FLAG=""
if [[ -n "${TRAMPOLINE_OVERRIDE_PATH:-}" ]]; then
  SETUP_FLAG="--setup-agents=false"
fi
"$HCLI_BIN" htx $SETUP_FLAG --stdout --services-file "$HARNESS_TI_SERVICES_FILE" -- mvn -f pom.xml test \
     -Dorder.service.url="$ORDER_SERVICE_URL" \
     -Dinventory.service.url="$INVENTORY_SERVICE_URL" \
     -Dshipping.service.url="$SHIPPING_SERVICE_URL" \
  || TEST_EXIT=$?

echo ""
if [[ "$TEST_EXIT" -eq 0 ]]; then
  echo "Tests: PASSED"
else
  echo "Tests: FAILED (exit $TEST_EXIT)"
fi

sleep 2

CG_SEARCH_DIR="${HARNESS_TI_DATA_DIR:-$HOME/.hcli/ti-agents}"
echo ""
echo "========================================"
echo "Call-graph output"
echo "========================================"
echo "Looking in: $CG_SEARCH_DIR"
FOUND=0
while IFS= read -r -d '' f; do
  FOUND=1
  SIZE=$(wc -c < "$f" | tr -d ' ')
  echo "  $f ($SIZE bytes)"
done < <(find "$CG_SEARCH_DIR" -type f -name 'unified-cg-*.ndjson' -print0 2>/dev/null)
if [[ "$FOUND" -eq 0 ]]; then
  echo "  (none)"
fi

exit "$TEST_EXIT"
