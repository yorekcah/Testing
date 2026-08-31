# PowerShell script to download all components for RHEL 9 airgap deployment
# This script requires Docker Desktop to be installed on Windows
# Downloads: RPMs, RKE2, MetalLB, Helm, Harbor, Longhorn, Velero, Gitea

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "==========================================" -ForegroundColor Blue
    Write-Host "$Message" -ForegroundColor Blue
    Write-Host "==========================================" -ForegroundColor Blue
}

# Configuration
$BASE_DIR = "C:\Users\A\ansible\airgap-bundle"
$DOWNLOAD_DIR = "$BASE_DIR\downloads"
$FINAL_DIR = "$BASE_DIR\rhel9-airgap-master"

# Add-on versions
$RKE2_VERSION = "v1.28.10+rke2r1"
$METALLB_VERSION = "v0.14.0"
$HELM_VERSION = "v3.14.0"
$HARBOR_VERSION = "v2.10.0"
$LONGHORN_VERSION = "v1.6.0"
$VELERO_VERSION = "v1.13.0"
$GITEA_VERSION = "v1.21.0"

# Check if Docker is available
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Error "Docker is not installed or not in PATH. Please install Docker Desktop."
    exit 1
}

Write-Header "Starting Complete Airgap Download for RHEL 9 (Windows)"

# Create directories
Write-Status "Creating directories..."
New-Item -ItemType Directory -Force -Path $BASE_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $DOWNLOAD_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $FINAL_DIR | Out-Null

# Download RKE2
Write-Header "1. Downloading RKE2"
Write-Status "Downloading RKE2 install script..."
Invoke-WebRequest -Uri "https://get.rke2.io" -OutFile "$DOWNLOAD_DIR\rke2-install.sh"

Write-Status "Downloading RKE2 airgap images..."
$RKE2_IMAGES_URL = "https://github.com/rancher/rke2/releases/download/${RKE2_VERSION}/rke2-images.linux-amd64.tar.gz"
Invoke-WebRequest -Uri $RKE2_IMAGES_URL -OutFile "$DOWNLOAD_DIR\rke2-images.linux-amd64.tar.gz"

Write-Status "Downloading RKE2 binaries..."
$RKE2_BINARIES = @("rke2", "rke2-aws", "rke2-azure", "rke2-docker", "rke2-openshift")
foreach ($binary in $RKE2_BINARIES) {
    $RKE2_BINARY_URL = "https://github.com/rancher/rke2/releases/download/${RKE2_VERSION}/${binary}.linux-amd64"
    Write-Status "Downloading $binary..."
    Invoke-WebRequest -Uri $RKE2_BINARY_URL -OutFile "$DOWNLOAD_DIR\${binary}.linux-amd64"
}

Write-Status "Downloading kubectl..."
$KUBECTL_VERSION = Invoke-RestMethod -Uri "https://dl.k8s.io/release/stable.txt"
Invoke-WebRequest -Uri "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -OutFile "$DOWNLOAD_DIR\kubectl"

# Download Helm
Write-Header "2. Downloading Helm"
Write-Status "Downloading Helm $HELM_VERSION..."
$HELM_URL = "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
Invoke-WebRequest -Uri $HELM_URL -OutFile "$DOWNLOAD_DIR\helm.tar.gz"

# Download MetalLB
Write-Header "3. Downloading MetalLB"
Write-Status "Downloading MetalLB manifest..."
$METALLB_MANIFEST_URL = "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
Invoke-WebRequest -Uri $METALLB_MANIFEST_URL -OutFile "$DOWNLOAD_DIR\metallb-native.yaml"

Write-Status "Pulling MetalLB images with Docker..."
$METALLB_IMAGES = @(
    "quay.io/metallb/controller:${METALLB_VERSION}",
    "quay.io/metallb/speaker:${METALLB_VERSION}"
)
foreach ($image in $METALLB_IMAGES) {
    Write-Status "Pulling $image..."
    docker pull $image
}
Write-Status "Saving MetalLB images..."
docker save "${METALLB_IMAGES}" -o "$DOWNLOAD_DIR\metallb-images.tar.gz"

