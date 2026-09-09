#!/usr/bin/env bash
# Watch Flux reconcile every 6 s (Ctrl-C to stop).
set -euo pipefail
watch -n 6 "flux get all -A"
