# RKE2 Kubernetes Cluster with MetalLB - Ansible Deployment for RHEL 9 Airgap

This Ansible playbook automates the deployment of a production-ready RKE2 Kubernetes cluster with MetalLB load balancing on RHEL 9 in an air-gapped environment with support for Harbor, Longhorn, Velero, and Gitea.

## Architecture

- **1 Jump Host**: Bastion host with kubectl, Helm, and management tools
- **3 RKE2 Servers**: Control plane nodes (etcd + API server + scheduler + controller manager)
- **3 RKE2 Agents**: Worker nodes for running workloads
- **MetalLB**: Load balancer for Kubernetes services
- **HAProxy**: Load balancer for RKE2 API server high availability
- **Optional Add-ons**: Harbor (container registry), Longhorn (storage), Velero (backup), Gitea (Git hosting)

## Airgap Deployment Overview

This deployment is designed for RHEL 9 air-gapped environments where internet access is restricted. The process involves:

1. **Download Phase** (on internet-connected system): Download all required RPMs, binaries, container images, and charts
2. **Transfer Phase**: Move the airgap bundle to the air-gapped environment
3. **Deployment Phase**: Use Ansible to deploy the cluster using local resources

## Prerequisites

### Control Machine Requirements
- Ansible 2.9 or higher
- Python 3.6+
- SSH access to all target hosts
- SSH key authentication configured

### Target Host Requirements
- **RHEL 9.x** (Red Hat Enterprise Linux 9)
- Minimum 2 CPU cores
- Minimum 4GB RAM per node
- Minimum 20GB disk space per node
- Network connectivity between all nodes
- Root or sudo access
- Subscribed to RHEL repositories (if not using local repository)

### Network Requirements
- All nodes must be on the same network segment
- SSH access (port 22) from control machine
- The following IP ranges must be available:
  - MetalLB IP range: `192.168.1.200-192.168.1.250` (configurable)
  - Load balancer IP: `192.168.1.199` (configurable)
  - Pod CIDR: `10.42.0.0/16` (configurable)
  - Service CIDR: `10.43.0.0/16` (configurable)

## Airgap Preparation

### Step 1: Download Airgap Bundle

On an internet-connected RHEL 9 system, run the download scripts:

```bash
# Navigate to scripts directory
cd ansible/scripts

# Make scripts executable
chmod +x download-*.sh

# Download all components (RPMs, RKE2, Add-ons)
sudo ./download-all-airgap.sh
```

This will create `/tmp/rhel9-airgap-master.tar.gz` containing:
- RHEL 9 RPM packages and local repository
- RKE2 binaries and container images
- Add-ons (MetalLB, Helm, Harbor, Longhorn, Velero, Gitea)

### Step 2: Transfer Airgap Bundle

Transfer the airgap bundle to your air-gapped environment:

```bash
# From internet-connected system
scp /tmp/rhel9-airgap-master.tar.gz user@jump-host:/tmp/

# On the jump host
sudo tar -xzf /tmp/rhel9-airgap-master.tar.gz -C /opt/
cd /opt/rhel9-airgap-master
sudo ./install-all.sh
```

### Step 3: Prepare Local Repository

The master installation script will:
1. Set up local RPM repository
2. Install RKE2 binaries
3. Load container images
4. Prepare add-ons for installation

## Deployment

### 1. Configure Inventory

Edit `inventory/hosts.ini` and replace the placeholder IP addresses with your actual host IPs:

```ini
[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3
ansible_os_family=RedHat
ansible_distribution_version=9

[jump]
jump-server ansible_host=YOUR_JUMP_HOST_IP ansible_port=22

[rke2_servers]
server-1 ansible_host=YOUR_SERVER1_IP ansible_port=22
server-2 ansible_host=YOUR_SERVER2_IP ansible_port=22
server-3 ansible_host=YOUR_SERVER3_IP ansible_port=22

[rke2_agents]
agent-1 ansible_host=YOUR_AGENT1_IP ansible_port=22
agent-2 ansible_host=YOUR_AGENT2_IP ansible_port=22
agent-3 ansible_host=YOUR_AGENT3_IP ansible_port=22
```

### 2. Configure Variables

Edit the variables in `group_vars/` to match your environment:

- `all.yml`: Common configuration (RKE2 version, MetalLB settings, network CIDRs, airgap settings)
- `jump.yml`: Jump host specific settings
- `rke2_servers.yml`: Control plane configuration
- `rke2_agents.yml`: Worker node configuration

Key variables to customize:

