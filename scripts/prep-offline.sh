#!/usr/bin/env bash
# Connected-side builder for the RHEL9/RKE2 air-gap bundle.
# Run this on an INTERNET-CONNECTED RHEL9 amd64 staging host.
set -euo pipefail

DEST="${1:-$PWD/airgap-bundle}"
PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RKE2_VERSION="${RKE2_VERSION:-v1.36.4+rke2r1}"
RKE2_SELINUX_VERSION="${RKE2_SELINUX_VERSION:-0.23}"
RKE2_SELINUX_RELEASE="${RKE2_SELINUX_RELEASE:-1}"
HELM_VERSION="${HELM_VERSION:-v4.2.4}"
K9S_VERSION="${K9S_VERSION:-v0.51.0}"
METALLB_VERSION="${METALLB_VERSION:-0.16.1}"
LONGHORN_VERSION="${LONGHORN_VERSION:-1.12.1}"
HARBOR_CHART_VERSION="${HARBOR_CHART_VERSION:-1.19.2}"
GITEA_CHART_VERSION="${GITEA_CHART_VERSION:-12.7.0}"
GITEA_APP_VERSION="${GITEA_APP_VERSION:-1.27.3}"
ANSIBLE_POSIX_VERSION="${ANSIBLE_POSIX_VERSION:-1.6.2}"
ARCH="${ARCH:-amd64}"

if [[ -e "$DEST" && ! -d "$DEST" ]]; then
  echo "ERROR: destination exists and is not a directory: $DEST" >&2
  exit 1
fi
if [[ -d "$DEST" && -n "$(find "$DEST" -mindepth 1 -print -quit)" ]]; then
  echo "ERROR: destination must be empty to prevent stale charts or images: $DEST" >&2
  exit 1
fi
mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"
mkdir -p "$DEST"/{artifacts,charts,images,rpm,collections,certs,manifests,checksums,logs}
exec > >(tee "$DEST/logs/prep-offline.log") 2>&1
for path in inventory group_vars host_vars playbooks roles scripts; do
  cp -a "$PACKAGE_ROOT/$path" "$DEST/"
