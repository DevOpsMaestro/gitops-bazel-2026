#!/usr/bin/env bash
# Defragment the etcd database to reclaim fragmented space.
set -euo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"

ETCD_POD=etcd-flux-kind-control-plane
ETCD_NS=kube-system
ETCD_FLAGS=(--endpoints=localhost:2379
            --cacert=/etc/kubernetes/pki/etcd/ca.crt
            --cert=/etc/kubernetes/pki/etcd/server.crt
            --key=/etc/kubernetes/pki/etcd/server.key)

kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
printf '\n==> etcd defragmentation\n'
printf 'Before:\n'
kubectl exec -n "$ETCD_NS" "$ETCD_POD" -- \
  /usr/local/bin/etcdctl "${ETCD_FLAGS[@]}" endpoint status --write-out=json 2>/dev/null \
  | python3 scripts/etcd_frag_line.py
printf '\nRunning defrag (this briefly pauses etcd writes)...\n'
kubectl exec -n "$ETCD_NS" "$ETCD_POD" -- \
  /usr/local/bin/etcdctl "${ETCD_FLAGS[@]}" defrag 2>/dev/null \
  && printf '✓ Defrag complete\n' \
  || { printf '✗ Defrag failed\n'; exit 1; }
printf '\nAfter:\n'
kubectl exec -n "$ETCD_NS" "$ETCD_POD" -- \
  /usr/local/bin/etcdctl "${ETCD_FLAGS[@]}" endpoint status --write-out=json 2>/dev/null \
  | python3 scripts/etcd_frag_line.py
printf '\n'
