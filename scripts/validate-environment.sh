#!/bin/bash
# RHEL 9 Environment Validation Script
# This script validates that the target RHEL 9 environment is ready for deployment

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

function check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

function check_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

function check_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

print_header "RHEL 9 Environment Validation"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_warning "Not running as root. Some checks may fail."
fi

# Check OS version
print_header "1. Operating System Check"
if [ -f /etc/redhat-release ]; then
    OS_VERSION=$(cat /etc/redhat-release)
    print_status "Detected: $OS_VERSION"
    if [[ "$OS_VERSION" == *"Red Hat Enterprise Linux release 9"* ]]; then
        check_pass "RHEL 9 detected"
    else
        check_fail "RHEL 9 not detected. Found: $OS_VERSION"
    fi
else
    check_fail "Not a Red Hat system"
fi

# Check RHEL subscription
print_header "2. RHEL Subscription Check"
if command -v subscription-manager &> /dev/null; then
    SUBSCRIPTION_STATUS=$(subscription-manager status 2>/dev/null || echo "Not registered")
    if [[ "$SUBSCRIPTION_STATUS" == *"Content Access Mode is set to Simple Content Access"* ]] || [[ "$SUBSCRIPTION_STATUS" == *"Overall Status: Current"* ]]; then
        check_pass "RHEL subscription active"
    else
        print_warning "RHEL subscription not active or not in airgap mode"
        check_skip "Subscription check (may be airgap environment)"
    fi
else
    check_skip "subscription-manager not found (airgap environment)"
fi

# Check package manager
print_header "3. Package Manager Check"
if command -v dnf &> /dev/null; then
    DNF_VERSION=$(dnf --version | head -n 1)
    check_pass "dnf available: $DNF_VERSION"
else
    check_fail "dnf not found"
fi

# Check critical packages
print_header "4. Critical Packages Check"
CRITICAL_PACKAGES=("curl" "wget" "python3" "firewalld" "chrony" "containerd")
for package in "${CRITICAL_PACKAGES[@]}"; do
    if rpm -q "$package" &> /dev/null; then
        check_pass "$package installed"
    else
        print_warning "$package not installed (will be installed by Ansible)"
    fi
done

# Check SELinux
print_header "5. SELinux Check"
if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce)
    print_status "SELinux status: $SELINUX_STATUS"
    if [[ "$SELINUX_STATUS" == "Enforcing" ]]; then
        print_warning "SELinux is enforcing - playbooks will set to permissive"
        check_pass "SELinux detected (will be configured)"
    elif [[ "$SELINUX_STATUS" == "Permissive" ]]; then
        check_pass "SELinux already permissive"
    else
        check_skip "SELinux disabled"
    fi
else
    check_skip "SELinux not found"
fi

# Check firewall
print_header "6. Firewall Check"
if systemctl is-active --quiet firewalld; then
    check_pass "firewalld is running"
    FIREWALL_ZONES=$(firewall-cmd --get-active-zones)
    print_status "Active zones: $FIREWALL_ZONES"
else
    print_warning "firewalld not running (will be started by Ansible)"
fi

# Check NetworkManager
print_header "7. Network Manager Check"
if systemctl is-active --quiet NetworkManager; then
    check_pass "NetworkManager is running"
    NM_CONNECTIONS=$(nmcli -t -f NAME connection show)
    print_status "Network connections: $NM_CONNECTIONS"
else
    check_fail "NetworkManager not running"
fi

# Check kernel modules
print_header "8. Kernel Modules Check"
KERNEL_MODULES=("overlay" "br_netfilter")
for module in "${KERNEL_MODULES[@]}"; do
    if lsmod | grep -q "^$module "; then
        check_pass "$module module loaded"
    else
        print_warning "$module module not loaded (will be loaded by Ansible)"
    fi
done

# Check sysctl parameters
print_header "9. Sysctl Parameters Check"
SYSPCTL_PARAMS=("net.ipv4.ip_forward" "net.bridge.bridge-nf-call-iptables")
for param in "${SYSPCTL_PARAMS[@]}"; do
    if sysctl "$param" &> /dev/null; then
        VALUE=$(sysctl -n "$param")
        print_status "$param = $VALUE"
        if [[ "$param" == *"ip_forward"* ]] && [[ "$VALUE" == "1" ]]; then
            check_pass "$param is set correctly"
        elif [[ "$param" == *"bridge-nf-call"* ]] && [[ "$VALUE" == "1" ]]; then
            check_pass "$param is set correctly"
        else
            print_warning "$param not set correctly (will be configured by Ansible)"
        fi
    else
        print_warning "$param not found (will be configured by Ansible)"
    fi
done

