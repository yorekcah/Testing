#!/bin/bash
# Script to download additional add-ons for RHEL 9 airgap deployment
# Downloads: MetalLB, Helm, Harbor, Longhorn, Velero, Gitea

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
DOWNLOAD_DIR="/tmp/add-ons-airgap"
FINAL_DIR="/opt/add-ons-airgap"
ARCH="amd64"

# Add-on versions
METALLB_VERSION="v0.14.0"
HELM_VERSION="v3.14.0"
HARBOR_VERSION="v2.10.0"
LONGHORN_VERSION="v1.6.0"
VELERO_VERSION="v1.13.0"
GITEA_VERSION="v1.21.0"

# Create directories
print_status "Creating directories..."
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$FINAL_DIR"
mkdir -p "$FINAL_DIR/binaries"
mkdir -p "$FINAL_DIR/images"
mkdir -p "$FINAL_DIR/charts"
mkdir -p "$FINAL_DIR/manifests"
mkdir -p "$FINAL_DIR/scripts"

# Download Helm
print_status "Downloading Helm $HELM_VERSION..."
HELM_URL="https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
curl -sfL "$HELM_URL" -o "$DOWNLOAD_DIR/helm.tar.gz"
tar -xzf "$DOWNLOAD_DIR/helm.tar.gz" -C "$DOWNLOAD_DIR"
mv "$DOWNLOAD_DIR/linux-${ARCH}/helm" "$FINAL_DIR/binaries/"
chmod +x "$FINAL_DIR/binaries/helm"

# Download MetalLB
print_status "Downloading MetalLB $METALLB_VERSION..."
METALLB_MANIFEST_URL="https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
curl -sfL "$METALLB_MANIFEST_URL" -o "$FINAL_DIR/manifests/metallb-native.yaml"

# Download MetalLB images
print_status "Downloading MetalLB container images..."
METALLB_IMAGES=(
    "quay.io/metallb/controller:${METALLB_VERSION}"
    "quay.io/metallb/speaker:${METALLB_VERSION}"
)

download_images_metallb() {
    if command -v docker &> /dev/null; then
        print_status "Using Docker to download MetalLB images..."
        for image in "${METALLB_IMAGES[@]}"; do
            print_status "Pulling $image..."
            docker pull "$image"
        done
        docker save "${METALLB_IMAGES[@]}" -o "$FINAL_DIR/images/metallb-images.tar.gz"
    elif command -v podman &> /dev/null; then
        print_status "Using Podman to download MetalLB images..."
        for image in "${METALLB_IMAGES[@]}"; do
            print_status "Pulling $image..."
            podman pull "$image"
        done
        podman save "${METALLB_IMAGES[@]}" -o "$FINAL_DIR/images/metallb-images.tar.gz"
    else
        print_error "Neither Docker nor Podman found for MetalLB images"
    fi
}
download_images_metallb

# Download Harbor
print_status "Downloading Harbor $HARBOR_VERSION..."
HARBOR_CHART_URL="https://github.com/goharbor/harbor-helm/releases/download/harbor-${HARBOR_VERSION}/harbor-${HARBOR_VERSION}.tgz"
curl -sfL "$HARBOR_CHART_URL" -o "$FINAL_DIR/charts/harbor-${HARBOR_VERSION}.tgz"

# Download Harbor images
print_status "Downloading Harbor container images..."
HARBOR_IMAGES=(
    "goharbor/harbor-core:${HARBOR_VERSION}"
    "goharbor/harbor-portal:${HARBOR_VERSION}"
    "goharbor/harbor-jobservice:${HARBOR_VERSION}"
    "goharbor/harbor-registry:${HARBOR_VERSION}"
    "goharbor/harbor-trivy:${HARBOR_VERSION}"
    "goharbor/harbor-exporter:${HARBOR_VERSION}"
    "goharbor/redis-photon:${HARBOR_VERSION}"
    "goharbor/registry-photon:${HARBOR_VERSION}"
    "goharbor/nginx-photon:${HARBOR_VERSION}"
    "goharbor/notary-server-photon:${HARBOR_VERSION}"
    "goharbor/notary-signer-photon:${HARBOR_VERSION}"
    "goharbor/prepare:${HARBOR_VERSION}"
)

