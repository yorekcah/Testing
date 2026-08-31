#!/bin/bash
# Script to download all required RPMs for RHEL 9 airgap deployment
# This script should be run on a RHEL 9 system with internet access

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
LOCAL_REPO_DIR="/opt/local-repo"
DOWNLOAD_DIR="/tmp/rhel-rpms-download"
RHEL_VERSION=9

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# Check if RHEL 9
if [ ! -f /etc/redhat-release ]; then
    print_error "This script must be run on RHEL"
    exit 1
fi

print_status "Starting RPM download for RHEL $RHEL_VERSION airgap deployment..."

# Create directories
print_status "Creating directories..."
mkdir -p "$LOCAL_REPO_DIR"
mkdir -p "$DOWNLOAD_DIR"

# Base packages required for Kubernetes and RKE2
BASE_PACKAGES=(
    "curl"
    "wget"
    "ca-certificates"
    "iptables"
    "socat"
    "conntrack-tools"
    "ipset"
    "open-vm-tools"
    "python3"
    "python3-pip"
    "chrony"
    "htop"
    "net-tools"
    "tcpdump"
    "vim"
    "git"
    "jq"
    "unzip"
    "firewalld"
    "haproxy"
    "containerd"
    "runc"
    "cri-tools"
)

# Download base packages
print_status "Downloading base packages..."
for package in "${BASE_PACKAGES[@]}"; do
    print_status "Downloading $package..."
    dnf download --downloadonly --downloaddir="$DOWNLOAD_DIR" "$package" || print_warning "Failed to download $package"
done

# Download additional dependencies
print_status "Downloading additional dependencies..."
dnf download --downloadonly --downloaddir="$DOWNLOAD_DIR" --resolve "${BASE_PACKAGES[@]}" || print_warning "Some dependencies may have failed"

# Create local repository structure
print_status "Creating local repository structure..."
mkdir -p "$LOCAL_REPO_DIR/Packages"
cp -r "$DOWNLOAD_DIR"/* "$LOCAL_REPO_DIR/Packages/" 2>/dev/null || true

# Initialize local repository
print_status "Initializing local repository..."
dnf install -y createrepo_c
createrepo_c "$LOCAL_REPO_DIR"

# Create repository configuration file
print_status "Creating repository configuration..."
cat > "$LOCAL_REPO_DIR/local-repo.repo" << 'EOF'
[local-repo]
name=Local Repository
baseurl=file:///opt/local-repo
enabled=1
gpgcheck=0
priority=1
EOF

# Get additional package information
print_status "Getting package information..."
dnf repolist enabled > "$LOCAL_REPO_DIR/enabled-repos.txt"
dnf list installed > "$LOCAL_REPO_DIR/installed-packages.txt"

# Create repository installation script
print_status "Creating repository installation script..."
cat > "$LOCAL_REPO_DIR/setup-local-repo.sh" << 'EOF'
#!/bin/bash
# Script to setup local repository on air-gapped systems

set -e

LOCAL_REPO_DIR="/opt/local-repo"

# Copy repository files
mkdir -p /etc/yum.repos.d/
cp $LOCAL_REPO_DIR/local-repo.repo /etc/yum.repos.d/

# Clean and update repository cache
dnf clean all
dnf makecache

echo "Local repository setup complete!"
EOF

chmod +x "$LOCAL_REPO_DIR/setup-local-repo.sh"

# Cleanup
print_status "Cleaning up temporary files..."
rm -rf "$DOWNLOAD_DIR"

print_status "=========================================="
print_status "RPM download completed successfully!"
print_status "=========================================="
print_status "Local repository location: $LOCAL_REPO_DIR"
print_status "Total size: $(du -sh $LOCAL_REPO_DIR | cut -f1)"
print_status "Number of packages: $(find $LOCAL_REPO_DIR/Packages -name '*.rpm' | wc -l)"
print_status ""
print_status "To transfer to air-gapped systems:"
print_status "1. Archive the repository: tar -czf rhel-local-repo.tar.gz -C /opt local-repo"
print_status "2. Transfer to air-gapped systems"
print_status "3. Extract: tar -xzf rhel-local-repo.tar.gz -C /opt"
print_status "4. Run: $LOCAL_REPO_DIR/setup-local-repo.sh"
print_status "=========================================="
