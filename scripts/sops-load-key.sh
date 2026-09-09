#!/usr/bin/env bash
# Load Age private key into cluster as sops-age secret (run after bootstrap).
set -euo pipefail

KEY_FILE="$HOME/.config/sops/age/keys.txt"
if [ ! -f "$KEY_FILE" ]; then
  printf '\n  ✗ Age key not found — run: bazel run //:sops-setup\n\n'; exit 1
fi
kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
cat "$KEY_FILE" | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin \
  --dry-run=client -o yaml | kubectl apply -f -
printf '  ✓ sops-age secret loaded into flux-system\n\n'
