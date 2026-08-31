#!/bin/bash
# Master script to download all components for RHEL 9 airgap deployment
# Downloads: RPMs, RKE2, MetalLB, Helm, Harbor, Longhorn, Velero, Gitea

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

function print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

print_header "Starting Complete Airgap Download for RHEL 9"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if this is being run on RHEL
if [ ! -f /etc/redhat-release ]; then
    print_warning "This script is designed for RHEL 9. Some components may not work on other distributions."
fi

# Download RPMs
print_header "1. Downloading RHEL 9 RPMs"
if [ -f "$SCRIPT_DIR/download-rhel-rpms.sh" ]; then
    bash "$SCRIPT_DIR/download-rhel-rpms.sh"
else
    print_error "RPM download script not found"
    exit 1
fi

# Download RKE2
print_header "2. Downloading RKE2 Binaries and Images"
if [ -f "$SCRIPT_DIR/download-rke2-airgap.sh" ]; then
    bash "$SCRIPT_DIR/download-rke2-airgap.sh"
else
    print_error "RKE2 download script not found"
    exit 1
fi

# Download Add-ons
print_header "3. Downloading Add-ons (MetalLB, Helm, Harbor, Longhorn, Velero, Gitea)"
if [ -f "$SCRIPT_DIR/download-add-ons.sh" ]; then
    bash "$SCRIPT_DIR/download-add-ons.sh"
else
    print_error "Add-ons download script not found"
    exit 1
fi

# Create master archive
print_header "4. Creating Master Airgap Archive"
ARCHIVE_DIR="/tmp/rhel9-airgap-master"
mkdir -p "$ARCHIVE_DIR"

# Copy all downloaded content
print_status "Copying RPM repository..."
cp -r /opt/local-repo "$ARCHIVE_DIR/"

print_status "Copying RKE2 airgap bundle..."
cp -r /opt/rke2-airgap "$ARCHIVE_DIR/"

print_status "Copying add-ons airgap bundle..."
cp -r /opt/add-ons-airgap "$ARCHIVE_DIR/"

# Create master installation script
print_status "Creating master installation script..."
cat > "$ARCHIVE_DIR/install-all.sh" << 'EOF'
#!/bin/bash
# Master installation script for RHEL 9 airgap deployment

set -e

print_status() {
    echo "[INFO] $1"
}

print_header() {
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

ARCHIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "Starting RHEL 9 Airgap Installation"

# Install local repository
print_header "1. Setting up local RPM repository"
bash "$ARCHIVE_DIR/local-repo/setup-local-repo.sh"

# Install RKE2
print_header "2. Installing RKE2"
bash "$ARCHIVE_DIR/rke2-airgap/scripts/install-rke2-airgap.sh"

# Install add-ons (optional - comment out if not needed)
print_header "3. Installing Add-ons"

# MetalLB
print_status "Installing MetalLB..."
bash "$ARCHIVE_DIR/add-ons-airgap/scripts/install-metallb.sh"

# Harbor (optional)
# print_status "Installing Harbor..."
# bash "$ARCHIVE_DIR/add-ons-airgap/scripts/install-harbor.sh"

# Longhorn (optional)
# print_status "Installing Longhorn..."
# bash "$ARCHIVE_DIR/add-ons-airgap/scripts/install-longhorn.sh"

# Velero (optional)
# print_status "Installing Velero..."
# bash "$ARCHIVE_DIR/add-ons-airgap/scripts/install-velero.sh"

# Gitea (optional)
# print_status "Installing Gitea..."
# bash "$ARCHIVE_DIR/add-ons-airgap/scripts/install-gitea.sh"

print_header "Airgap Installation Complete!"
print_status "RKE2 and selected add-ons have been installed."
print_status "Configure each component according to your requirements."
EOF

chmod +x "$ARCHIVE_DIR/install-all.sh"

# Create README for the archive
print_status "Creating archive README..."
cat > "$ARCHIVE_DIR/README.txt" << 'EOF'
RHEL 9 Airgap Deployment Bundle
================================

This archive contains all components needed for a complete RHEL 9 airgap deployment.

Contents:
----------
1. local-repo/ - RHEL 9 RPM packages and local repository
2. rke2-airgap/ - RKE2 binaries and container images
3. add-ons-airgap/ - Additional Kubernetes add-ons

Installation:
-------------
1. Extract this archive: tar -xzf rhel9-airgap-master.tar.gz
2. Navigate to the extracted directory: cd rhel9-airgap-master
3. Run the master installation script: ./install-all.sh

Individual Installation:
------------------------
You can also install components individually:

- RPM Repository: ./local-repo/setup-local-repo.sh
- RKE2: ./rke2-airgap/scripts/install-rke2-airgap.sh
- MetalLB: ./add-ons-airgap/scripts/install-metallb.sh
- Harbor: ./add-ons-airgap/scripts/install-harbor.sh
- Longhorn: ./add-ons-airgap/scripts/install-longhorn.sh
- Velero: ./add-ons-airgap/scripts/install-velero.sh
- Gitea: ./add-ons-airgap/scripts/install-gitea.sh

Configuration:
--------------
After installation, you'll need to configure:
- RKE2: /etc/rancher/rke2/config.yaml
- MetalLB: Kubernetes manifests in add-ons-airgap/manifests/
- Harbor: Helm values (customize as needed)
- Longhorn: Helm values (customize as needed)
- Velero: Backup storage configuration
- Gitea: Helm values (customize as needed)

Network Requirements:
----------------------
Ensure the following ports are open:
- 22/tcp (SSH)
- 6443/tcp (Kubernetes API)
- 8472/udp (Flannel VXLAN)
- 10250/tcp (Kubelet)
- 80/tcp, 443/tcp (HTTP/HTTPS)
- 9100/tcp (Node Exporter)
- 8404/tcp (HAProxy Stats)

For detailed documentation, refer to the main Ansible deployment documentation.
EOF

# Create the final archive
print_status "Creating final archive..."
cd /tmp
tar -czf rhel9-airgap-master.tar.gz rhel9-airgap-master/

# Display summary
print_header "Airgap Download Complete!"
print_status "Master archive location: /tmp/rhel9-airgap-master.tar.gz"
print_status "Archive size: $(du -sh /tmp/rhel9-airgap-master.tar.gz | cut -f1)"
print_status ""
print_status "Archive contents:"
du -sh /tmp/rhel9-airgap-master/* | sort -h
print_status ""
print_status "Transfer this archive to your air-gapped environment:"
print_status "1. Copy: scp /tmp/rhel9-airgap-master.tar.gz user@target-system:/tmp/"
print_status "2. Extract: tar -xzf /tmp/rhel9-airgap-master.tar.gz -C /opt/"
print_status "3. Install: cd /opt/rhel9-airgap-master && ./install-all.sh"
print_header "=========================================="
