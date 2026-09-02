#!/bin/bash
# Mirror container images used by the cluster into a local registry.
# Run on an internet-connected machine that can reach both upstream registries and your local registry.
set -euo pipefail
source /etc/os-release
[[ "${ID:-}" == rhel && "${VERSION_ID%%.*}" == 9 ]] || { echo 'ERROR: this script requires RHEL 9.' >&2; exit 1; }

LOCAL_REGISTRY="${1:-harbor.airgap.local/library}"
IMAGE_MANIFEST="${2:-/opt/airgap/images/images.txt}"
[[ -s "$IMAGE_MANIFEST" ]] || { echo "Image manifest not found or empty: $IMAGE_MANIFEST" >&2; exit 1; }
mapfile -t IMAGES < <(sed '/^[[:space:]]*$/d' "$IMAGE_MANIFEST")

# Select container tool
if command -v docker &>/dev/null; then
  CRI=docker
elif command -v podman &>/dev/null; then
  CRI=podman
else
  echo "docker or podman is required" >&2
  exit 1
fi

mirror_image() {
  local src="$1"
  local dst="${LOCAL_REGISTRY}/${src#*/}"
  echo "Mirroring ${src} -> ${dst}"
  ${CRI} pull "${src}" || { echo "Failed to pull ${src}"; exit 1; }
  ${CRI} tag "${src}" "${dst}"
  ${CRI} push "${dst}" || { echo "Failed to push ${dst}"; exit 1; }
}

for img in "${IMAGES[@]}"; do
  mirror_image "${img}"
done

echo "=== Image mirror complete ==="
