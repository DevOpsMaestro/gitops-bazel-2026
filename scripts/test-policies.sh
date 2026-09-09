#!/usr/bin/env bash
# Run Kyverno CLI policy unit tests.
set -euo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"
kyverno test apps/base/kyverno/tests/
