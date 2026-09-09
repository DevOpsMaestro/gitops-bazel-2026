#!/usr/bin/env bash
# Verify Contour ingress — pods, HTTPProxy CRs, and all three HTTP routes.
set -uo pipefail

kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
printf '\n==> Contour ingress verification\n'
PASS=0; FAIL=0

printf '[1/6] Contour controller running... '
if kubectl get pods -n contour -l app.kubernetes.io/component=contour \
     --no-headers 2>/dev/null | grep -q Running; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL\n'; FAIL=$((FAIL+1))
fi

printf '[2/6] Contour Envoy DaemonSet running... '
ENVOY_READY=$(kubectl get pods -n contour -l app.kubernetes.io/component=envoy \
     --no-headers 2>/dev/null | grep -c Running)
if [ "$ENVOY_READY" -gt 0 ]; then
  printf 'ok (%s pod(s))\n' "$ENVOY_READY"; PASS=$((PASS+1))
else
  printf 'FAIL\n'; FAIL=$((FAIL+1))
fi

printf '[3/6] All HTTPProxy CRs valid... '
INVALID=$(kubectl get httpproxy -A --no-headers 2>/dev/null | grep -vc ' valid ')
TOTAL=$(kubectl get httpproxy -A --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [ "$TOTAL" -gt 0 ] && [ "$INVALID" = "0" ]; then
  printf 'ok (%s proxy/proxies)\n' "$TOTAL"; PASS=$((PASS+1))
else
  printf 'FAIL (%s invalid or missing)\n' "$INVALID"
  kubectl get httpproxy -A --no-headers 2>/dev/null | grep -v ' valid '
  FAIL=$((FAIL+1))
fi

printf '[4/6] Route httpbin-contour.local → HTTP 200... '
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
          -H 'Host: httpbin-contour.local' http://localhost:8080/get)
if [ "$CODE" = "200" ]; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL (got %s)\n' "$CODE"; FAIL=$((FAIL+1))
fi

printf '[5/6] Route grafana.local → HTTP 302... '
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
          -H 'Host: grafana.local' http://localhost:8080/)
if [ "$CODE" = "302" ]; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL (got %s)\n' "$CODE"; FAIL=$((FAIL+1))
fi

printf '[6/6] Route prometheus.local → HTTP 302... '
CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
          -H 'Host: prometheus.local' http://localhost:8080/)
if [ "$CODE" = "302" ]; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL (got %s)\n' "$CODE"; FAIL=$((FAIL+1))
fi

printf '\n  result: %d/6 checks passed\n' "$PASS"
[ "$FAIL" = "0" ] \
  && printf '✓ Contour ingress test passed\n\n' \
  || { printf '✗ Some checks failed — run: kubectl get httpproxy -A\n\n'; exit 1; }