# Download Harbor
Write-Header "4. Downloading Harbor"
Write-Status "Downloading Harbor chart..."
$HARBOR_CHART_URL = "https://github.com/goharbor/harbor-helm/releases/download/harbor-${HARBOR_VERSION}/harbor-${HARBOR_VERSION}.tgz"
Invoke-WebRequest -Uri $HARBOR_CHART_URL -OutFile "$DOWNLOAD_DIR\harbor-${HARBOR_VERSION}.tgz"

Write-Status "Pulling Harbor images with Docker..."
$HARBOR_IMAGES = @(
    "goharbor/harbor-core:${HARBOR_VERSION}",
    "goharbor/harbor-portal:${HARBOR_VERSION}",
    "goharbor/harbor-jobservice:${HARBOR_VERSION}",
    "goharbor/harbor-registry:${HARBOR_VERSION}",
    "goharbor/harbor-trivy:${HARBOR_VERSION}",
    "goharbor/harbor-exporter:${HARBOR_VERSION}",
    "goharbor/redis-photon:${HARBOR_VERSION}",
    "goharbor/registry-photon:${HARBOR_VERSION}",
    "goharbor/nginx-photon:${HARBOR_VERSION}",
    "goharbor/notary-server-photon:${HARBOR_VERSION}",
    "goharbor/notary-signer-photon:${HARBOR_VERSION}",
    "goharbor/prepare:${HARBOR_VERSION}"
)
foreach ($image in $HARBOR_IMAGES) {
    Write-Status "Pulling $image..."
    docker pull $image
}
Write-Status "Saving Harbor images..."
docker save "${HARBOR_IMAGES}" -o "$DOWNLOAD_DIR\harbor-images.tar.gz"

# Download Longhorn
Write-Header "5. Downloading Longhorn"
Write-Status "Downloading Longhorn chart..."
$LONGHORN_CHART_URL = "https://github.com/longhorn/longhorn/releases/download/${LONGHORN_VERSION}/longhorn-${LONGHORN_VERSION}.tgz"
Invoke-WebRequest -Uri $LONGHORN_CHART_URL -OutFile "$DOWNLOAD_DIR\longhorn-${LONGHORN_VERSION}.tgz"

Write-Status "Pulling Longhorn images with Docker..."
$LONGHORN_IMAGES = @(
    "longhornio/longhorn-manager:${LONGHORN_VERSION}",
    "longhornio/longhorn-engine:${LONGHORN_VERSION}",
    "longhornio/longhorn-instance-manager:${LONGHORN_VERSION}",
    "longhornio/longhorn-share-manager:${LONGHORN_VERSION}",
    "longhornio/longhorn-ui:${LONGHORN_VERSION}",
    "longhornio/support-bundle-kit:${LONGHORN_VERSION}",
    "longhornio/backing-image-manager:${LONGHORN_VERSION}"
)
foreach ($image in $LONGHORN_IMAGES) {
    Write-Status "Pulling $image..."
    docker pull $image
}
Write-Status "Saving Longhorn images..."
docker save "${LONGHORN_IMAGES}" -o "$DOWNLOAD_DIR\longhorn-images.tar.gz"

# Download Velero
Write-Header "6. Downloading Velero"
Write-Status "Downloading Velero binary..."
$VELERO_BINARY_URL = "https://github.com/vmware-tanzu/velero/releases/download/${VELERO_VERSION}/velero-${VELERO_VERSION}-linux-amd64.tar.gz"
Invoke-WebRequest -Uri $VELERO_BINARY_URL -OutFile "$DOWNLOAD_DIR\velero.tar.gz"

Write-Status "Downloading Velero plugin..."
$VELERO_PLUGIN_URL = "https://github.com/vmware-tanzu/velero-plugin-for-aws/releases/download/${VELERO_VERSION}/velero-plugin-for-aws-linux-amd64.tar.gz"
Invoke-WebRequest -Uri $VELERO_PLUGIN_URL -OutFile "$DOWNLOAD_DIR\velero-plugin.tar.gz"

Write-Status "Pulling Velero images with Docker..."
$VELERO_IMAGES = @(
    "velero/velero:${VELERO_VERSION}",
    "velero/velero-plugin-for-aws:${VELERO_VERSION}"
)
foreach ($image in $VELERO_IMAGES) {
    Write-Status "Pulling $image..."
    docker pull $image
}
Write-Status "Saving Velero images..."
docker save "${VELERO_IMAGES}" -o "$DOWNLOAD_DIR\velero-images.tar.gz"

