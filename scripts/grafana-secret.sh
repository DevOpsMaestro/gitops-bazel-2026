#!/usr/bin/env bash
# Generate a stable Grafana secret_key and apply it (run once after bootstrap).
set -euo pipefail

kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
if kubectl get secret grafana-secret-key -n observability >/dev/null 2>&1; then
  printf '\n  ✓ grafana-secret-key already exists in observability — skipping\n\n'
else
  KEY=$(openssl rand -base64 32)
  kubectl create secret generic grafana-secret-key \
    --namespace=observability \
    --from-literal=secret-key="$KEY"
  printf '  ✓ grafana-secret-key created — Grafana sessions will now persist across restarts\n\n'
fi
