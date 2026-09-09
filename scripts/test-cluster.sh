#!/usr/bin/env bash
# Smoke-test a running cluster — Flux, Grafana, Prometheus, Loki, Kyverno.
set -uo pipefail

kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
kubectl get pods -n flux-system -l app=source-controller --no-headers 2>/dev/null \
  | grep -q Running \
  || { printf '\n  ✗ Flux is not running — check: kubectl get pods -n flux-system\n\n'; exit 1; }
printf '\n==> Cluster smoke test\n'
PASS=0; FAIL=0

printf '[1/5] Flux HelmReleases all reconciled... '
NOTREADY=$(flux get helmreleases -A --no-header 2>/dev/null | grep -v 'True' | wc -l | tr -d ' ')
if [ "$NOTREADY" = "0" ]; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL (%s release(s) not ready)\n' "$NOTREADY"
  flux get helmreleases -A --no-header 2>/dev/null | grep -v 'True'
  FAIL=$((FAIL+1))
fi

printf '[2/5] Grafana API health... '
kubectl port-forward -n observability svc/observability-grafana 19080:80 >/dev/null 2>&1 & PF_PID=$!
TRIES=0; until nc -z localhost 19080 2>/dev/null || [ $TRIES -ge 10 ]; do sleep 1; TRIES=$((TRIES+1)); done
if curl -sf --max-time 5 http://localhost:19080/api/health 2>/dev/null | grep -q '"database":"ok"'; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL\n'; FAIL=$((FAIL+1))
fi
kill $PF_PID 2>/dev/null; wait $PF_PID 2>/dev/null

printf '[3/5] Prometheus active targets... '
kubectl port-forward -n observability svc/observability-kube-prometh-prometheus 19090:9090 >/dev/null 2>&1 & PF_PID=$!
TRIES=0; until nc -z localhost 19090 2>/dev/null || [ $TRIES -ge 10 ]; do sleep 1; TRIES=$((TRIES+1)); done
TARGET_COUNT=$(curl -sf --max-time 5 'http://localhost:19090/api/v1/targets?state=active' 2>/dev/null \
  | grep -o '"health"' | wc -l | tr -d ' ')
kill $PF_PID 2>/dev/null; wait $PF_PID 2>/dev/null
if [ "$TARGET_COUNT" -gt 0 ]; then
  printf 'ok (%s active targets)\n' "$TARGET_COUNT"; PASS=$((PASS+1))
else
  printf 'FAIL (no active targets)\n'; FAIL=$((FAIL+1))
fi

printf '[4/5] Loki ready endpoint... '
kubectl port-forward -n observability svc/observability-loki 19100:3100 >/dev/null 2>&1 & PF_PID=$!
TRIES=0; until nc -z localhost 19100 2>/dev/null || [ $TRIES -ge 10 ]; do sleep 1; TRIES=$((TRIES+1)); done
if curl -sf --max-time 5 http://localhost:19100/ready 2>/dev/null | grep -q 'ready'; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL\n'; FAIL=$((FAIL+1))
fi
kill $PF_PID 2>/dev/null; wait $PF_PID 2>/dev/null

printf '[5/5] Kyverno admission controller running... '
if kubectl get pods -n kyverno -l app.kubernetes.io/component=admission-controller \
     --no-headers 2>/dev/null | grep -q Running; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL\n'; FAIL=$((FAIL+1))
fi

printf '\n  result: %d/5 checks passed\n' "$PASS"
[ "$FAIL" = "0" ] \
  && printf '✓ Cluster smoke test passed\n\n' \
  || { printf '✗ Some checks failed — run: kubectl get pods -A\n\n'; exit 1; }
