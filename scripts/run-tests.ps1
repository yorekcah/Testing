# PowerShell Test Script for RHEL 9 Airgap Deployment Validation
# This script runs validation tests on all target systems from Windows

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

# Check if Ansible is available
if (-not (Get-Command ansible -ErrorAction SilentlyContinue)) {
    Write-Error "Ansible is not installed. Please install Ansible first."
    exit 1
}

Write-Header "RHEL 9 Airgap Deployment Test Suite (Windows)"

# Check if inventory is configured
if (-not (Test-Path "inventory/hosts.ini")) {
    Write-Error "Inventory file not found: inventory/hosts.ini"
    exit 1
}

# Check for placeholder IPs
$inventoryContent = Get-Content "inventory/hosts.ini" -Raw
if ($inventoryContent -match "JUMP_HOST_IP" -or $inventoryContent -match "SERVER1_IP" -or $inventoryContent -match "AGENT1_IP") {
    Write-Error "Inventory file contains placeholder IPs. Please configure actual host IPs."
    exit 1
}

Write-Status "Starting test suite..."

# Phase 1: Run environment validation on all nodes
Write-Header "Phase 1: Environment Validation"
Write-Status "Running environment validation on all nodes..."

# Copy validation script to all nodes
ansible all -m copy -a "src=scripts/validate-environment.sh dest=/tmp/validate-environment.sh mode=0755"

# Run validation on jump host
Write-Status "Validating jump host..."
ansible jump -m shell -a "sudo /tmp/validate-environment.sh" | Tee-Object -FilePath "C:\temp\jump-validation.log"

# Run validation on RKE2 servers
Write-Status "Validating RKE2 servers..."
ansible rke2_servers -m shell -a "sudo /tmp/validate-environment.sh" | Tee-Object -FilePath "C:\temp\servers-validation.log"

# Run validation on RKE2 agents
Write-Status "Validating RKE2 agents..."
ansible rke2_agents -m shell -a "sudo /tmp/validate-environment.sh" | Tee-Object -FilePath "C:\temp\agents-validation.log"

# Phase 2: Run Ansible connectivity tests
Write-Header "Phase 2: Ansible Connectivity Tests"
Write-Status "Testing Ansible connectivity to all nodes..."

ansible all -m ping | Tee-Object -FilePath "C:\temp\connectivity-test.log"

# Phase 3: Check airgap resources
Write-Header "Phase 3: Airgap Resources Check"
Write-Status "Checking airgap resources on nodes..."

# Check local repository
ansible all -m shell -a "test -d /opt/local-repo && echo 'EXISTS' || echo 'MISSING'" | Tee-Object -FilePath "C:\temp\local-repo-check.log"

# Check RKE2 airgap bundle
ansible all -m shell -a "test -d /opt/rke2-airgap && echo 'EXISTS' || echo 'MISSING'" | Tee-Object -FilePath "C:\temp\rke2-airgap-check.log"

# Check add-ons airgap bundle
ansible all -m shell -a "test -d /opt/add-ons-airgap && echo 'EXISTS' || echo 'MISSING'" | Tee-Object -FilePath "C:\temp\addons-airgap-check.log"

# Phase 4: Pre-deployment checks
Write-Header "Phase 4: Pre-Deployment Checks"
Write-Status "Running pre-deployment validation..."

# Check if services are installed
ansible kubernetes -m shell -a "systemctl is-active firewalld || echo 'NOT_RUNNING'" | Tee-Object -FilePath "C:\temp\firewalld-check.log"

# Check kernel modules
ansible kubernetes -m shell -a "lsmod | grep -E 'overlay|br_netfilter' || echo 'MODULES_NOT_LOADED'" | Tee-Object -FilePath "C:\temp\kernel-modules-check.log"

# Check SELinux status
ansible kubernetes -m shell -a "getenforce" | Tee-Object -FilePath "C:\temp\selinux-check.log"

# Phase 5: Run deployment test playbook (if cluster is already deployed)
Write-Header "Phase 5: Deployment Validation (if cluster exists)"
Write-Status "Running deployment test playbook..."

try {
    ansible-playbook playbooks/test-deployment.yml --ask-become-pass
    Write-Status "Deployment test playbook completed successfully"
} catch {
    Write-Warning "Deployment test playbook failed (cluster may not be deployed yet)"
}

# Phase 6: Generate test report
Write-Header "Phase 6: Test Report Generation"
Write-Status "Generating test report..."

$reportContent = @"
RHEL 9 Airgap Deployment Test Report
=====================================
Date: $(Get-Date)
Test Runner: $env:USERNAME@$env:COMPUTERNAME

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
$(Get-Content "C:\temp\jump-validation.log" -ErrorAction SilentlyContinue | Out-String)

Servers Validation:
$(Get-Content "C:\temp\servers-validation.log" -ErrorAction SilentlyContinue | Out-String)

Agents Validation:
$(Get-Content "C:\temp\agents-validation.log" -ErrorAction SilentlyContinue | Out-String)

Connectivity Test:
$(Get-Content "C:\temp\connectivity-test.log" -ErrorAction SilentlyContinue | Out-String)

Airgap Resources:
Local Repository:
$(Get-Content "C:\temp\local-repo-check.log" -ErrorAction SilentlyContinue | Out-String)

RKE2 Airgap Bundle:
$(Get-Content "C:\temp\rke2-airgap-check.log" -ErrorAction SilentlyContinue | Out-String)

Add-ons Airgap Bundle:
$(Get-Content "C:\temp\addons-airgap-check.log" -ErrorAction SilentlyContinue | Out-String)

Pre-Deployment Checks:
Firewalld Status:
$(Get-Content "C:\temp\firewalld-check.log" -ErrorAction SilentlyContinue | Out-String)

Kernel Modules:
$(Get-Content "C:\temp\kernel-modules-check.log" -ErrorAction SilentlyContinue | Out-String)

SELinux Status:
$(Get-Content "C:\temp\selinux-check.log" -ErrorAction SilentlyContinue | Out-String)

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
3. For detailed troubleshooting: Review individual log files in C:\temp\

=====================================
End of Test Report
=====================================
"@

Set-Content -Path "C:\temp\test-report.txt" -Value $reportContent

Write-Status "Test report generated: C:\temp\test-report.txt"

# Display summary
Write-Header "Test Suite Complete"
Write-Status "Individual test logs available in C:\temp\"
Write-Status "Summary report: C:\temp\test-report.txt"
Write-Status ""
Write-Status "Next steps:"
Write-Status "1. Review the test report: Get-Content C:\temp\test-report.txt"
Write-Status "2. Address any critical issues found"
Write-Status "3. If all tests pass, proceed with deployment"
Write-Status "4. If tests fail, fix issues and re-run this test suite"

Write-Header "=========================================="
