#!/usr/bin/env bash
# Verify Kyverno admission control — controllers, policies, and live enforcement.
# Requires: running cluster
set -uo pipefail

kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
printf '\n==> Kyverno admission control verification\n'
PASS=0; FAIL=0

printf '[1/4] All Kyverno controllers running... '
RUNNING=$(kubectl get pods -n kyverno -l app.kubernetes.io/part-of=kyverno-kyverno \
     --no-headers 2>/dev/null | grep -c Running)
if [ "$RUNNING" -ge 4 ]; then
  printf 'ok (%s pod(s))\n' "$RUNNING"; PASS=$((PASS+1))
else
  printf 'FAIL (%s/4 running)\n' "$RUNNING"
  kubectl get pods -n kyverno --no-headers 2>/dev/null
  FAIL=$((FAIL+1))
fi

printf '[2/4] All ClusterPolicies Ready... '
NOT_READY=$(kubectl get clusterpolicies --no-headers 2>/dev/null | grep -vc 'Ready')
TOTAL_POL=$(kubectl get clusterpolicies --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$TOTAL_POL" -gt 0 ] && [ "$NOT_READY" = "0" ]; then
  printf 'ok (%s policies)\n' "$TOTAL_POL"; PASS=$((PASS+1))
else
  printf 'FAIL (%s not Ready)\n' "$NOT_READY"
  kubectl get clusterpolicies --no-headers 2>/dev/null | grep -v 'Ready'
  FAIL=$((FAIL+1))
fi

printf '[3/4] Enforce: pod without resource limits is blocked (dry-run)... '
if printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: kyverno-test\n  namespace: default\nspec:\n  containers:\n  - name: t\n    image: busybox:1.36.1\n    securityContext:\n      allowPrivilegeEscalation: false\n' \
     | kubectl apply --dry-run=server -f - 2>&1 | grep -q 'denied the request'; then
  printf 'ok — admission blocked\n'; PASS=$((PASS+1))
else
  printf 'FAIL — require-resource-limits policy did not block\n'; FAIL=$((FAIL+1))
fi

printf '[4/4] Enforce: allowPrivilegeEscalation: true is blocked (dry-run)... '
if printf 'apiVersion: v1\nkind: Pod\nmetadata:\n  name: kyverno-test\n  namespace: default\nspec:\n  containers:\n  - name: t\n    image: busybox:1.36.1\n    securityContext:\n      allowPrivilegeEscalation: true\n    resources:\n      requests:\n        cpu: 100m\n        memory: 64Mi\n      limits:\n        cpu: 100m\n        memory: 64Mi\n' \
     | kubectl apply --dry-run=server -f - 2>&1 | grep -q 'denied the request'; then
  printf 'ok — admission blocked\n'; PASS=$((PASS+1))
else
  printf 'FAIL — disallow-privilege-escalation policy did not block\n'; FAIL=$((FAIL+1))
fi

printf '\n  result: %d/4 checks passed\n' "$PASS"
[ "$FAIL" = "0" ] \
  && printf '✓ Kyverno admission control test passed\n\n' \
  || { printf '✗ Some checks failed — run: kubectl get clusterpolicies\n\n'; exit 1; }