download_images_harbor() {
    if command -v docker &> /dev/null; then
        print_status "Using Docker to download Harbor images..."
        for image in "${HARBOR_IMAGES[@]}"; do
            print_status "Pulling $image..."
            docker pull "$image"
        done
        docker save "${HARBOR_IMAGES[@]}" -o "$FINAL_DIR/images/harbor-images.tar.gz"
    elif command -v podman &> /dev/null; then
        print_status "Using Podman to download Harbor images..."
        for image in "${HARBOR_IMAGES[@]}"; do
            print_status "Pulling $image..."
            podman pull "$image"
        done
        podman save "${HARBOR_IMAGES[@]}" -o "$FINAL_DIR/images/harbor-images.tar.gz"
    else
        print_error "Neither Docker nor Podman found for Harbor images"
    fi
}
download_images_harbor

# Download Longhorn
print_status "Downloading Longhorn $LONGHORN_VERSION..."
LONGHORN_CHART_URL="https://github.com/longhorn/longhorn/releases/download/${LONGHORN_VERSION}/longhorn-${LONGHORN_VERSION}.tgz"
curl -sfL "$LONGHORN_CHART_URL" -o "$FINAL_DIR/charts/longhorn-${LONGHORN_VERSION}.tgz"

# Download Longhorn images
print_status "Downloading Longhorn container images..."
LONGHORN_IMAGES=(
    "longhornio/longhorn-manager:${LONGHORN_VERSION}"
    "longhornio/longhorn-engine:${LONGHORN_VERSION}"
    "longhornio/longhorn-instance-manager:${LONGHORN_VERSION}"
    "longhornio/longhorn-share-manager:${LONGHORN_VERSION}"
    "longhornio/longhorn-ui:${LONGHORN_VERSION}"
    "longhornio/support-bundle-kit:${LONGHORN_VERSION}"
    "longhornio/backing-image-manager:${LONGHORN_VERSION}"
    "longhornio/longhorn-instance-manager:${LONGHORN_VERSION}"
)

download_images_longhorn() {
    if command -v docker &> /dev/null; then
        print_status "Using Docker to download Longhorn images..."
        for image in "${LONGHORN_IMAGES[@]}"; do
            print_status "Pulling $image..."
            docker pull "$image"
        done
        docker save "${LONGHORN_IMAGES[@]}" -o "$FINAL_DIR/images/longhorn-images.tar.gz"
    elif command -v podman &> /dev/null; then
        print_status "Using Podman to download Longhorn images..."
        for image in "${LONGHORN_IMAGES[@]}"; do
            print_status "Pulling $image..."
            podman pull "$image"
        done
        podman save "${LONGHORN_IMAGES[@]}" -o "$FINAL_DIR/images/longhorn-images.tar.gz"
    else
        print_error "Neither Docker nor Podman found for Longhorn images"
    fi
}
download_images_longhorn

# Download Velero
print_status "Downloading Velero $VELERO_VERSION..."
VELERO_BINARY_URL="https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-${ARCH}.tar.gz"
curl -sfL "$VELERO_BINARY_URL" -o "$DOWNLOAD_DIR/velero.tar.gz"
tar -xzf "$DOWNLOAD_DIR/velero.tar.gz" -C "$DOWNLOAD_DIR"
mv "$DOWNLOAD_DIR/velero-${VELERO_VERSION}-linux-${ARCH}/velero" "$FINAL_DIR/binaries/"
chmod +x "$FINAL_DIR/binaries/velero"

