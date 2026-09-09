#!/usr/bin/env bash
# Validate all kustomize manifests locally (mirrors CI validate step).
set -euo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"

command -v kustomize >/dev/null 2>&1 \
  || { printf '\n  ✗ kustomize not found — install: brew install kustomize\n\n'; exit 1; }
for dir in \
    infrastructure/controllers \
    apps/base/prometheus apps/base/grafana apps/base/loki apps/base/promtail \
    apps/base/tempo apps/base/opentelemetry apps/base/kyverno apps/base/demo \
    apps/base/notifications apps/base/istio apps/base/envoy-gateway \
    apps/overlays/kind clusters/kind; do
  printf '  kustomize build %s\n' "$dir"
  kustomize build "$dir" > /dev/null
done
printf '✓ All manifests valid\n'
