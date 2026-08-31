#!/bin/bash
# Quick deployment script for RKE2 Kubernetes Cluster with MetalLB

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Ansible is installed
if ! command -v ansible &> /dev/null; then
    print_error "Ansible is not installed. Please install Ansible first."
    exit 1
fi

print_status "Ansible version: $(ansible --version | head -n 1)"

# Check if inventory file exists
if [ ! -f "inventory/hosts.ini" ]; then
    print_warning "Inventory file not found. Copying from example..."
    cp inventory/hosts.ini.example inventory/hosts.ini
    print_warning "Please edit inventory/hosts.ini with your actual host IPs"
    print_warning "Then run this script again"
    exit 1
fi

# Check if variables are configured
if grep -q "JUMP_HOST_IP" inventory/hosts.ini || grep -q "SERVER1_IP" inventory/hosts.ini; then
    print_error "Please configure the inventory file with actual host IPs"
    print_error "Edit inventory/hosts.ini and replace placeholder IPs"
    exit 1
fi

print_status "Starting RKE2 Kubernetes Cluster deployment..."

# Test connectivity
print_status "Testing connectivity to all hosts..."
if ! ansible all -m ping; then
    print_error "Connectivity test failed. Please check SSH access and network connectivity."
    exit 1
fi

print_status "Connectivity test passed!"

# Install Ansible requirements if requirements.yml exists
if [ -f "requirements.yml" ]; then
    print_status "Installing Ansible collections and roles..."
    ansible-galaxy install -r requirements.yml
fi

# Run the main playbook
print_status "Deploying RKE2 Kubernetes Cluster with MetalLB..."
if ansible-playbook playbooks/site.yml; then
    print_status "=========================================="
    print_status "Deployment completed successfully!"
    print_status "=========================================="
    print_status "Next steps:"
    print_status "1. SSH to the jump host: ssh ubuntu@<jump-host-ip>"
    print_status "2. Copy kubeconfig: sudo /opt/scripts/kube-config.sh"
    print_status "3. Verify cluster: kubectl get nodes"
    print_status "=========================================="
else
    print_error "Deployment failed. Please check the error messages above."
    exit 1
fi