# Check system resources
print_header "10. System Resources Check"
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
DISK_SPACE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')

print_status "Total Memory: ${TOTAL_MEM}GB"
print_status "CPU Cores: $CPU_CORES"
print_status "Available Disk Space: ${DISK_SPACE}GB"

if [[ $TOTAL_MEM -ge 4 ]]; then
    check_pass "Memory sufficient (>= 4GB)"
else
    check_fail "Memory insufficient (< 4GB)"
fi

if [[ $CPU_CORES -ge 2 ]]; then
    check_pass "CPU cores sufficient (>= 2)"
else
    check_fail "CPU cores insufficient (< 2)"
fi

if [[ $DISK_SPACE -ge 20 ]]; then
    check_pass "Disk space sufficient (>= 20GB)"
else
    check_fail "Disk space insufficient (< 20GB)"
fi

# Check swap
print_header "11. Swap Check"
SWAP_TOTAL=$(free -g | awk '/^Swap:/{print $2}')
if [[ $SWAP_TOTAL -eq 0 ]]; then
    check_pass "Swap disabled (recommended for Kubernetes)"
else
    print_warning "Swap enabled ($SWAP_TOTAL GB) - should be disabled for Kubernetes"
fi

# Check network connectivity
print_header "12. Network Connectivity Check"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
    check_pass "Internet connectivity available"
    INTERNET_AVAILABLE=true
else
    print_warning "No internet connectivity (expected in airgap environment)"
    INTERNET_AVAILABLE=false
fi

# Check airgap resources
print_header "13. Airgap Resources Check"
if [ -d "/opt/local-repo" ]; then
    check_pass "Local RPM repository exists"
    REPO_PACKAGES=$(find /opt/local-repo -name "*.rpm" | wc -l)
    print_status "RPM packages in local repo: $REPO_PACKAGES"
else
    print_warning "Local RPM repository not found (may need to be created)"
fi

if [ -d "/opt/rke2-airgap" ]; then
    check_pass "RKE2 airgap bundle exists"
    RKE2_IMAGES=$(find /opt/rke2-airgap -name "*.tar.gz" | wc -l)
    print_status "RKE2 image archives: $RKE2_IMAGES"
else
    print_warning "RKE2 airgap bundle not found (may need to be created)"
fi

if [ -d "/opt/add-ons-airgap" ]; then
    check_pass "Add-ons airgap bundle exists"
    ADDON_IMAGES=$(find /opt/add-ons-airgap -name "*.tar.gz" | wc -l)
    print_status "Add-on image archives: $ADDON_IMAGES"
else
    print_warning "Add-ons airgap bundle not found (may need to be created)"
fi

# Check SSH access
print_header "14. SSH Configuration Check"
if [ -f /etc/ssh/sshd_config ]; then
    SSHD_RUNNING=$(systemctl is-active sshd)
    if [[ "$SSHD_RUNNING" == "active" ]]; then
        check_pass "SSH daemon is running"
    else
        check_fail "SSH daemon not running"
    fi
else
    check_fail "SSH configuration not found"
fi

# Check time synchronization
print_header "15. Time Synchronization Check"
if systemctl is-active --quiet chronyd; then
    check_pass "chrony time service is running"
    CHRONY_SOURCES=$(chronyc sources 2>/dev/null | head -10)
    print_status "Chrony sources: $CHRONY_SOURCES"
else
    print_warning "chrony not running (will be installed by Ansible)"
fi

# Check container runtime
print_header "16. Container Runtime Check"
if systemctl is-active --quiet containerd; then
    check_pass "containerd is running"
    CONTAINERD_VERSION=$(containerd --version)
    print_status "containerd version: $CONTAINERD_VERSION"
else
    print_warning "containerd not running (will be installed by RKE2)"
fi

# Check disk mounting
print_header "17. Disk Mounting Check"
MOUNT_POINTS=("/var/lib/rancher" "/etc/rancher" "/opt")
for mount_point in "${MOUNT_POINTS[@]}"; do
    if mountpoint -q "$mount_point"; then
        check_pass "$mount_point is mounted"
    else
        print_warning "$mount_point not mounted (will be created by Ansible)"
    fi
done

# Final summary
print_header "Validation Complete"
print_status "Review the results above to ensure your environment is ready for deployment."
print_status "Critical failures should be addressed before running the Ansible deployment."
print_status "Warnings indicate items that will be handled by the deployment playbooks."

if [ "$INTERNET_AVAILABLE" = true ]; then
    print_warning "Internet connectivity detected - this appears to NOT be an airgap environment"
    print_warning "Ensure airgap resources are properly prepared for airgap deployment"
else
    check_pass "No internet connectivity - consistent with airgap environment"
fi

print_header "=========================================="
