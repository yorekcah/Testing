# RHEL 9 Airgap Deployment Testing Guide

## Overview

Since I cannot directly install and test on actual RHEL 9 airgap systems, I have created a comprehensive testing framework that you can use to validate the deployment on your target systems.

## Testing Tools Created

### 1. Environment Validation Script
**File**: `scripts/validate-environment.sh`

This script validates that each RHEL 9 node is ready for deployment by checking:
- OS version and RHEL subscription status
- Package manager (dnf) availability
- Critical packages (curl, wget, python3, firewalld, chrony, containerd)
- SELinux status and configuration
- Firewall (firewalld) status
- Network Manager status
- Kernel modules (overlay, br_netfilter)
- Sysctl parameters
- System resources (memory, CPU, disk space)
- Swap configuration
- Network connectivity
- Airgap resources (local repository, RKE2 bundle, add-ons bundle)
- SSH configuration
- Time synchronization
- Container runtime status

**Usage**:
```bash
# Run on individual nodes
sudo ./scripts/validate-environment.sh

# Or run via Ansible on all nodes
ansible all -m copy -a "src=scripts/validate-environment.sh dest=/tmp/validate-environment.sh mode=0755"
ansible all -m shell -a "sudo /tmp/validate-environment.sh"
```

### 2. Deployment Test Playbook
**File**: `playbooks/test-deployment.yml`

This playbook validates that the RKE2 cluster is deployed correctly by testing:
- Jump host accessibility and configuration
- RKE2 server accessibility and service status
- RKE2 agent accessibility and service status
- Kubernetes cluster functionality
- Cluster node status
- Pod deployment and status
- MetalLB configuration and status
- Network connectivity between nodes
- Firewall configuration

**Usage**:
```bash
# Run the test playbook
ansible-playbook playbooks/test-deployment.yml --ask-become-pass
```

### 3. Master Test Suite
**Files**: `scripts/run-tests.sh` (Linux) and `scripts/run-tests.ps1` (Windows)

These scripts orchestrate the complete testing process:
- Environment validation on all nodes
- Ansible connectivity tests
- Airgap resources verification
- Pre-deployment checks
- Deployment validation (if cluster exists)
- Test report generation

**Usage**:
```bash
# Linux
./scripts/run-tests.sh

# Windows
.\scripts\run-tests.ps1
```

### 4. Playbook Validation Script
**File**: `scripts/validate-playbooks.sh`

This script validates Ansible playbooks without deploying:
- Ansible configuration file syntax
- Inventory file validation
- Group variables YAML syntax
- Playbook syntax checking
- Ansible collections installation
- Role dependencies checking
- Dry-run simulation

**Usage**:
```bash
./scripts/validate-playbooks.sh
```

## Testing Workflow

### Phase 1: Pre-Deployment Validation

#### Step 1: Validate Playbooks Locally
```bash
cd ansible
./scripts/validate-playbooks.sh
```

This ensures all playbooks have correct syntax and variables before deployment.

#### Step 2: Configure Inventory
Edit `inventory/hosts.ini` with your actual RHEL 9 host IPs:
```ini
[all:vars]
ansible_user=rhel
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
ansible_os_family=RedHat
ansible_distribution_version=9

[jump]
jump-server ansible_host=192.168.1.10 ansible_port=22

[rke2_servers]
server-1 ansible_host=192.168.1.11 ansible_port=22
server-2 ansible_host=192.168.1.12 ansible_port=22
server-3 ansible_host=192.168.1.13 ansible_port=22

[rke2_agents]
agent-1 ansible_host=192.168.1.14 ansible_port=22
agent-2 ansible_host=192.168.1.15 ansible_port=22
agent-3 ansible_host=192.168.1.16 ansible_port=22
```

#### Step 3: Test Connectivity
```bash
# Test SSH connectivity
ansible all -m ping

# Run full test suite
.\scripts\run-tests.ps1
```

### Phase 2: Airgap Preparation

#### Step 1: Download Airgap Bundle
```bash
# On internet-connected RHEL 9 system
cd ansible/scripts
sudo ./download-all-airgap.sh
```

#### Step 2: Transfer to Airgap Environment
```bash
# Transfer to jump host
scp /tmp/rhel9-airgap-master.tar.gz rhel@jump-host:/tmp/

# On jump host
sudo tar -xzf /tmp/rhel9-airgap-master.tar.gz -C /opt/
cd /opt/rhel9-airgap-master
sudo ./install-all.sh
```

#### Step 3: Validate Airgap Resources
```bash
# Run test suite to verify airgap resources
.\scripts\run-tests.ps1
```

### Phase 3: Deployment

#### Step 1: Deploy Cluster
```powershell
# From Windows control machine
cd C:\Users\A\ansible
.\deploy.ps1
```

#### Step 2: Post-Deployment Testing
```bash
# Run deployment test playbook
ansible-playbook playbooks/test-deployment.yml --ask-become-pass
```

### Phase 4: Functional Testing

#### Step 1: Test Kubernetes Functionality
```bash
# SSH to jump host
ssh rhel@jump-host

# Copy kubeconfig
sudo /opt/scripts/kube-config.sh

# Test cluster
kubectl get nodes
kubectl get pods --all-namespaces
kubectl cluster-info
```

