#!/bin/bash
set -e

# Source shared version pins so $CLUSTER_NAME and $K8S_VER are defined.
# $BUILD_WORKSPACE_DIRECTORY is set by `bazel run` and points at the real
# workspace — BASH_SOURCE-relative lookup breaks there since the executed
# file is Bazel's launcher stub, not this script in place under scripts/.
REPO_ROOT="${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$REPO_ROOT"
# shellcheck source=../versions.env
source "${REPO_ROOT}/versions.env"

echo "🗑  Deleting KinD cluster: $CLUSTER_NAME"
kind delete cluster --name "$CLUSTER_NAME"

# Optional cleanup
read -p "🧹 Do you want to remove the local KinD node image? [y/N]: " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
  echo "🧽 Removing KinD node image (kindest/node:${K8S_VER})..."
  docker rmi "kindest/node:${K8S_VER}" 2>/dev/null || true
fi

echo "✅ Teardown complete."
exit 0
