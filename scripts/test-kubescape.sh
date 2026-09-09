#!/usr/bin/env bash
# Run Kubescape NSA+MITRE posture scan against the live cluster.
set -euo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"
source versions.env

command -v kubescape >/dev/null 2>&1 \
  || { printf '\n  ✗ kubescape not found — install: brew install kubescape\n\n'; exit 1; }
kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
printf '\n==> Kubescape security posture scan (NSA + MITRE)\n'
kubescape scan framework nsa,mitre \
  --kube-context "kind-$CLUSTER_NAME" \
  --format pretty-printer \
  --verbose