done
cp -a "$PACKAGE_ROOT/collections/." "$DEST/collections/"
cp -a "$PACKAGE_ROOT/ansible.cfg" "$PACKAGE_ROOT/README.md" "$PACKAGE_ROOT/CHANGELOG.md" "$PACKAGE_ROOT/VERSION" "$DEST/"
chmod +x "$DEST"/scripts/*.sh

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required command '$1' is missing" >&2; exit 1; }; }
for c in curl sha256sum helm python3 tar dnf rpm uname; do need_cmd "$c"; done
source /etc/os-release
[[ "${ID:-}" == rhel && "${VERSION_ID%%.*}" == 9 ]] || { echo 'ERROR: run this on a RHEL 9 staging host.' >&2; exit 1; }
[[ "$(uname -m)" == x86_64 && "$ARCH" == amd64 ]] || { echo 'ERROR: this bundle supports RHEL 9 x86_64/amd64 only.' >&2; exit 1; }
dnf download --help >/dev/null 2>&1 || { echo 'ERROR: dnf download is unavailable; install dnf-plugins-core.' >&2; exit 1; }
if command -v docker >/dev/null 2>&1; then CRI=docker; elif command -v podman >/dev/null 2>&1; then CRI=podman; else echo 'ERROR: docker or podman is required.' >&2; exit 1; fi
command -v ansible-galaxy >/dev/null 2>&1 || { echo 'ERROR: ansible-galaxy is required to stage ansible.posix.' >&2; exit 1; }

fetch() {
  local url="$1" out="$2"
  echo "GET $url"
  curl -fL --retry 4 --retry-delay 2 --connect-timeout 20 -o "$out" "$url"
  test -s "$out"
}

urlencode_version="${RKE2_VERSION//+/%2B}"
RKE2_BASE="https://github.com/rancher/rke2/releases/download/${urlencode_version}"
SELINUX_BASE="https://github.com/rancher/rke2-selinux/releases/download/v${RKE2_SELINUX_VERSION}.stable.${RKE2_SELINUX_RELEASE}"

# RKE2 official air-gap artifacts.
fetch "$RKE2_BASE/rke2-images.linux-amd64.tar.zst" "$DEST/artifacts/rke2-images.linux-amd64.tar.zst"
fetch "$RKE2_BASE/rke2.linux-amd64.tar.gz" "$DEST/artifacts/rke2.linux-amd64.tar.gz"
fetch "$RKE2_BASE/sha256sum-amd64.txt" "$DEST/artifacts/sha256sum-amd64.txt"
fetch "https://get.rke2.io" "$DEST/artifacts/rke2-install.sh"
chmod +x "$DEST/artifacts/rke2-install.sh"

# RHEL9 SELinux policy required BEFORE RKE2 installation.
fetch "$SELINUX_BASE/rke2-selinux-${RKE2_SELINUX_VERSION}-${RKE2_SELINUX_RELEASE}.el9.noarch.rpm" \
      "$DEST/artifacts/rke2-selinux-${RKE2_SELINUX_VERSION}-${RKE2_SELINUX_RELEASE}.el9.noarch.rpm"

(
  cd "$DEST/artifacts"
  sha256sum -c sha256sum-amd64.txt --ignore-missing
  sha256sum "rke2-selinux-${RKE2_SELINUX_VERSION}-${RKE2_SELINUX_RELEASE}.el9.noarch.rpm" > rke2-selinux.sha256
)

# CLI tools.
K8S_VERSION="${RKE2_VERSION%%+*}"
fetch "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" "$DEST/artifacts/helm-linux-amd64.tar.gz"
fetch "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl" "$DEST/artifacts/kubectl"
chmod +x "$DEST/artifacts/kubectl"
fetch "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" "$DEST/artifacts/k9s_Linux_amd64.tar.gz"

# Offline Ansible collection.
(cd "$DEST/collections" && ansible-galaxy collection download "ansible.posix:${ANSIBLE_POSIX_VERSION}")

WORK="$DEST/.chart-work"
rm -rf "$WORK" && mkdir -p "$WORK"
helm repo add metallb https://metallb.github.io/metallb >/dev/null 2>&1 || true
helm repo add frr-k8s https://metallb.github.io/frr-k8s --force-update >/dev/null
helm repo add longhorn https://charts.longhorn.io >/dev/null 2>&1 || true
helm repo add harbor https://helm.goharbor.io >/dev/null 2>&1 || true
helm repo add gitea-charts https://dl.gitea.com/charts/ >/dev/null 2>&1 || true
helm repo update

# Pull charts as directories so dependency failures are fatal and dependencies
# are packaged into the final chart tarballs for true offline Helm installs.
pull_chart() {
  local repo="$1" chart="$2" version="$3"
  echo "Pulling ${repo}/${chart}:${version}"
  helm pull "${repo}/${chart}" --version "$version" --untar --untardir "$WORK/charts"
  local d="$WORK/charts/$chart"
  test -f "$d/Chart.yaml"
  helm dependency build "$d"
  helm package "$d" --destination "$DEST/charts" >/dev/null
}
pull_chart metallb metallb "$METALLB_VERSION"
pull_chart longhorn longhorn "$LONGHORN_VERSION"
pull_chart harbor harbor "$HARBOR_CHART_VERSION"
pull_chart gitea-charts gitea "$GITEA_CHART_VERSION"

# Render with values aligned to the actual Ansible roles, rather than relying
# on chart defaults. This is what makes the resulting image manifest useful.
mkdir -p "$WORK/values" "$DEST/images/rendered"
cat > "$WORK/values/metallb.yaml" <<EOF2
EOF2
cat > "$WORK/values/longhorn.yaml" <<EOF2
defaultSettings:
  defaultReplicaCount: 3
persistence:
  defaultClassReplicaCount: 3
EOF2
cat > "$WORK/values/harbor.yaml" <<EOF2
expose:
  type: loadBalancer
  tls:
    enabled: false
  loadBalancer:
    name: harbor
    ports:
      httpPort: 80
      httpsPort: 443
    annotations:
      metallb.universe.tf/loadBalancerIPs: "10.0.0.102"
externalURL: "http://harbor.airgap.local"
persistence:
  enabled: true
  persistentVolumeClaim:
    registry: {size: 50Gi, storageClass: longhorn}
    jobservice: {size: 5Gi, storageClass: longhorn}
    database: {size: 5Gi, storageClass: longhorn}
    redis: {size: 5Gi, storageClass: longhorn}
    trivy: {size: 5Gi, storageClass: longhorn}
chartmuseum:
  enabled: false
trivy:
  enabled: false
notary:
  enabled: false
EOF2
cat > "$WORK/values/gitea.yaml" <<EOF2
service:
  http: {port: 3000}
  ssh: {port: 22}
ingress:
  enabled: true
  className: traefik
image:
  tag: "$GITEA_APP_VERSION"
persistence:
  enabled: true
  size: 10Gi
  storageClass: longhorn
postgresql:
  enabled: true
  persistence: {size: 5Gi, storageClass: longhorn}
postgresql-ha:
  enabled: false
valkey-cluster:
  enabled: false
valkey:
  enabled: true
  primary:
    persistence: {size: 5Gi, storageClass: longhorn}
EOF2

render() {
  local chart="$1" values="$2"
  local tgz
  tgz="$(find "$DEST/charts" -maxdepth 1 -name "${chart}-*.tgz" -print -quit)"
  test -n "$tgz"
  helm template "$chart" "$tgz" --values "$values" --include-crds > "$DEST/images/rendered/${chart}.yaml"
}
render metallb "$WORK/values/metallb.yaml"
render longhorn "$WORK/values/longhorn.yaml"
render harbor "$WORK/values/harbor.yaml"
render gitea "$WORK/values/gitea.yaml"

# Explicit non-Helm images and images whose tag is set directly by Ansible.
cat > "$DEST/images/images-explicit.txt" <<EOF2
quay.io/metallb/controller:v${METALLB_VERSION}
quay.io/metallb/speaker:v${METALLB_VERSION}
EOF2

rm -f "$DEST/images/images-discovered.txt"
for f in "$DEST"/images/rendered/*.yaml; do
  grep -hoE 'image:[[:space:]]*[^[:space:]]+' "$f" \
    | sed -E "s/^image:[[:space:]]*//; s/^[\"']//; s/[\"',]$//" \
    >> "$DEST/images/images-discovered.txt" || true
done
sed '/^$/d;/{{/d;/^sha256:/d' "$DEST/images/images-discovered.txt" \
  | sort -u > "$DEST/images/images-discovered.clean.txt"
cat "$DEST/images/images-explicit.txt" "$DEST/images/images-discovered.clean.txt" \
  | sed '/^$/d' | sort -u > "$DEST/images/images.txt"

# Pull every application image. RKE2's own system images come from the official
# rke2-images archive and are intentionally not duplicated here.
echo '=== Pulling bootstrap images ==='
while IFS= read -r img; do
  [[ -z "$img" ]] && continue
  echo "Pulling $img"
  "$CRI" pull "$img"
done < "$DEST/images/images.txt"
mapfile -t IMAGES < "$DEST/images/images.txt"
if [[ "$CRI" == podman ]]; then
  "$CRI" save --multi-image-archive -o "$DEST/images/bootstrap-images.tar" "${IMAGES[@]}"
else
  "$CRI" save -o "$DEST/images/bootstrap-images.tar" "${IMAGES[@]}"
fi

# RPM closure. The Rancher SELinux RPM is copied separately because it is not a
# RHEL repository package. The other packages are resolved from enabled RHEL9 repos.
mkdir -p "$DEST/rpm"
cp "$DEST/artifacts/rke2-selinux-${RKE2_SELINUX_VERSION}-${RKE2_SELINUX_RELEASE}.el9.noarch.rpm" "$DEST/rpm/"
dnf --releasever=9 download --resolve --alldeps --arch=x86_64,noarch --destdir "$DEST/rpm" \
  chrony firewalld python3-pip python3-pyyaml jq vim-minimal curl wget zstd \
  net-tools iscsi-initiator-utils nfs-utils policycoreutils \
  policycoreutils-python-utils selinux-policy-targeted container-selinux \
  iptables-nft libnftnl selinux-policy

# Bundle manifest and checksums.
cat > "$DEST/manifests/BUNDLE-MANIFEST.txt" <<EOF2
Ansible Package 3.2.0 air-gap bundle
Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
RKE2: $RKE2_VERSION
RHEL: 9
Architecture: linux-amd64

The air-gapped deployment requires this entire directory, including the Ansible
configuration, inventory, variables, playbooks, roles, scripts and artifact directories.
RKE2 system images are imported from rke2-images.linux-amd64.tar.zst.
Application images are imported from images/bootstrap-images.tar.
SELinux policy is installed from rke2-selinux before RKE2.
EOF2
rm -rf "$WORK"
(
  cd "$DEST"
  find . -type f ! -path './checksums/*' ! -path './logs/*' -print0 \
    | sort -z | xargs -0 sha256sum > checksums/SHA256SUMS
)
"$(dirname "$0")/validate-bundle.sh" "$DEST"
echo "=== Bundle ready: $DEST ==="
