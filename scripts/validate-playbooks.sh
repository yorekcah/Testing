#!/bin/bash
# Playbook Validation Script
# This script validates Ansible playbooks without actually deploying

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

function print_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

function print_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_header "Ansible Playbook Validation"

# Check if Ansible is available
if ! command -v ansible &> /dev/null; then
    print_error "Ansible is not installed or not in PATH"
    exit 1
fi

print_status "Ansible version: $(ansible --version | head -n 1)"

# Validate ansible.cfg
print_header "1. Validating Ansible Configuration"
if [ -f "ansible.cfg" ]; then
    if ansible-config view > /dev/null 2>&1; then
        print_pass "ansible.cfg is valid"
    else
        print_fail "ansible.cfg has errors"
    fi
else
    print_warning "ansible.cfg not found (using defaults)"
fi

# Validate inventory
print_header "2. Validating Inventory File"
if [ -f "inventory/hosts.ini" ]; then
    if ansible-inventory -i inventory/hosts.ini --list > /dev/null 2>&1; then
        print_pass "inventory/hosts.ini is valid"
        print_status "Inventory groups:"
        ansible-inventory -i inventory/hosts.ini --list
    else
        print_fail "inventory/hosts.ini has errors"
    fi
else
    print_fail "inventory/hosts.ini not found"
fi

# Validate group_vars
print_header "3. Validating Group Variables"
VAR_FILES=("group_vars/all.yml" "group_vars/jump.yml" "group_vars/rke2_servers.yml" "group_vars/rke2_agents.yml")
for var_file in "${VAR_FILES[@]}"; do
    if [ -f "$var_file" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('$var_file'))" 2>/dev/null; then
            print_pass "$var_file is valid YAML"
        else
            print_fail "$var_file has YAML syntax errors"
        fi
    else
        print_warning "$var_file not found"
    fi
done

# Validate playbooks
print_header "4. Validating Playbooks"
PLAYBOOKS=(
    "playbooks/jump-host-setup.yml"
    "playbooks/network-firewall-setup.yml"
    "playbooks/rke2-server-setup.yml"
    "playbooks/rke2-agent-setup.yml"
    "playbooks/metallb-setup.yml"
    "playbooks/add-ons-setup.yml"
    "playbooks/site.yml"
    "playbooks/test-deployment.yml"
)

for playbook in "${PLAYBOOKS[@]}"; do
    if [ -f "$playbook" ]; then
        print_status "Validating $playbook..."
        if ansible-playbook "$playbook" --syntax-check > /dev/null 2>&1; then
            print_pass "$playbook syntax is valid"
        else
            print_fail "$playbook has syntax errors"
            ansible-playbook "$playbook" --syntax-check
        fi
    else
        print_warning "$playbook not found"
    fi
done

# Check for required collections
print_header "5. Checking Ansible Collections"
if [ -f "requirements.yml" ]; then
    print_status "Installing required collections..."
    if ansible-galaxy install -r requirements.yml --force > /dev/null 2>&1; then
        print_pass "Collections installed successfully"
    else
        print_warning "Some collections may have failed to install"
    fi
else
    print_warning "requirements.yml not found"
fi

# Check for role dependencies
print_header "6. Checking Role Dependencies"
if [ -d "roles" ]; then
    ROLE_COUNT=$(find roles -name "*.yml" | wc -l)
    print_status "Found $ROLE_COUNT role files"
    if [ $ROLE_COUNT -gt 0 ]; then
        print_pass "Roles directory exists with content"
    else
        print_warning "Roles directory is empty"
    fi
else
    print_warning "No roles directory found"
fi

# Dry-run simulation
print_header "7. Running Dry-Run Simulation"
print_status "Running check mode on site.yml (will not make changes)..."
if ansible-playbook playbooks/site.yml --check --diff --skip-tags "skip_ansible_lint" > /tmp/dry-run.log 2>&1; then
    print_pass "Dry-run completed successfully"
    print_status "Dry-run log: /tmp/dry-run.log"
else
    print_warning "Dry-run completed with warnings (expected if cluster not deployed)"
    print_status "Dry-run log: /tmp/dry-run.log"
fi

# Final summary
print_header "Validation Complete"
print_status "Review the results above to ensure playbooks are ready for deployment."
print_status "Critical failures should be addressed before running the actual deployment."
print_status "Warnings may indicate missing optional components."

print_header "=========================================="