```yaml
# OS Configuration
os_family: "RedHat"
os_distribution: "RedHat"
os_version: "9"

# Airgap Configuration
airgap_enabled: true
airgap_local_repo_path: "/opt/local-repo"
airgap_container_images_path: "/opt/container-images"
airgap_rke2_binary_path: "/opt/rke2-airgap"
airgap_addons_path: "/opt/add-ons-airgap"

# RKE2 version
rke2_version: "v1.28.10+rke2r1"

# MetalLB configuration
metallb_version: "v0.14.0"
metallb_ip_range: "192.168.1.200-192.168.1.250"
metallb_protocol: "layer2"

# Add-on installation flags
install_harbor: false      # Set to true to install Harbor
install_longhorn: false   # Set to true to install Longhorn
install_velero: false     # Set to true to install Velero
install_gitea: false      # Set to true to install Gitea

# Network configuration
pod_cidr: "10.42.0.0/16"
service_cidr: "10.43.0.0/16"
api_server_loadbalancer_ip: "192.168.1.199"
```

### 3. SSH Key Configuration

Ensure your SSH key is configured for passwordless access to all hosts:

```bash
# Copy SSH key to all hosts
ssh-copy-id ubuntu@<jump-host-ip>
ssh-copy-id ubuntu@<server1-ip>
ssh-copy-id ubuntu@<server2-ip>
ssh-copy-id ubuntu@<server3-ip>
ssh-copy-id ubuntu@<agent1-ip>
ssh-copy-id ubuntu@<agent2-ip>
ssh-copy-id ubuntu@<agent3-ip>
```

### 4. Test Connectivity

```bash
# Test Ansible connectivity
ansible all -m ping

# Test specific groups
ansible jump -m ping
ansible rke2_servers -m ping
ansible rke2_agents -m ping
```

### 5. Deploy the Cluster

Deploy the entire cluster with a single command:

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

This will execute all playbooks in sequence:
1. Jump host setup
2. Network and firewall configuration
3. RKE2 server installation
4. RKE2 agent installation
5. MetalLB installation and configuration
6. Optional add-ons installation (if enabled)
7. Final verification

### Individual Component Deployment

You can also deploy individual components:

```bash
# Deploy jump host only
ansible-playbook playbooks/jump-host-setup.yml

# Configure network and firewall
ansible-playbook playbooks/network-firewall-setup.yml

# Deploy RKE2 servers
ansible-playbook playbooks/rke2-server-setup.yml

# Deploy RKE2 agents
ansible-playbook playbooks/rke2-agent-setup.yml

# Deploy MetalLB
ansible-playbook playbooks/metallb-setup.yml

# Deploy add-ons (if enabled in variables)
ansible-playbook playbooks/add-ons-setup.yml
```

## Post-Deployment

### Access the Cluster

1. SSH to the jump host:
```bash
ssh ubuntu@<jump-host-ip>
```

2. Copy the kubeconfig from the first RKE2 server:
```bash
sudo /opt/scripts/kube-config.sh
```

3. Verify cluster access:
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Configure kubectl on Local Machine

Copy the kubeconfig from the jump host to your local machine:

```bash
# From jump host
scp ubuntu@<jump-host-ip>:~/.kube/config ~/.kube/rke2-config

# On local machine
export KUBECONFIG=~/.kube/rke2-config
kubectl get nodes
```

### Test MetalLB

Deploy a test application to verify MetalLB is working:

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check the service
kubectl get svc nginx

# Access the application
curl http://<EXTERNAL-IP>
```

## Add-ons Configuration

### Harbor (Container Registry)

Enable Harbor installation in `group_vars/all.yml`:

```yaml
install_harbor: true
harbor_version: "v2.10.0"
```

After installation, Harbor will be available via NodePort. Configure Ingress for external access.

### Longhorn (Storage)

Enable Longhorn installation in `group_vars/all.yml`:

```yaml
install_longhorn: true
longhorn_version: "v1.6.0"
```

Longhorn will be installed as the default storage class. Verify storage class:

```bash
kubectl get storageclass
```

### Velero (Backup)

Enable Velero installation in `group_vars/all.yml`:

```yaml
install_velero: true
velero_version: "v1.13.0"
```

You'll need to configure backup storage credentials in `/tmp/velero-credentials.txt`:

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

### Gitea (Git Hosting)

Enable Gitea installation in `group_vars/all.yml`:

```yaml
install_gitea: true
gitea_version: "v1.21.0"
```

Gitea will be available via NodePort. Configure Ingress for external access.

## RHEL 9 Specific Configuration

### Firewalld Configuration

The playbooks use firewalld instead of UFW for RHEL 9. Firewall rules are automatically configured for:

- SSH (22/tcp)
- Kubernetes API (6443/tcp)
- Flannel VXLAN (8472/udp)
- Kubelet API (10250/tcp)
- HTTP/HTTPS (80/tcp, 443/tcp)
- NodePort services (30000-32767/tcp)
- BGP (179/tcp) if using BGP mode

### SELinux Considerations

RHEL 9 uses SELinux in enforcing mode by default. The playbooks handle SELinux contexts for container runtime and Kubernetes components.

### Local Repository Setup

The airgap bundle includes a local RPM repository that's automatically configured on all nodes. This ensures package installation without internet access.

## Troubleshooting

### Common Issues

#### Airgap Bundle Installation

```bash
# Check if airgap bundle is extracted
ls -la /opt/rhel9-airgap-master/

