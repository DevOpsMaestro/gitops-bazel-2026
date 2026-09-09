#!/usr/bin/env bash
# Baseline bandwidth test — single stream, 30 s, through nginx stream proxy.
set -euo pipefail

kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
kubectl get pods -n iperf3 -l app=iperf3-server --no-headers 2>/dev/null \
  | grep -q Running \
  || { printf '\n  ✗ iperf3 server not running — check: kubectl get pods -n iperf3\n\n'; exit 1; }
command -v iperf3 >/dev/null 2>&1 \
  || { printf '\n  ✗ iperf3 not found — install: brew install iperf3\n\n'; exit 1; }
printf '\n==> iperf3 baseline bandwidth test (single stream, 30 s)\n'
printf '    Path: localhost:32111 → nginx stream{} → iperf3 Service :32111 → iperf3 pod\n\n'
iperf3 -4 -c localhost -p 32111 -t 30
printf '\n✓ Baseline test complete\n\n'
