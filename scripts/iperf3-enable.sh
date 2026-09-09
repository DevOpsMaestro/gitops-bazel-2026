#!/usr/bin/env bash
# Enable iperf3 — uncomments its entry in apps/overlays/kind/kustomization.yaml.
set -euo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"

sed -i '' 's|^  # - ../../base/iperf3.*|  - ../../base/iperf3|' \
  apps/overlays/kind/kustomization.yaml
grep -q '^  - ../../base/iperf3$' apps/overlays/kind/kustomization.yaml \
  && printf '\n✓ iperf3 enabled in apps/overlays/kind/kustomization.yaml\n  Commit and push to deploy via Flux.\n\n' \
  || { printf '\n✗ Pattern not matched — inspect apps/overlays/kind/kustomization.yaml\n\n'; exit 1; }
