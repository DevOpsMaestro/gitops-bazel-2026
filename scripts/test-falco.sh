#!/usr/bin/env bash
# Validate Falco detects runtime threats via event-generator.
# Requires: running cluster
set -uo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"

EVENT_GENERATOR_VERSION=0.13.0

kubectl cluster-info >/dev/null 2>&1 \
  || { printf '\n  ✗ No cluster — run: bazel run //:bootstrap\n\n'; exit 1; }
kubectl get pods -n falco -l app.kubernetes.io/name=falco --no-headers 2>/dev/null \
  | grep -q Running \
  || { printf '\n  ✗ Falco is not running — check: kubectl get pods -n falco\n\n'; exit 1; }
printf '\n==> Deploying Falco event-generator (v%s)...\n' "$EVENT_GENERATOR_VERSION"
START_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
kubectl apply -f tests/falco/ >/dev/null
printf '==> Waiting for events to be fired (up to 90 s)...\n'
kubectl wait --for=condition=complete --timeout=90s \
    job/falco-event-generator -n falco-test 2>/dev/null \
  || { printf '\n  ✗ Job did not complete in time\n'
       printf '     kubectl logs -n falco-test job/falco-event-generator\n\n'
       kubectl delete namespace falco-test --ignore-not-found >/dev/null 2>&1
       exit 1; }
printf '\n==> Checking Falco detections on the event node...\n'
NODE=$(kubectl get pod -n falco-test -l job-name=falco-event-generator \
        -o jsonpath='{.items[0].spec.nodeName}' 2>/dev/null)
FALCO_POD=$(kubectl get pod -n falco -l app.kubernetes.io/name=falco \
             --field-selector="spec.nodeName=$NODE" -o name 2>/dev/null | head -1)
LOGS=$(kubectl logs "$FALCO_POD" -n falco --since-time="$START_TS" 2>/dev/null)
PASS=0; FAIL=0
for RULE in \
    "Read sensitive file untrusted" \
    "Run shell untrusted" \
    "Find AWS Credentials" \
    "Search Private Keys or Passwords"; do
  if printf '%s' "$LOGS" | grep -q "$RULE"; then
    printf '  ✓ %s\n' "$RULE"; PASS=$((PASS+1))
  else
    printf '  ✗ %s  (not detected)\n' "$RULE"; FAIL=$((FAIL+1))
  fi
done
printf '\n  result: %d/%d rules detected\n' "$PASS" "$((PASS+FAIL))"
kubectl delete namespace falco-test --ignore-not-found >/dev/null 2>&1
[ "$FAIL" = "0" ] \
  && printf '✓ Falco detection test passed\n\n' \
  || { printf '✗ Missing detections — Falco logs: kubectl logs -n falco %s\n\n' "$FALCO_POD"; exit 1; }
