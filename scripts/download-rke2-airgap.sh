#!/bin/bash
# Script to download RKE2 binaries and container images for airgap deployment
# Supports RKE2 v1.28.10+rke2r1

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
RKE2_VERSION="v1.28.10+rke2r1"
DOWNLOAD_DIR="/tmp/rke2-airgap"
FINAL_DIR="/opt/rke2-airgap"
ARCH="amd64"

# Create directories
print_status "Creating directories..."
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$FINAL_DIR"

# Download RKE2 install script
print_status "Downloading RKE2 install script..."
curl -sfL https://get.rke2.io -o "$DOWNLOAD_DIR/rke2-install.sh"
chmod +x "$DOWNLOAD_DIR/rke2-install.sh"

# Download RKE2 binaries for airgap
print_status "Downloading RKE2 airgap images..."

# Download RKE2 server images
print_status "Downloading RKE2 server images..."
RKE2_SERVER_IMAGES=(
    "rancher/rke2-runtime:${RKE2_VERSION}"
    "rancher/rke2-canal:${RKE2_VERSION}"
    "rancher/rke2-coredns:${RKE2_VERSION}"
    "rancher/rke2-ingress-nginx:${RKE2_VERSION}"
    "rancher/rke2-pause:${RKE2_VERSION}"
    "rancher/rke2-metrics-server:${RKE2_VERSION}"
)

# Download RKE2 agent images
print_status "Downloading RKE2 agent images..."
RKE2_AGENT_IMAGES=(
    "rancher/rke2-runtime:${RKE2_VERSION}"
    "rancher/rke2-pause:${RKE2_VERSION}"
)

# Function to download images using docker
download_images_docker() {
    print_status "Using Docker to download images..."
    for image in "${RKE2_SERVER_IMAGES[@]}"; do
        print_status "Pulling $image..."
        docker pull "$image"
    done

    # Save images
    print_status "Saving images to tar files..."
    docker save "${RKE2_SERVER_IMAGES[@]}" -o "$DOWNLOAD_DIR/rke2-server-images.tar.gz"
}

# Function to download images using podman
download_images_podman() {
    print_status "Using Podman to download images..."
    for image in "${RKE2_SERVER_IMAGES[@]}"; do
        print_status "Pulling $image..."
        podman pull "$image"
    done

    # Save images
    print_status "Saving images to tar files..."
    podman save "${RKE2_SERVER_IMAGES[@]}" -o "$DOWNLOAD_DIR/rke2-server-images.tar.gz"
}

# Check for available container runtime
if command -v docker &> /dev/null; then
    download_images_docker
elif command -v podman &> /dev/null; then
    download_images_podman
else
    print_error "Neither Docker nor Podman found. Please install one of them."
    exit 1
fi

# Download RKE2 airgap bundle from GitHub releases
print_status "Downloading RKE2 airgap bundle..."
RKE2_AIRGAP_URL="https://github.com/rancher/rke2/releases/download/${RKE2_VERSION}/rke2-images.linux-${ARCH}.tar.gz"
curl -sfL "$RKE2_AIRGAP_URL" -o "$DOWNLOAD_DIR/rke2-images.linux-${ARCH}.tar.gz"

# Download RKE2 binaries
print_status "Downloading RKE2 binaries..."
RKE2_BINARIES=(
    "rke2"
    "rke2-aws"
    "rke2-azure"
    "rke2-docker"
    "rke2-openshift"
)

for binary in "${RKE2_BINARIES[@]}"; do
    print_status "Downloading $binary..."
    RKE2_BINARY_URL="https://github.com/rancher/rke2/releases/download/${RKE2_VERSION}/${binary}.linux-${ARCH}"
    curl -sfL "$RKE2_BINARY_URL" -o "$DOWNLOAD_DIR/${binary}.linux-${ARCH}"
    chmod +x "$DOWNLOAD_DIR/${binary}.linux-${ARCH}"
done

# Download kubectl
print_status "Downloading kubectl..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -sfL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" -o "$DOWNLOAD_DIR/kubectl"
chmod +x "$DOWNLOAD_DIR/kubectl"

