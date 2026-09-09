#!/usr/bin/env bash
# Disable iperf3 — comments out its entry in apps/overlays/kind/kustomization.yaml.
set -euo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"

sed -i '' 's|^  - ../../base/iperf3$|  # - ../../base/iperf3        # iperf3 feature flag — run: bazel run //:iperf3-enable to restore|' \
  apps/overlays/kind/kustomization.yaml
grep -q '^  # - ../../base/iperf3' apps/overlays/kind/kustomization.yaml \
  && printf '\n✓ iperf3 disabled in apps/overlays/kind/kustomization.yaml\n  Commit and push to remove via Flux (prune: true will delete the namespace).\n\n' \
  || { printf '\n✗ Pattern not matched — inspect apps/overlays/kind/kustomization.yaml\n\n'; exit 1; }
