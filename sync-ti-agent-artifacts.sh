#!/usr/bin/env bash
# Build the latest TI agent artifacts from ti-agents and copy them into
# it-ti/ti-agent-artifacts/ for local scripts and Harness CI.
#
# Produces linux/amd64 artifacts:
#   - ti-agent.so                  (NativeAOT shared library)
#   - java-agent-trampoline.jar    (javaagent entrypoint + embedded jars)
#
# The .so must be built on Linux (ti-agent.csproj picks the extension from the
# host OS; NativeAOT needs a target linker). We use the ti-agents Linux builder
# Docker image, same approach as build-linux-agents.sh.
#
# Usage:
#   ./sync-ti-agent-artifacts.sh
#   TI_AGENTS_DIR=/path/to/ti-agents ./sync-ti-agent-artifacts.sh
#   BRANCH=main SKIP_PULL=1 ./sync-ti-agent-artifacts.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IT_TI_DIR="${IT_TI_DIR:-$SCRIPT_DIR}"
TI_AGENTS_DIR="${TI_AGENTS_DIR:-$IT_TI_DIR/../ti-agents}"
OUT_DIR="$IT_TI_DIR/ti-agent-artifacts"
IMAGE_TAG="${IMAGE_TAG:-ti-agent-linux-builder:local}"
BRANCH="${BRANCH:-main}"
SKIP_PULL="${SKIP_PULL:-0}"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -d "$TI_AGENTS_DIR/ti-agent" ] || die "ti-agents repo not found at $TI_AGENTS_DIR (set TI_AGENTS_DIR)"
[ -f "$TI_AGENTS_DIR/docker-images/build-machines/linux/Dockerfile" ] \
  || die "Linux Dockerfile not found under $TI_AGENTS_DIR"

echo "==> ti-agents repo: $TI_AGENTS_DIR"
echo "==> it-ti output:   $OUT_DIR"
echo "==> branch:         $BRANCH"
echo "==> docker image:   $IMAGE_TAG (linux/amd64)"
echo ""

echo "==> Syncing ti-agents ($BRANCH)..."
(
  cd "$TI_AGENTS_DIR"
  if [ "$SKIP_PULL" != "1" ]; then
    git fetch origin "$BRANCH"
  fi
  git checkout "$BRANCH"
  if [ "$SKIP_PULL" != "1" ]; then
    git pull --ff-only origin "$BRANCH"
  fi
  echo "    at $(git rev-parse --short HEAD) — $(git log -1 --format='%s')"
)

echo ""
echo "==> Building builder image (linux/amd64)..."
docker buildx build --platform linux/amd64 -t "$IMAGE_TAG" --load \
  "$TI_AGENTS_DIR/docker-images/build-machines/linux/"

echo ""
echo "==> Building ti-agent.so + java-agent-trampoline.jar..."
docker run --rm --platform linux/amd64 \
  -v "$TI_AGENTS_DIR:/work" \
  -w /work/ti-agent \
  --user 0:0 \
  -e HOME=/root \
  "$IMAGE_TAG" bash -c '
    set -euo pipefail
    export PATH="/home/builder/.dotnet:$PATH"
    DOTNET=/home/builder/.dotnet/dotnet

    echo "--- native agent (linux-x64) ---"
    $DOTNET publish src/ti.agent/ti-agent.csproj \
      -c Release -r linux-x64 /p:NativeLib=Shared /p:SelfContained=true

    echo "--- java trampoline jar ---"
    bash tools/gradlew -p src/java :java-agent-trampoline:build -x test --no-daemon

    echo "--- built artifacts ---"
    ls -la pack/ti-agent.so
    ls -la src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar
    file pack/ti-agent.so
  '

SO_SRC="$TI_AGENTS_DIR/ti-agent/pack/ti-agent.so"
JAR_SRC="$TI_AGENTS_DIR/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar"
[ -f "$SO_SRC" ]  || die "build did not produce $SO_SRC"
[ -f "$JAR_SRC" ] || die "build did not produce $JAR_SRC"

mkdir -p "$OUT_DIR"
cp "$SO_SRC"  "$OUT_DIR/ti-agent.so"
cp "$JAR_SRC" "$OUT_DIR/java-agent-trampoline.jar"

echo ""
echo "==> Verifying artifacts..."
SO_INFO=$(file "$OUT_DIR/ti-agent.so")
echo "  ti-agent.so: $SO_INFO"
echo "$SO_INFO" | grep -q 'ELF 64-bit LSB shared object, x86-64' \
  || die "ti-agent.so is NOT Linux x86-64 — wrong arch"

JAR_ENTRIES=$(jar tf "$OUT_DIR/java-agent-trampoline.jar" 2>/dev/null || true)
echo "$JAR_ENTRIES" | grep -q 'callgraph-boot.jar'   || die "trampoline jar missing callgraph-boot.jar"
echo "$JAR_ENTRIES" | grep -q 'callgraph-agent.jar'  || die "trampoline jar missing callgraph-agent.jar"
echo "$JAR_ENTRIES" | grep -q 'harness/callgraph/trampoline/TrampolineAgent.class' \
  || die "trampoline jar missing TrampolineAgent.class"
echo "  java-agent-trampoline.jar: OK"

echo ""
echo "==> Done. Artifacts copied to $OUT_DIR:"
ls -la "$OUT_DIR"
echo ""
echo "Next: git add ti-agent-artifacts/ && git commit, then run integration_tests_simple."