# Download Gitea
Write-Header "7. Downloading Gitea"
Write-Status "Downloading Gitea chart..."
$GITEA_CHART_URL = "https://github.com/gitea/helm-chart/releases/download/gitea-${GITEA_VERSION}/gitea-${GITEA_VERSION}.tgz"
Invoke-WebRequest -Uri $GITEA_CHART_URL -OutFile "$DOWNLOAD_DIR\gitea-${GITEA_VERSION}.tgz"

Write-Status "Pulling Gitea images with Docker..."
$GITEA_IMAGES = @(
    "gitea/gitea:${GITEA_VERSION}",
    "postgres:15",
    "redis:7"
)
foreach ($image in $GITEA_IMAGES) {
    Write-Status "Pulling $image..."
    docker pull $image
}
Write-Status "Saving Gitea images..."
docker save "${GITEA_IMAGES}" -o "$DOWNLOAD_DIR\gitea-images.tar.gz"

# Organize files
Write-Header "8. Organizing Airgap Bundle"
Write-Status "Creating directory structure..."
New-Item -ItemType Directory -Force -Path "$FINAL_DIR\binaries" | Out-Null
New-Item -ItemType Directory -Force -Path "$FINAL_DIR\images" | Out-Null
New-Item -ItemType Directory -Force -Path "$FINAL_DIR\charts" | Out-Null
New-Item -ItemType Directory -Force -Path "$FINAL_DIR\manifests" | Out-Null
New-Item -ItemType Directory -Force -Path "$FINAL_DIR\scripts" | Out-Null

Write-Status "Moving binaries..."
Move-Item -Path "$DOWNLOAD_DIR\rke2*.linux-amd64" -Destination "$FINAL_DIR\binaries\" -Force
Move-Item -Path "$DOWNLOAD_DIR\kubectl" -Destination "$FINAL_DIR\binaries\" -Force
Move-Item -Path "$DOWNLOAD_DIR\rke2-install.sh" -Destination "$FINAL_DIR\scripts\" -Force

Write-Status "Moving images..."
Move-Item -Path "$DOWNLOAD_DIR\rke2-images.linux-amd64.tar.gz" -Destination "$FINAL_DIR\images\" -Force
Move-Item -Path "$DOWNLOAD_DIR\metallb-images.tar.gz" -Destination "$FINAL_DIR\images\" -Force
Move-Item -Path "$DOWNLOAD_DIR\harbor-images.tar.gz" -Destination "$FINAL_DIR\images\" -Force
Move-Item -Path "$DOWNLOAD_DIR\longhorn-images.tar.gz" -Destination "$FINAL_DIR\images\" -Force
Move-Item -Path "$DOWNLOAD_DIR\velero-images.tar.gz" -Destination "$FINAL_DIR\images\" -Force
Move-Item -Path "$DOWNLOAD_DIR\gitea-images.tar.gz" -Destination "$FINAL_DIR\images\" -Force

Write-Status "Moving charts..."
Move-Item -Path "$DOWNLOAD_DIR\harbor-*.tgz" -Destination "$FINAL_DIR\charts\" -Force
Move-Item -Path "$DOWNLOAD_DIR\longhorn-*.tgz" -Destination "$FINAL_DIR\charts\" -Force
Move-Item -Path "$DOWNLOAD_DIR\gitea-*.tgz" -Destination "$FINAL_DIR\charts\" -Force

Write-Status "Moving manifests..."
Move-Item -Path "$DOWNLOAD_DIR\metallb-native.yaml" -Destination "$FINAL_DIR\manifests\" -Force

Write-Status "Extracting Helm..."
Expand-Archive -Path "$DOWNLOAD_DIR\helm.tar.gz" -DestinationPath "$DOWNLOAD_DIR\helm-temp" -Force
Move-Item -Path "$DOWNLOAD_DIR\helm-temp\linux-amd64\helm" -Destination "$FINAL_DIR\binaries\" -Force
Remove-Item -Path "$DOWNLOAD_DIR\helm-temp" -Recurse -Force