# Move files to final directory
print_status "Moving files to final directory..."
cp -r "$DOWNLOAD_DIR"/* "$FINAL_DIR/"

# Create directory structure for deployment
print_status "Creating deployment directory structure..."
mkdir -p "$FINAL_DIR/binaries"
mkdir -p "$FINAL_DIR/images"
mkdir -p "$FINAL_DIR/scripts"

# Move files to appropriate directories
mv "$FINAL_DIR"/rke2*.linux-* "$FINAL_DIR/binaries/" 2>/dev/null || true
mv "$FINAL_DIR"/kubectl "$FINAL_DIR/binaries/" 2>/dev/null || true
mv "$FINAL_DIR"/rke2-install.sh "$FINAL_DIR/scripts/" 2>/dev/null || true
mv "$FINAL_DIR"/rke2*.tar.gz "$FINAL_DIR/images/" 2>/dev/null || true
mv "$FINAL_DIR"/rke2-server-images.tar.gz "$FINAL_DIR/images/" 2>/dev/null || true

# Create installation script
print_status "Creating installation script..."
cat > "$FINAL_DIR/scripts/install-rke2-airgap.sh" << 'EOF'
#!/bin/bash
# Script to install RKE2 from airgap binaries

set -e

RKE2_VERSION="v1.28.10+rke2r1"
RKE2_AIRGAP_DIR="/opt/rke2-airgap"
RKE2_INSTALL_DIR="/usr/local/bin"

# Copy binaries
echo "Copying RKE2 binaries..."
cp $RKE2_AIRGAP_DIR/binaries/rke2.linux-amd64 $RKE2_INSTALL_DIR/rke2
cp $RKE2_AIRGAP_DIR/binaries/kubectl $RKE2_INSTALL_DIR/kubectl
chmod +x $RKE2_INSTALL_DIR/rke2
chmod +x $RKE2_INSTALL_DIR/kubectl

# Copy images to RKE2 data directory
echo "Copying RKE2 images..."
mkdir -p /var/lib/rancher/rke2/agent/images/
cp $RKE2_AIRGAP_DIR/images/rke2-images.linux-amd64.tar.gz /var/lib/rancher/rke2/agent/images/
cp $RKE2_AIRGAP_DIR/images/rke2-server-images.tar.gz /var/lib/rancher/rke2/agent/images/

# Run install script with airgap flag
echo "Installing RKE2..."
INSTALL_RKE2_VERSION="$RKE2_VERSION" INSTALL_RKE2_CHANNEL=stable INSTALL_RKE2_ARTIFACT_PATH="$RKE2_AIRGAP_DIR/binaries" $RKE2_AIRGAP_DIR/scripts/rke2-install.sh

echo "RKE2 airgap installation complete!"
EOF

chmod +x "$FINAL_DIR/scripts/install-rke2-airgap.sh"

# Create manifest file
print_status "Creating manifest file..."
cat > "$FINAL_DIR/MANIFEST.txt" << EOF
RKE2 Airgap Bundle
==================
RKE2 Version: $RKE2_VERSION
Architecture: $ARCH
Download Date: $(date)

Contents:
- RKE2 binaries and install script
- RKE2 container images
- kubectl binary
- Installation scripts

Installation:
1. Extract the bundle to /opt/rke2-airgap
2. Run: /opt/rke2-airgap/scripts/install-rke2-airgap.sh
3. Configure /etc/rancher/rke2/config.yaml
4. Start RKE2: systemctl start rke2-server (or rke2-agent)
EOF

# Cleanup
print_status "Cleaning up temporary files..."
rm -rf "$DOWNLOAD_DIR"

print_status "=========================================="
print_status "RKE2 airgap download completed successfully!"
print_status "=========================================="
print_status "Airgap bundle location: $FINAL_DIR"
print_status "Total size: $(du -sh $FINAL_DIR | cut -f1)"
print_status ""
print_status "To transfer to air-gapped systems:"
print_status "1. Archive the bundle: tar -czf rke2-airgap.tar.gz -C /opt rke2-airgap"
print_status "2. Transfer to air-gapped systems"
print_status "3. Extract: tar -xzf rke2-airgap.tar.gz -C /opt"
print_status "4. Run: $FINAL_DIR/scripts/install-rke2-airgap.sh"
print_status "=========================================="
