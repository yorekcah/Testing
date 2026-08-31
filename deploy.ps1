# PowerShell deployment script for RKE2 Kubernetes Cluster with MetalLB

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

# Check if Ansible is installed
if (-not (Get-Command ansible -ErrorAction SilentlyContinue)) {
    Write-Error "Ansible is not installed. Please install Ansible first."
    exit 1
}

Write-Status "Ansible version: $(ansible --version | Select-Object -First 1)"

# Check if inventory file exists
if (-not (Test-Path "inventory/hosts.ini")) {
    Write-Warning "Inventory file not found. Copying from example..."
    Copy-Item "inventory/hosts.ini.example" "inventory/hosts.ini"
    Write-Warning "Please edit inventory/hosts.ini with your actual host IPs"
    Write-Warning "Then run this script again"
    exit 1
}

# Check if variables are configured
$inventoryContent = Get-Content "inventory/hosts.ini" -Raw
if ($inventoryContent -match "JUMP_HOST_IP" -or $inventoryContent -match "SERVER1_IP") {
    Write-Error "Please configure the inventory file with actual host IPs"
    Write-Error "Edit inventory/hosts.ini and replace placeholder IPs"
    exit 1
}

Write-Status "Starting RKE2 Kubernetes Cluster deployment..."

# Test connectivity
Write-Status "Testing connectivity to all hosts..."
$pingResult = ansible all -m ping
if ($LASTEXITCODE -ne 0) {
    Write-Error "Connectivity test failed. Please check SSH access and network connectivity."
    exit 1
}

Write-Status "Connectivity test passed!"

# Install Ansible requirements if requirements.yml exists
if (Test-Path "requirements.yml") {
    Write-Status "Installing Ansible collections and roles..."
    ansible-galaxy install -r requirements.yml
}

# Run the main playbook
Write-Status "Deploying RKE2 Kubernetes Cluster with MetalLB..."
$playbookResult = ansible-playbook playbooks/site.yml
if ($LASTEXITCODE -eq 0) {
    Write-Status "=========================================="
    Write-Status "Deployment completed successfully!"
    Write-Status "=========================================="
    Write-Status "Next steps:"
    Write-Status "1. SSH to the jump host: ssh ubuntu@<jump-host-ip>"
    Write-Status "2. Copy kubeconfig: sudo /opt/scripts/kube-config.sh"
    Write-Status "3. Verify cluster: kubectl get nodes"
    Write-Status "=========================================="
} else {
    Write-Error "Deployment failed. Please check the error messages above."
    exit 1
}
