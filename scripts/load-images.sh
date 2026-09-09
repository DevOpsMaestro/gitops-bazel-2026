#!/usr/bin/env bash
# Load cached images from local Docker into an existing KinD cluster.
#
# Use this after destroying and recreating a cluster when images are already
# in local Docker cache — skips all registry traffic for the bootstrap step.
set -euo pipefail
cd "${BUILD_WORKSPACE_DIRECTORY:-$(git rev-parse --show-toplevel)}"
source versions.env

BOOTSTRAP_IMAGES=(
  "quay.io/cilium/cilium:v$CILIUM_VERSION"
  "quay.io/cilium/operator-generic:v$CILIUM_VERSION"
  "quay.io/cilium/hubble-relay:v$CILIUM_VERSION"
  "docker.io/istio/proxyv2:$ISTIO_VERSION"
)

printf '\nLoading bootstrap images into KinD cluster "%s" nodes...\n' "$CLUSTER_NAME"
# Load each image to all nodes in parallel (one docker save pipe per node),
# then wait before moving to the next image to cap concurrent IO.
for img in "${BOOTSTRAP_IMAGES[@]}"; do
  printf '  %s\n' "$img"
  for NODE in $(kind get nodes --name "$CLUSTER_NAME"); do
    (docker save "$img" | docker exec -i "$NODE" \
      ctr --namespace=k8s.io images import --digests --snapshotter=overlayfs -) &
  done
  wait
done
printf '✓ Done. Images are loaded into all cluster nodes.\n\n'