#### Step 2: Test MetalLB
```bash
# Deploy test application
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Verify LoadBalancer IP assignment
kubectl get svc nginx

# Test connectivity
curl http://<EXTERNAL-IP>
```

#### Step 3: Test Add-ons (if installed)
```bash
# Test Harbor
kubectl get pods -n harbor
kubectl get svc -n harbor

# Test Longhorn
kubectl get pods -n longhorn-system
kubectl get storageclass

# Test Velero
kubectl get pods -n velero
velero backup get

# Test Gitea
kubectl get pods -n gitea
kubectl get svc -n gitea
```

## Expected Test Results

### Successful Deployment Indicators

#### Environment Validation
- ✅ RHEL 9 detected
- ✅ dnf package manager available
- ✅ SELinux in permissive mode
- ✅ firewalld running
- ✅ NetworkManager running
- ✅ Kernel modules loaded
- ✅ System resources sufficient
- ✅ Airgap resources present

#### Deployment Test
- ✅ All nodes accessible via Ansible
- ✅ RKE2 services running
- ✅ Kubernetes cluster functional
- ✅ All nodes in Ready state
- ✅ System pods running
- ✅ MetalLB configured
- ✅ Network connectivity working

#### Functional Test
- ✅ kubectl commands working
- ✅ Pods can be deployed
- ✅ Services get LoadBalancer IPs
- ✅ External connectivity working
- ✅ Add-ons functioning correctly

### Common Issues and Solutions

#### Issue: SELinux Blocking Container Runtime
**Symptom**: containerd or RKE2 fails to start
**Solution**: Playbooks set SELinux to permissive mode, verify with `sestatus`

#### Issue: Missing Airgap Resources
**Symptom**: Package installation fails
**Solution**: Ensure airgap bundle is properly extracted on all nodes

#### Issue: Network Connectivity
**Symptom**: Nodes cannot communicate
**Solution**: Check firewalld rules and network configuration

#### Issue: RKE2 Service Fails
**Symptom**: rke2-server or rke2-agent not starting
**Solution**: Check logs with `journalctl -u rke2-server -f`

## Automated Testing Commands

### Quick Validation
```bash
# Validate playbooks
./scripts/validate-playbooks.sh

# Test connectivity
ansible all -m ping

# Run environment validation
ansible all -m shell -a "sudo /tmp/validate-environment.sh"
```

### Full Test Suite
```bash
# Windows
.\scripts\run-tests.ps1

# Linux
./scripts/run-tests.sh
```

### Deployment Testing
```bash
# Test deployment
ansible-playbook playbooks/test-deployment.yml --ask-become-pass

# Test specific components
ansible-playbook playbooks/test-deployment.yml --limit rke2_servers --ask-become-pass
```

## Continuous Monitoring

### Health Check Script
```bash
#!/bin/bash
# Simple health check script

# Check RKE2 services
for node in server-1 server-2 server-3 agent-1 agent-2 agent-3; do
    echo "Checking $node..."
    ssh rhel@$node "sudo systemctl status rke2-server" || \
    ssh rhel@$node "sudo systemctl status rke2-agent"
done

# Check cluster nodes
ssh rhel@jump-host "kubectl get nodes"

# Check critical pods
ssh rhel@jump-host "kubectl get pods -n kube-system"
```

## Troubleshooting Guide

### Common Validation Failures

#### 1. Package Manager Issues
**Error**: `dnf command not found`
**Solution**: Ensure RHEL 9 is properly installed and subscribed

#### 2. SELinux Issues
**Error**: SELinux blocking operations
**Solution**: Verify SELinux status and playbooks configure it correctly

#### 3. Network Issues
**Error**: Nodes cannot communicate
**Solution**: Check firewall rules and network configuration

#### 4. Resource Issues
**Error**: Insufficient memory or CPU
**Solution**: Verify system requirements are met

## Testing Checklist

### Pre-Deployment
- [ ] Playbooks validated
- [ ] Inventory configured
- [ ] SSH keys distributed
- [ ] Connectivity tested
- [ ] Airgap bundle prepared
- [ ] Airgap resources transferred
- [ ] Environment validation passed

### During Deployment
- [ ] Jump host configured
- [ ] Network configured
- [ ] RKE2 servers installed
- [ ] RKE2 agents installed
- [ ] MetalLB configured
- [ ] Add-ons installed (if enabled)

### Post-Deployment
- [ ] Cluster nodes ready
- [ ] Pods running
- [ ] Services accessible
- [ ] LoadBalancer IPs assigned
- [ ] Network connectivity working
- [ ] Add-ons functional

## Conclusion

While I cannot directly test on your RHEL 9 airgap systems, the comprehensive testing framework I've created will allow you to:

1. **Validate playbooks** before deployment
2. **Test environment readiness** on all nodes
3. **Validate airgap resources** are properly prepared
4. **Test deployment** after installation
5. **Monitor cluster health** continuously

Run the test suite at each phase to ensure successful deployment of your 1 jump, 3 server, 3 agent RHEL 9 airgap Kubernetes cluster.

## Support

If you encounter issues during testing:
1. Review individual test logs in `/tmp/` or `C:\temp\`
2. Check the test report generated by the test suite
3. Refer to the troubleshooting guide above
4. Review the RHEL9-COMPATIBILITY.md for known issues
