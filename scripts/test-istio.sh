#!/usr/bin/env bash
# Verify Istio service mesh — istiod, injection, proxy sync, mTLS, and config analysis.
# Requires: running cluster + istioctl
set -uo pipefail

kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
command -v istioctl >/dev/null 2>&1 \
  || { printf '\n  ✗ istioctl not found — install: brew install istioctl\n\n'; exit 1; }
printf '\n==> Istio service mesh verification\n'
PASS=0; FAIL=0

printf '[1/5] istiod running... '
if kubectl get pods -n istio-system -l app=istiod --no-headers 2>/dev/null | grep -q Running; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL\n'; FAIL=$((FAIL+1))
fi

printf '[2/5] Injection enabled: demo and observability namespaces... '
INJECTING=$(kubectl get namespace demo observability \
     -o jsonpath='{range .items[*]}{.metadata.labels.istio-injection}{"\n"}{end}' 2>/dev/null \
     | grep -c '^enabled$')
if [ "$INJECTING" -eq 2 ]; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL (%s/2 namespaces labelled)\n' "$INJECTING"; FAIL=$((FAIL+1))
fi

printf '[3/5] All proxies subscribed to istiod xDS... '
PROXY_COUNT=$(istioctl proxy-status 2>/dev/null | tail -n +2 | grep -c .)
SYNCED_COUNT=$(istioctl proxy-status 2>/dev/null | tail -n +2 \
     | grep -c '4 (CDS,LDS,EDS,RDS)' || true)
if [ "$PROXY_COUNT" -gt 0 ] && [ "$PROXY_COUNT" -eq "$SYNCED_COUNT" ]; then
  printf 'ok (%s proxy/proxies)\n' "$PROXY_COUNT"; PASS=$((PASS+1))
else
  printf 'FAIL (%s/%s synced)\n' "$SYNCED_COUNT" "$PROXY_COUNT"
  istioctl proxy-status 2>/dev/null
  FAIL=$((FAIL+1))
fi

printf '[4/5] mTLS in use: X-Forwarded-Client-Cert header present... '
XFCC=$(kubectl exec -n demo deploy/load-generator -c curl -- \
     curl -s --max-time 5 http://httpbin.demo.svc.cluster.local/get 2>/dev/null \
     | grep -c 'X-Forwarded-Client-Cert' || true)
if [ "$XFCC" -gt 0 ]; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL — header absent; Istio sidecar may not be intercepting traffic\n'
  FAIL=$((FAIL+1))
fi

printf '[5/5] No errors or warnings from istioctl analyze... '
ISSUES=$(istioctl analyze --all-namespaces 2>/dev/null \
     | grep -cE '^(Warning|Error)' || true)
if [ "$ISSUES" -eq 0 ]; then
  printf 'ok\n'; PASS=$((PASS+1))
else
  printf 'FAIL (%s issue(s))\n' "$ISSUES"
  istioctl analyze --all-namespaces 2>/dev/null | grep -E '^(Warning|Error)'
  FAIL=$((FAIL+1))
fi

printf '\n  result: %d/5 checks passed\n' "$PASS"
[ "$FAIL" = "0" ] \
  && printf '✓ Istio service mesh test passed\n\n' \
  || { printf '✗ Some checks failed — run: istioctl analyze --all-namespaces\n\n'; exit 1; }
