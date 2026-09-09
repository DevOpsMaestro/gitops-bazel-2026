#!/usr/bin/env bash
# Generate Age key pair for SOPS (skips if key already exists).
set -euo pipefail

KEY_FILE="$HOME/.config/sops/age/keys.txt"
if [ -f "$KEY_FILE" ]; then
  printf '\n  Age key already exists at %s\n' "$KEY_FILE"
  printf '  Public key: %s\n\n' "$(grep 'public key' "$KEY_FILE" | awk '{print $NF}')"
else
  mkdir -p "$(dirname "$KEY_FILE")"
  age-keygen -o "$KEY_FILE"
  printf '\n  ✓ Key written to %s\n' "$KEY_FILE"
  printf '  Public key: %s\n' "$(grep 'public key' "$KEY_FILE" | awk '{print $NF}')"
  printf '\n  Next: paste the public key into .sops.yaml, then run: bazel run //:sops-load-key\n\n'
fi
