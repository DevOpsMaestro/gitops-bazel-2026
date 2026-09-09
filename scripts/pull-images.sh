#!/usr/bin/env bash
# Pre-pull all bootstrap images to local Docker cache.
#
# KinD node image, Cilium/Hubble/Istio images, and cilium-envoy (resolved
# from the Helm chart) are pulled so that `bazel run //:bootstrap` can load
# them from local Docker instead of the registry.
set -euo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"
source versions.env

LOCAL_ARCH=$(uname -m)
if [ "$LOCAL_ARCH" = "arm64" ]; then
  DOCKER_PLATFORM=linux/arm64
else
  DOCKER_PLATFORM=linux/amd64
fi

BOOTSTRAP_IMAGES=(
  "quay.io/cilium/cilium:v$CILIUM_VERSION"
  "quay.io/cilium/operator-generic:v$CILIUM_VERSION"
  "quay.io/cilium/hubble-relay:v$CILIUM_VERSION"
  "docker.io/istio/proxyv2:$ISTIO_VERSION"
)

# KinD node image — pulled by `kind create cluster` but pre-pulling avoids
# a ~700 MB download during bootstrap where failure is more disruptive.
printf '\n==> KinD node image\n'
docker pull --platform "$DOCKER_PLATFORM" "kindest/node:$K8S_VER"

# Core bootstrap images — pulled in parallel (different registries, no benefit
# to serialising). Each image prints on completion so failures are visible.
printf '\n==> Cilium + Hubble + Istio images (parallel pull)\n'
for img in "${BOOTSTRAP_IMAGES[@]}"; do
  (docker pull --platform "$DOCKER_PLATFORM" "$img" --quiet > /dev/null 2>&1 \
    && printf '    ✓ %s\n' "$img" \
    || printf '    ✗ FAILED: %s\n' "$img") &
done
wait

# cilium-envoy — the tag is not a simple version string; it is constructed
# from a hash embedded in the chart and resolved at render time. We extract
# it here from `helm template` so the pin is always correct for the chart.
printf '\n==> cilium-envoy (resolved from Helm chart v%s)\n' "$CILIUM_VERSION"
helm repo add cilium https://helm.cilium.io --force-update > /dev/null 2>&1 || true
ENVOY_IMG=$(helm template cilium cilium/cilium \
    --version "$CILIUM_VERSION" \
    --namespace kube-system \
    --set kubeProxyReplacement=true 2>/dev/null \
  | grep 'image: quay.io/cilium/cilium-envoy' \
  | head -1 | awk '{print $2}' | tr -d '"')
if [ -n "$ENVOY_IMG" ]; then
  printf '    %-70s' "$ENVOY_IMG"
  docker pull --platform "$DOCKER_PLATFORM" "$ENVOY_IMG" --quiet > /dev/null 2>&1 \
    && printf ' done\n' || printf ' FAILED\n'
else
  printf '    ⚠  image not resolved — it will pull from the registry at runtime\n'
fi

printf '\n✓ Docker cache warmed. Run: bazel run //:bootstrap\n\n'