# Verify local repository setup
dnf repolist
dnf list available
```

#### RKE2 Installation Issues

```bash
# Check RKE2 service status
sudo systemctl status rke2-server  # for servers
sudo systemctl status rke2-agent   # for agents

# Check RKE2 logs
sudo journalctl -u rke2-server -f
sudo journalctl -u rke2-agent -f

# Verify RKE2 binaries
ls -la /usr/local/bin/rke2
/usr/local/bin/rke2 --version
```

#### Container Image Loading

```bash
# Check if images are loaded
ctr -n k8s.io images ls

# Load images manually if needed
ctr -n k8s.io images import /opt/rke2-airgap/images/rke2-images.linux-amd64.tar.gz
```

#### Node Not Ready

```bash
# Check node status
kubectl get nodes -o wide

# Check node logs
ssh ubuntu@<node-ip>
sudo journalctl -u rke2-server -f  # for servers
sudo journalctl -u rke2-agent -f   # for agents

# Check kubelet logs
sudo journalctl -u kubelet -f
```

#### MetalLB Not Working

```bash
# Check MetalLB pods
kubectl get pods -n metallb-system

# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb

# Check IP address pool
kubectl get IPAddressPool -n metallb-system

# Check if images are loaded
ctr -n k8s.io images ls | grep metallb
```

#### Network Issues

```bash
# Check firewall status
sudo firewall-cmd --list-all

# Check network connectivity
ping <node-ip>
telnet <node-ip> 6443

# Check NetworkManager
sudo systemctl status NetworkManager
```

### Logs

#### RKE2 Server Logs
```bash
sudo journalctl -u rke2-server -f
```

#### RKE2 Agent Logs
```bash
sudo journalctl -u rke2-agent -f
```

#### HAProxy Logs
```bash
sudo journalctl -u haproxy -f
```

#### Firewalld Logs
```bash
sudo journalctl -u firewalld -f
```

## Configuration

### MetalLB Modes

#### Layer 2 Mode (Default)
```yaml
metallb_protocol: "layer2"
metallb_ip_range: "192.168.1.200-192.168.1.250"
```

#### BGP Mode
```yaml
metallb_protocol: "bgp"
metallb_ip_range: "192.168.1.200-192.168.1.250"
metallb_bgp_peer_address: "192.168.1.1"
metallb_bgp_peer_asn: 65000
metallb_bgp_local_asn: 65001
metallb_bgp_router_id: "192.168.1.199"
```

### Custom Network Configuration

Modify the network CIDRs in `group_vars/all.yml`:

```yaml
pod_cidr: "10.42.0.0/16"
service_cidr: "10.43.0.0/16"
cluster_domain: "cluster.local"
```

### Firewall Configuration

The firewall rules are automatically configured using firewalld. Modify the ports in `group_vars/all.yml`:

```yaml
firewall_ports:
  - 22/tcp    # SSH
  - 6443/tcp  # Kubernetes API
  - 8472/udp  # Flannel VXLAN
  - 10250/tcp # Kubelet
  - 179/tcp   # BGP (if using BGP mode)
  - 80/tcp    # HTTP
  - 443/tcp   # HTTPS
```

## Management

### Scaling the Cluster

#### Add New Worker Nodes

1. Add the new nodes to `inventory/hosts.ini` under `[rke2_agents]`
2. Transfer airgap bundle to new nodes
3. Run the agent setup playbook:
```bash
ansible-playbook playbooks/rke2-agent-setup.yml --limit agent-new
```

#### Add New Control Plane Nodes

1. Add the new nodes to `inventory/hosts.ini` under `[rke2_servers]`
2. Transfer airgap bundle to new nodes
3. Run the server setup playbook:
```bash
ansible-playbook playbooks/rke2-server-setup.yml --limit server-new
```

### Upgrading RKE2

1. Download new RKE2 version using download scripts
2. Update the `rke2_version` in `group_vars/all.yml`
3. Transfer new airgap bundle to all nodes
4. Run the server setup playbook:
```bash
ansible-playbook playbooks/rke2-server-setup.yml
```
5. Run the agent setup playbook:
```bash
ansible-playbook playbooks/rke2-agent-setup.yml
```

### Monitoring

The jump host includes Node Exporter for basic monitoring:

```bash
# Check node exporter
curl http://<jump-host-ip>:9100/metrics
```

## Security Considerations

1. **SSH Keys**: Use strong SSH keys and restrict access
2. **Firewall**: The playbook configures firewalld rules
3. **SELinux**: SELinux is enforcing by default in RHEL 9
4. **RBAC**: Enable and configure Kubernetes RBAC for production
5. **Secrets**: Use Kubernetes secrets or external secret management
6. **Network Segmentation**: Consider isolating the control plane network
7. **Regular Updates**: Keep RKE2 and Kubernetes components updated
8. **Airgap Security**: Verify airgap bundle integrity before deployment

## Backup and Recovery

### Backup etcd

```bash
# On the first RKE2 server
sudo /var/lib/rancher/rke2/bin/etcdctl snapshot save /tmp/etcd-snapshot.db \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key
```

### Restore etcd

```bash
# On the first RKE2 server
sudo /var/lib/rancher/rke2/bin/etcdctl snapshot restore /tmp/etcd-snapshot.db \
  --cacert=/var/lib/rancher/rke2/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/rke2/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/rke2/server/tls/etcd/server-client.key
