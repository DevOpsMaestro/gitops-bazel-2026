#!/usr/bin/env bash
# Verify required CLI tools are installed.
set -euo pipefail

printf '\nChecking required tools:\n'
for tool in docker kind kubectl helm flux kustomize gh kyverno kubescape age sops; do
  if command -v "$tool" > /dev/null 2>&1; then
    printf '  ✓ %s\n' "$tool"
  else
    printf '  ✗ %s  (not found — install via brew)\n' "$tool"
  fi
done
printf '\n'