Write-Status "Extracting Velero..."
Expand-Archive -Path "$DOWNLOAD_DIR\velero.tar.gz" -DestinationPath "$DOWNLOAD_DIR\velero-temp" -Force
Move-Item -Path "$DOWNLOAD_DIR\velero-temp\velero-${VELERO_VERSION}-linux-amd64\velero" -Destination "$FINAL_DIR\binaries\" -Force
Remove-Item -Path "$DOWNLOAD_DIR\velero-temp" -Recurse -Force

Write-Status "Extracting Velero plugin..."
Expand-Archive -Path "$DOWNLOAD_DIR\velero-plugin.tar.gz" -DestinationPath "$DOWNLOAD_DIR\velero-plugin-temp" -Force
New-Item -ItemType Directory -Force -Path "$FINAL_DIR\binaries\velero-plugins" | Out-Null
Move-Item -Path "$DOWNLOAD_DIR\velero-plugin-temp\*" -Destination "$FINAL_DIR\binaries\velero-plugins\" -Force
Remove-Item -Path "$DOWNLOAD_DIR\velero-plugin-temp" -Recurse -Force

# Create README
Write-Status "Creating README..."
$README_CONTENT = @"
RHEL 9 Airgap Deployment Bundle (Windows Download)
====================================================

Download Date: $(Get-Date)

Components:
- RKE2 v${RKE2_VERSION}
- MetalLB v${METALLB_VERSION}
- Helm v${HELM_VERSION}
- Harbor v${HARBOR_VERSION}
- Longhorn v${LONGHORN_VERSION}
- Velero v${VELERO_VERSION}
- Gitea v${GITEA_VERSION}

Contents:
- binaries/ - RKE2, kubectl, Helm, Velero binaries
- images/ - Container images for all components
- charts/ - Helm charts for Harbor, Longhorn, Gitea
- manifests/ - Kubernetes manifests (MetalLB)
- scripts/ - Installation scripts

Installation:
1. Transfer this bundle to your Linux system (use SCP, SMB, or USB)
2. Extract to /opt/rhel9-airgap-master
3. Run installation scripts on Linux systems

Note: This bundle was downloaded on Windows using Docker.
The RPM repository needs to be created on a RHEL 9 system with internet access.
Run scripts/download-rhel-rpms.sh on a RHEL 9 system to complete the bundle.
"@

Set-Content -Path "$FINAL_DIR\README.txt" -Value $README_CONTENT

# Create installation scripts
Write-Status "Creating installation scripts..."

# MetalLB installation script
$METALLB_SCRIPT = @"
#!/bin/bash
# Script to install MetalLB in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="\${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading MetalLB images..."
ctr -n k8s.io images import `"$ADDONS_DIR/images/metallb-images.tar.gz`"

# Install MetalLB
echo "Installing MetalLB..."
kubectl apply -f `"$ADDONS_DIR/manifests/metallb-native.yaml`" --kubeconfig=`"$KUBECONFIG`"

echo "MetalLB installation complete!"
"@
Set-Content -Path "$FINAL_DIR\scripts\install-metallb.sh" -Value $METALLB_SCRIPT

# Harbor installation script
$HARBOR_SCRIPT = @"
#!/bin/bash
# Script to install Harbor in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="\${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading Harbor images..."
ctr -n k8s.io images import `"$ADDONS_DIR/images/harbor-images.tar.gz`"

# Install Harbor using Helm
echo "Installing Harbor..."
helm install harbor `"$ADDONS_DIR/charts/harbor-${HARBOR_VERSION}.tgz`" --kubeconfig=`"$KUBECONFIG`" --namespace harbor --create-namespace

echo "Harbor installation complete!"
"@
Set-Content -Path "$FINAL_DIR\scripts\install-harbor.sh" -Value $HARBOR_SCRIPT

# Longhorn installation script
$LONGHORN_SCRIPT = @"
#!/bin/bash
# Script to install Longhorn in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="\${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading Longhorn images..."
ctr -n k8s.io images import `"$ADDONS_DIR/images/longhorn-images.tar.gz`"

