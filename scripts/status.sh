#!/usr/bin/env bash
# Show Flux reconciliation state across all namespaces.
set -euo pipefail
flux get all -A