# Download Velero plugin
print_status "Downloading Velero AWS plugin..."
VELERO_PLUGIN_URL="https://github.com/vmware-tanzu/velero-plugin-for-aws/releases/download/${VELERO_VERSION}/velero-plugin-for-aws-linux-${ARCH}.tar.gz"
curl -sfL "$VELERO_PLUGIN_URL" -o "$DOWNLOAD_DIR/velero-plugin.tar.gz"
tar -xzf "$DOWNLOAD_DIR/velero-plugin.tar.gz" -C "$DOWNLOAD_DIR"
mkdir -p "$FINAL_DIR/binaries/velero-plugins"
mv "$DOWNLOAD_DIR"/velero-* "$FINAL_DIR/binaries/velero-plugins/" 2>/dev/null || true

# Download Velero images
print_status "Downloading Velero container images..."
VELERO_IMAGES=(
    "velero/velero:${VELERO_VERSION}"
    "velero/velero-plugin-for-aws:${VELERO_VERSION}"
)

download_images_velero() {
    if command -v docker &> /dev/null; then
        print_status "Using Docker to download Velero images..."
        for image in "${VELERO_IMAGES[@]}"; do
            print_status "Pulling $image..."
            docker pull "$image"
        done
        docker save "${VELERO_IMAGES[@]}" -o "$FINAL_DIR/images/velero-images.tar.gz"
    elif command -v podman &> /dev/null; then
        print_status "Using Podman to download Velero images..."
        for image in "${VELERO_IMAGES[@]}"; do
            print_status "Pulling $image..."
            podman pull "$image"
        done
        podman save "${VELERO_IMAGES[@]}" -o "$FINAL_DIR/images/velero-images.tar.gz"
    else
        print_error "Neither Docker nor Podman found for Velero images"
    fi
}
download_images_velero

# Download Gitea
print_status "Downloading Gitea $GITEA_VERSION..."
GITEA_CHART_URL="https://github.com/gitea/helm-chart/releases/download/gitea-${GITEA_VERSION}/gitea-${GITEA_VERSION}.tgz"
curl -sfL "$GITEA_CHART_URL" -o "$FINAL_DIR/charts/gitea-${GITEA_VERSION}.tgz"

# Download Gitea images
print_status "Downloading Gitea container images..."
GITEA_IMAGES=(
    "gitea/gitea:${GITEA_VERSION}"
    "postgres:15"
    "redis:7"
)

download_images_gitea() {
    if command -v docker &> /dev/null; then
        print_status "Using Docker to download Gitea images..."
        for image in "${GITEA_IMAGES[@]}"; do
            print_status "Pulling $image..."
            docker pull "$image"
        done
        docker save "${GITEA_IMAGES[@]}" -o "$FINAL_DIR/images/gitea-images.tar.gz"
    elif command -v podman &> /dev/null; then
        print_status "Using Podman to download Gitea images..."
        for image in "${GITEA_IMAGES[@]}"; do
            print_status "Pulling $image..."
            podman pull "$image"
        done
        podman save "${GITEA_IMAGES[@]}" -o "$FINAL_DIR/images/gitea-images.tar.gz"
    else
        print_error "Neither Docker nor Podman found for Gitea images"
    fi
}
download_images_gitea

# Create installation scripts
print_status "Creating installation scripts..."

# MetalLB installation script
cat > "$FINAL_DIR/scripts/install-metallb.sh" << 'EOF'
#!/bin/bash
# Script to install MetalLB in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading MetalLB images..."
ctr -n k8s.io images import "$ADDONS_DIR/images/metallb-images.tar.gz"

# Install MetalLB
echo "Installing MetalLB..."
kubectl apply -f "$ADDONS_DIR/manifests/metallb-native.yaml" --kubeconfig="$KUBECONFIG"

echo "MetalLB installation complete!"
EOF
chmod +x "$FINAL_DIR/scripts/install-metallb.sh"

# Harbor installation script
cat > "$FINAL_DIR/scripts/install-harbor.sh" << 'EOF'
#!/bin/bash
# Script to install Harbor in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading Harbor images..."
ctr -n k8s.io images import "$ADDONS_DIR/images/harbor-images.tar.gz"

