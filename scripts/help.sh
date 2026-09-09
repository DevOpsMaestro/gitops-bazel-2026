#!/usr/bin/env bash
# Show available bazel run targets.
set -euo pipefail

targets=(
  "bootstrap|Full cluster bootstrap — preflight → images → kind → cilium → flux"
  "destroy|Tear down all KinD clusters and optionally prune local Docker images"
  "branch|Update Flux GitRepository branch patch to match the current git branch"
  "pull-images|Pre-pull all bootstrap images to local Docker cache"
  "load-images|Load cached images from local Docker into an existing KinD cluster"
  "cache-running|Pull every image currently running in the cluster to local Docker"
  "check-tools|Verify required CLI tools are installed"
  "sops-setup|Generate Age key pair for SOPS (skips if key already exists)"
  "sops-load-key|Load Age private key into cluster as sops-age secret (run after bootstrap)"
  "grafana-secret|Generate a stable Grafana secret_key and apply it (run once after bootstrap)"
  "status|Show Flux reconciliation state across all namespaces"
  "check-crd-count|Warn if installed CRD count approaches the etcd slow-list threshold (>150)"
  "etcd-status|Show etcd database size, in-use bytes, and fragmentation percentage"
  "etcd-defrag|Defragment the etcd database to reclaim fragmented space"
  "watch|Watch Flux reconcile every 6 s (Ctrl-C to stop)"
  "validate|Validate all kustomize manifests locally (mirrors CI validate step)"
  "test-policies|Run Kyverno CLI policy unit tests"
  "test-istio|Verify Istio service mesh — istiod, injection, proxy sync, mTLS, config analysis"
  "test-kyverno|Verify Kyverno admission control — controllers, policies, live enforcement"
  "test-falco|Validate Falco detects runtime threats via event-generator"
  "test-kubescape|Run Kubescape NSA+MITRE posture scan against the live cluster"
  "test-cluster|Smoke-test a running cluster — Flux, Grafana, Prometheus, Loki, Kyverno"
  "test-contour|Verify Contour ingress — pods, HTTPProxy CRs, and all three HTTP routes"
  "test-iperf3|Baseline bandwidth test — single stream, 30 s, through nginx stream proxy"
  "iperf3-enable|Enable iperf3 — uncomments its entry in apps/overlays/kind/kustomization.yaml"
  "iperf3-disable|Disable iperf3 — comments out its entry in apps/overlays/kind/kustomization.yaml"
)

printf '\nUsage: bazel run //:<target>\n\n'
for entry in "${targets[@]}"; do
  name="${entry%%|*}"
  desc="${entry#*|}"
  printf '  %-16s %s\n' "$name" "$desc"
done
printf '\n'
