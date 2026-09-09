#!/usr/bin/env bash
# Warn if installed CRD count approaches the etcd slow-list threshold (>150).
set -euo pipefail

count=$(kubectl get crds --no-headers 2>/dev/null | wc -l | tr -d ' ')
printf "Installed CRDs: %s\n" "$count"
if [ "$count" -gt 150 ]; then
  printf "WARNING: CRD count %s exceeds 150.\n" "$count"
  printf "High CRD counts slow etcd LIST responses and cause watch-mark-send-over-slow-network\n"
  printf "warnings. Review Helm chart CRD installations; consider disabling unused capabilities.\n"
  exit 1
fi
