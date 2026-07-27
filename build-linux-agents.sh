#!/usr/bin/env bash
# Build the Linux x64 TI agent artifacts (ti-agent.so + java-agent-trampoline.jar)
# from the ti-agents source, inside a Linux container, then copy them into this
# repo under ti-agent-artifacts/ so the Harness CI pipeline (cloneCodebase: true)
# can use them directly instead of downloading the stale GCS QA zip.
#
# Why a container: ti-agent.csproj selects the output extension by HOST OS
# (IsOSPlatform('Linux') -> .so) and NativeAOT needs a target-platform native
# linker, so the .so cannot be cross-compiled from macOS. We build inside the
# repo's own docker-images/build-machines/linux/Dockerfile (Ubuntu 20.04 +
# .NET 9.0.200 + JDK17), pinned to linux/amd64 to match the Harness k8s nodes.
#
# The java-agent-trampoline.jar is platform-independent (it embeds
# callgraph-boot.jar + callgraph-agent.jar as resources) but is built in the
# same container for a single self-contained run.
#
# Usage:
#   ./build-linux-agents.sh                # uses default sibling repo paths
#   TI_AGENTS_DIR=/path/to/ti-agents ./build-linux-agents.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IT_TI_DIR="${IT_TI_DIR:-$SCRIPT_DIR}"
TI_AGENTS_DIR="${TI_AGENTS_DIR:-$IT_TI_DIR/../ti-agents}"
IMAGE_TAG="${IMAGE_TAG:-ti-agent-linux-builder:local}"
OUT_DIR="$IT_TI_DIR/ti-agent-artifacts"

die() { echo "ERROR: $*" >&2; exit 1; }

[ -d "$TI_AGENTS_DIR/ti-agent" ] || die "ti-agents repo not found at $TI_AGENTS_DIR (set TI_AGENTS_DIR)"
[ -f "$TI_AGENTS_DIR/docker-images/build-machines/linux/Dockerfile" ] \
  || die "Linux Dockerfile not found under $TI_AGENTS_DIR"

echo "==> ti-agents repo: $TI_AGENTS_DIR"
echo "==> output dir:     $OUT_DIR"
echo "==> image:          $IMAGE_TAG (linux/amd64)"
echo ""

# 1. Build the Linux builder image (amd64, via QEMU on Apple Silicon).
echo "==> Building builder image (linux/amd64)..."
docker buildx build --platform linux/amd64 -t "$IMAGE_TAG" --load \
  "$TI_AGENTS_DIR/docker-images/build-machines/linux/"

# 2. Build the native .so + java trampoline jar inside the container.
#    Mount the ti-agents repo at /work and run as root so the build can write
#    to the host mount without a slow `chmod -R` over the whole repo tree.
#    The dotnet SDK lives under /home/builder/.dotnet (world-readable/executable).
#    No `dotnet workload install native-aot` is needed: .NET 9 ships NativeAOT
#    via the Microsoft.DotNet.ILCompiler NuGet package, restored by PublishAot=true.
echo ""
echo "==> Building ti-agent.so (NativeAOT) + java-agent-trampoline.jar..."
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

# 3. Copy artifacts into this repo.
SO_SRC="$TI_AGENTS_DIR/ti-agent/pack/ti-agent.so"
JAR_SRC="$TI_AGENTS_DIR/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar"
[ -f "$SO_SRC" ]  || die "build did not produce $SO_SRC"
[ -f "$JAR_SRC" ] || die "build did not produce $JAR_SRC"

mkdir -p "$OUT_DIR"
cp "$SO_SRC"  "$OUT_DIR/ti-agent.so"
cp "$JAR_SRC" "$OUT_DIR/java-agent-trampoline.jar"

# 4. Verify.
echo ""
echo "==> Verifying artifacts..."
SO_INFO=$(file "$OUT_DIR/ti-agent.so")
echo "  ti-agent.so: $SO_INFO"
echo "$SO_INFO" | grep -q 'ELF 64-bit LSB shared object, x86-64' \
  || die "ti-agent.so is NOT a Linux x86-64 ELF — wrong arch build"

JAR_ENTRIES=$(jar tf "$OUT_DIR/java-agent-trampoline.jar" 2>/dev/null || true)
echo "$JAR_ENTRIES" | grep -q 'callgraph-boot.jar'   || die "trampoline jar missing callgraph-boot.jar"
echo "$JAR_ENTRIES" | grep -q 'callgraph-agent.jar'  || die "trampoline jar missing callgraph-agent.jar"
echo "$JAR_ENTRIES" | grep -q 'harness/callgraph/trampoline/TrampolineAgent.class' \
  || die "trampoline jar missing TrampolineAgent.class"
echo "  java-agent-trampoline.jar: OK (boot+agent jars + TrampolineAgent present)"

echo ""
echo "==> Done. Artifacts in $OUT_DIR:"
ls -la "$OUT_DIR"
echo ""
echo "Next: git add ti-agent-artifacts/ and commit, then run the integration_tests_simple pipeline."
