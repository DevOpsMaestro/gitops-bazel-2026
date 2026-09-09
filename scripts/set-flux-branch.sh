#!/bin/bash
# Updates the Flux GitRepository branch patch to match the current git branch,
# then commits and pushes. Run once after creating a new branch.
#
# Usage (run from repo root):
#   ./scripts/set-flux-branch.sh
#   ./scripts/set-flux-branch.sh my-other-branch   # override the target branch
set -e

# $BUILD_WORKSPACE_DIRECTORY is set by `bazel run` and points at the real
# workspace — needed since this script's relative paths and git commands
# assume cwd is the repo root.
REPO_ROOT="${BUILD_WORKSPACE_DIRECTORY:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$REPO_ROOT"

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"
PATCH_FILE="clusters/kind/flux-system/kustomization.yaml"

current=$(grep "branch:" "$PATCH_FILE" | awk '{print $2}')

if [[ "$current" == "$BRANCH" ]]; then
  printf "Flux branch is already set to '%s' — nothing to do.\n" "$BRANCH"
  exit 0
fi

sed -i '' "s|branch: .*|branch: ${BRANCH}|" "$PATCH_FILE"
printf "Updated Flux branch: %s → %s\n" "$current" "$BRANCH"

git add "$PATCH_FILE"
git commit -m "chore: point Flux GitRepository at branch ${BRANCH}"
git push origin "$BRANCH"

printf "✓ Flux will now track branch '%s'\n" "$BRANCH"