# Install Harbor using Helm
echo "Installing Harbor..."
helm install harbor "$ADDONS_DIR/charts/harbor-v2.10.0.tgz" --kubeconfig="$KUBECONFIG" --namespace harbor --create-namespace

echo "Harbor installation complete!"
EOF
chmod +x "$FINAL_DIR/scripts/install-harbor.sh"

# Longhorn installation script
cat > "$FINAL_DIR/scripts/install-longhorn.sh" << 'EOF'
#!/bin/bash
# Script to install Longhorn in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading Longhorn images..."
ctr -n k8s.io images import "$ADDONS_DIR/images/longhorn-images.tar.gz"

# Install Longhorn using Helm
echo "Installing Longhorn..."
helm install longhorn "$ADDONS_DIR/charts/longhorn-v1.6.0.tgz" --kubeconfig="$KUBECONFIG" --namespace longhorn-system --create-namespace

echo "Longhorn installation complete!"
EOF
chmod +x "$FINAL_DIR/scripts/install-longhorn.sh"

# Velero installation script
cat > "$FINAL_DIR/scripts/install-velero.sh" << 'EOF'
#!/bin/bash
# Script to install Velero in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading Velero images..."
ctr -n k8s.io images import "$ADDONS_DIR/images/velero-images.tar.gz"

# Install Velero
echo "Installing Velero..."
velero install --kubeconfig="$KUBECONFIG" --plugins="$ADDONS_DIR/binaries/velero-plugins"

echo "Velero installation complete!"
EOF
chmod +x "$FINAL_DIR/scripts/install-velero.sh"

# Gitea installation script
cat > "$FINAL_DIR/scripts/install-gitea.sh" << 'EOF'
#!/bin/bash
# Script to install Gitea in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading Gitea images..."
ctr -n k8s.io images import "$ADDONS_DIR/images/gitea-images.tar.gz"

# Install Gitea using Helm
echo "Installing Gitea..."
helm install gitea "$ADDONS_DIR/charts/gitea-v1.21.0.tgz" --kubeconfig="$KUBECONFIG" --namespace gitea --create-namespace

echo "Gitea installation complete!"
EOF
chmod +x "$FINAL_DIR/scripts/install-gitea.sh"

# Create manifest file
print_status "Creating manifest file..."
cat > "$FINAL_DIR/MANIFEST.txt" << EOF
Add-ons Airgap Bundle
======================
Download Date: $(date)

Components:
- MetalLB v${METALLB_VERSION}
- Helm v${HELM_VERSION}
- Harbor v${HARBOR_VERSION}
- Longhorn v${LONGHORN_VERSION}
- Velero v${VELERO_VERSION}
- Gitea v${GITEA_VERSION}

Contents:
- Binaries: Helm, Velero
- Helm Charts: Harbor, Longhorn, Gitea
- Container Images: MetalLB, Harbor, Longhorn, Velero, Gitea
- Installation Scripts: Individual scripts for each component

Installation:
1. Extract the bundle to /opt/add-ons-airgap
2. Load container images: ctr -n k8s.io images import /opt/add-ons-airgap/images/*.tar.gz
3. Install components using provided scripts
4. Configure each component according to your requirements
EOF

# Cleanup
print_status "Cleaning up temporary files..."
rm -rf "$DOWNLOAD_DIR"

print_status "=========================================="
print_status "Add-ons airgap download completed successfully!"
print_status "=========================================="
print_status "Airgap bundle location: $FINAL_DIR"
print_status "Total size: $(du -sh $FINAL_DIR | cut -f1)"
print_status ""
print_status "To transfer to air-gapped systems:"
print_status "1. Archive the bundle: tar -czf add-ons-airgap.tar.gz -C /opt add-ons-airgap"
print_status "2. Transfer to air-gapped systems"
print_status "3. Extract: tar -xzf add-ons-airgap.tar.gz -C /opt"
print_status "4. Use individual installation scripts for each component"
print_status "=========================================="
