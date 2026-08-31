#!/bin/bash
# Master test script for RHEL 9 airgap deployment validation
# This script runs validation tests on all target systems

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

# Check if Ansible is available
if ! command -v ansible &> /dev/null; then
    print_error "Ansible is not installed or not in PATH"
    exit 1
fi

print_header "RHEL 9 Airgap Deployment Test Suite"

# Check if inventory is configured
if [ ! -f "inventory/hosts.ini" ]; then
    print_error "Inventory file not found: inventory/hosts.ini"
    exit 1
fi

# Check for placeholder IPs
if grep -q "JUMP_HOST_IP\|SERVER1_IP\|AGENT1_IP" inventory/hosts.ini; then
    print_error "Inventory file contains placeholder IPs. Please configure actual host IPs."
    exit 1
fi

print_status "Starting test suite..."

# Phase 1: Run environment validation on all nodes
print_header "Phase 1: Environment Validation"
print_status "Running environment validation on all nodes..."

# Copy validation script to all nodes
ansible all -m copy -a "src=scripts/validate-environment.sh dest=/tmp/validate-environment.sh mode=0755"

# Run validation on jump host
print_status "Validating jump host..."
ansible jump -m shell -a "sudo /tmp/validate-environment.sh" | tee /tmp/jump-validation.log

# Run validation on RKE2 servers
print_status "Validating RKE2 servers..."
ansible rke2_servers -m shell -a "sudo /tmp/validate-environment.sh" | tee /tmp/servers-validation.log

# Run validation on RKE2 agents
print_status "Validating RKE2 agents..."
ansible rke2_agents -m shell -a "sudo /tmp/validate-environment.sh" | tee /tmp/agents-validation.log

# Phase 2: Run Ansible connectivity tests
print_header "Phase 2: Ansible Connectivity Tests"
print_status "Testing Ansible connectivity to all nodes..."

ansible all -m ping | tee /tmp/connectivity-test.log

# Phase 3: Check airgap resources
print_header "Phase 3: Airgap Resources Check"
print_status "Checking airgap resources on nodes..."

# Check local repository
ansible all -m shell -a "test -d /opt/local-repo && echo 'EXISTS' || echo 'MISSING'" | tee /tmp/local-repo-check.log

# Check RKE2 airgap bundle
ansible all -m shell -a "test -d /opt/rke2-airgap && echo 'EXISTS' || echo 'MISSING'" | tee /tmp/rke2-airgap-check.log

# Check add-ons airgap bundle
ansible all -m shell -a "test -d /opt/add-ons-airgap && echo 'EXISTS' || echo 'MISSING'" | tee /tmp/addons-airgap-check.log

# Phase 4: Pre-deployment checks
print_header "Phase 4: Pre-Deployment Checks"
print_status "Running pre-deployment validation..."

# Check if services are installed
ansible kubernetes -m shell -a "systemctl is-active firewalld || echo 'NOT_RUNNING'" | tee /tmp/firewalld-check.log

# Check kernel modules
ansible kubernetes -m shell -a "lsmod | grep -E 'overlay|br_netfilter' || echo 'MODULES_NOT_LOADED'" | tee /tmp/kernel-modules-check.log

# Check SELinux status
ansible kubernetes -m shell -a "getenforce" | tee /tmp/selinux-check.log

# Phase 5: Run deployment test playbook (if cluster is already deployed)
print_header "Phase 5: Deployment Validation (if cluster exists)"
print_status "Running deployment test playbook..."

if ansible-playbook playbooks/test-deployment.yml --ask-become-pass; then
    print_status "Deployment test playbook completed successfully"
else
    print_warning "Deployment test playbook failed (cluster may not be deployed yet)"
fi

# Phase 6: Generate test report
print_header "Phase 6: Test Report Generation"
print_status "Generating test report..."

cat > /tmp/test-report.txt << EOF
RHEL 9 Airgap Deployment Test Report
=====================================
Date: $(date)
Test Runner: $(whoami)@$(hostname)

SUMMARY
-------
Test phases completed:
1. Environment Validation
2. Ansible Connectivity Tests
3. Airgap Resources Check
4. Pre-Deployment Checks
5. Deployment Validation (if applicable)

DETAILED RESULTS
---------------
Jump Host Validation:
$(cat /tmp/jump-validation.log 2>/dev/null || echo "No data")

Servers Validation:
$(cat /tmp/servers-validation.log 2>/dev/null || echo "No data")

Agents Validation:
$(cat /tmp/agents-validation.log 2>/dev/null || echo "No data")

Connectivity Test:
$(cat /tmp/connectivity-test.log 2>/dev/null || echo "No data")

Airgap Resources:
Local Repository:
$(cat /tmp/local-repo-check.log 2>/dev/null || echo "No data")

RKE2 Airgap Bundle:
$(cat /tmp/rke2-airgap-check.log 2>/dev/null || echo "No data")

Add-ons Airgap Bundle:
$(cat /tmp/addons-airgap-check.log 2>/dev/null || echo "No data")

Pre-Deployment Checks:
Firewalld Status:
$(cat /tmp/firewalld-check.log 2>/dev/null || echo "No data")

Kernel Modules:
$(cat /tmp/kernel-modules-check.log 2>/dev/null || echo "No data")

SELinux Status:
$(cat /tmp/selinux-check.log 2>/dev/null || echo "No data")

RECOMMENDATIONS
---------------
1. Review all validation logs above
2. Address any critical failures before deployment
3. Ensure airgap resources are available on all nodes
4. Verify network connectivity between all nodes
5. Check that system requirements are met

NEXT STEPS
----------
1. If all validations pass: Run deployment with ansible-playbook playbooks/site.yml
2. If validations fail: Address issues and re-run this test suite
3. For detailed troubleshooting: Review individual log files in /tmp/

=====================================
End of Test Report
=====================================
EOF

print_status "Test report generated: /tmp/test-report.txt"

# Display summary
print_header "Test Suite Complete"
print_status "Individual test logs available in /tmp/"
print_status "Summary report: /tmp/test-report.txt"
print_status ""
print_status "Next steps:"
print_status "1. Review the test report: cat /tmp/test-report.txt"
print_status "2. Address any critical issues found"
print_status "3. If all tests pass, proceed with deployment"
print_status "4. If tests fail, fix issues and re-run this test suite"

print_header "=========================================="