```

### Backup Velero

If Velero is installed:

```bash
# Create backup
velero backup create my-backup --include-namespaces '*'

# List backups
velero backup get

# Restore from backup
velero restore create --from-backup my-backup
```

## Download Scripts Reference

### Individual Download Scripts

You can run individual download scripts if needed:

```bash
# Download only RPMs
sudo ./download-rhel-rpms.sh

# Download only RKE2
sudo ./download-rke2-airgap.sh

# Download only add-ons
sudo ./download-add-ons.sh
```

### Download Script Locations

- `scripts/download-rhel-rpms.sh` - RHEL 9 RPM packages
- `scripts/download-rke2-airgap.sh` - RKE2 binaries and images
- `scripts/download-add-ons.sh` - Harbor, Longhorn, Velero, Gitea
- `scripts/download-all-airgap.sh` - Master download script

## Testing and Validation

The deployment includes comprehensive testing tools to validate your RHEL 9 airgap environment:

### Pre-Deployment Testing
- **Playbook Validation**: `./scripts/validate-playbooks.sh`
- **Environment Validation**: `./scripts/validate-environment.sh`
- **Full Test Suite**: `./scripts/run-tests.sh` (Linux) or `.\scripts\run-tests.ps1` (Windows)

### Post-Deployment Testing
- **Deployment Test**: `ansible-playbook playbooks/test-deployment.yml`
- **Cluster Validation**: Access via jump host and run kubectl commands

### Detailed Testing Guide
See `TESTING-GUIDE.md` for comprehensive testing procedures and troubleshooting.

## Contributing

To contribute improvements or fixes:
1. Test changes in a non-production environment
2. Update documentation for any configuration changes
3. Follow existing code style and patterns
4. Run validation scripts before submitting changes
4. Test airgap deployment scenarios

## License

This deployment configuration is provided as-is for educational and production use.

## Support

For issues specific to:
- **RKE2**: https://docs.rke2.io/
- **MetalLB**: https://metallb.universe.tf/
- **Ansible**: https://docs.ansible.com/
- **RHEL 9**: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/

## Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── inventory/
│   ├── hosts.ini              # Host inventory file
│   └── hosts.ini.example      # Example inventory
├── group_vars/
│   ├── all.yml                # Common variables (RHEL 9, airgap, add-ons)
│   ├── jump.yml               # Jump host variables
│   ├── rke2_servers.yml       # Server variables
│   └── rke2_agents.yml        # Agent variables
├── host_vars/                 # Host-specific variables (optional)
├── playbooks/
│   ├── site.yml               # Main deployment playbook
│   ├── jump-host-setup.yml    # Jump host configuration (RHEL 9)
│   ├── network-firewall-setup.yml  # Network configuration (firewalld)
│   ├── rke2-server-setup.yml  # RKE2 server installation (airgap)
│   ├── rke2-agent-setup.yml   # RKE2 agent installation (airgap)
│   ├── metallb-setup.yml      # MetalLB installation
│   └── add-ons-setup.yml      # Add-ons installation
├── scripts/
│   ├── download-rhel-rpms.sh  # RHEL 9 RPM download script
│   ├── download-rke2-airgap.sh    # RKE2 airgap download script
│   ├── download-add-ons.sh    # Add-ons download script
│   └── download-all-airgap.sh     # Master download script
├── roles/                     # Custom roles (optional)
└── configs/                   # Additional configuration files
```

## Version History

- **v2.0** - RHEL 9 airgap support with Harbor, Longhorn, Velero, Gitea
- **v1.0** - Initial release with RKE2 v1.28.10 and MetalLB v0.14.0 (Ubuntu)