# Install Longhorn using Helm
echo "Installing Longhorn..."
helm install longhorn `"$ADDONS_DIR/charts/longhorn-${LONGHORN_VERSION}.tgz`" --kubeconfig=`"$KUBECONFIG`" --namespace longhorn-system --create-namespace

echo "Longhorn installation complete!"
"@
Set-Content -Path "$FINAL_DIR\scripts\install-longhorn.sh" -Value $LONGHORN_SCRIPT

# Velero installation script
$VELERO_SCRIPT = @"
#!/bin/bash
# Script to install Velero in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="\${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading Velero images..."
ctr -n k8s.io images import `"$ADDONS_DIR/images/velero-images.tar.gz`"

# Install Velero
echo "Installing Velero..."
velero install --kubeconfig=`"$KUBECONFIG`" --plugins=`"$ADDONS_DIR/binaries/velero-plugins`"

echo "Velero installation complete!"
"@
Set-Content -Path "$FINAL_DIR\scripts\install-velero.sh" -Value $VELERO_SCRIPT

# Gitea installation script
$GITEA_SCRIPT = @"
#!/bin/bash
# Script to install Gitea in airgap environment

set -e

ADDONS_DIR="/opt/add-ons-airgap"
KUBECONFIG="\${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"

# Load images
echo "Loading Gitea images..."
ctr -n k8s.io images import `"$ADDONS_DIR/images/gitea-images.tar.gz`"

# Install Gitea using Helm
echo "Installing Gitea..."
helm install gitea `"$ADDONS_DIR/charts/gitea-${GITEA_VERSION}.tgz`" --kubeconfig=`"$KUBECONFIG`" --namespace gitea --create-namespace

echo "Gitea installation complete!"
"@
Set-Content -Path "$FINAL_DIR\scripts\install-gitea.sh" -Value $GITEA_SCRIPT

# RKE2 installation script
$RKE2_SCRIPT = @"
#!/bin/bash
# Script to install RKE2 from airgap binaries

set -e

RKE2_VERSION="${RKE2_VERSION}"
RKE2_AIRGAP_DIR="/opt/rke2-airgap"
RKE2_INSTALL_DIR="/usr/local/bin"

# Copy binaries
echo "Copying RKE2 binaries..."
cp `"$RKE2_AIRGAP_DIR/binaries/rke2.linux-amd64`" `"$RKE2_INSTALL_DIR/rke2`"
cp `"$RKE2_AIRGAP_DIR/binaries/kubectl`" `"$RKE2_INSTALL_DIR/kubectl`"
chmod +x `"$RKE2_INSTALL_DIR/rke2`"
chmod +x `"$RKE2_INSTALL_DIR/kubectl`"

# Copy images to RKE2 data directory
echo "Copying RKE2 images..."
mkdir -p /var/lib/rancher/rke2/agent/images/
cp `"$RKE2_AIRGAP_DIR/images/rke2-images.linux-amd64.tar.gz`" /var/lib/rancher/rke2/agent/images/

# Run install script with airgap flag
echo "Installing RKE2..."
INSTALL_RKE2_VERSION=`"$RKE2_VERSION`" INSTALL_RKE2_CHANNEL=stable INSTALL_RKE2_ARTIFACT_PATH=`"$RKE2_AIRGAP_DIR/binaries`" `"$RKE2_AIRGAP_DIR/scripts/rke2-install.sh`"

echo "RKE2 airgap installation complete!"
"@
Set-Content -Path "$FINAL_DIR\scripts\install-rke2-airgap.sh" -Value $RKE2_SCRIPT

# Cleanup
Write-Status "Cleaning up temporary files..."
Remove-Item -Path "$DOWNLOAD_DIR" -Recurse -Force

Write-Header "Airgap Download Complete!"
Write-Status "Airgap bundle location: $FINAL_DIR"
$TOTAL_SIZE = (Get-ChildItem -Path $FINAL_DIR -Recurse | Measure-Object -Property Length -Sum).Sum / 1GB
Write-Status "Total size: $([math]::Round($TOTAL_SIZE, 2)) GB"
Write-Status ""
Write-Status "Next steps:"
Write-Status "1. Transfer this bundle to a RHEL 9 system"
Write-Status "2. On RHEL 9, run scripts/download-rhel-rpms.sh to complete the bundle"
Write-Status "3. Transfer the complete bundle to air-gapped systems"
Write-Status "4. Extract and run installation scripts"
Write-Header "=========================================="
