# Ansible Package 3.2 — RHEL 9 / RKE2 Air-Gap Deployment

This is a self-contained **RHEL 9 connected-side build -> compressed offline transfer -> disconnected RHEL 9 deployment** package. Run all shell scripts on RHEL 9.

The package is limited to RKE2 with packaged Traefik, MetalLB, Longhorn, Harbor, Gitea, and K9s. Stable versions verified on September 2, 2026 are pinned for reproducible air-gap builds:

| Component | Version |
|---|---|
| RKE2 | `v1.36.4+rke2r1` |
| Traefik | Packaged with RKE2 |
| MetalLB | `0.16.1` |
| Longhorn | `1.12.1` |
| Harbor chart / app | `1.19.2` / `v2.15.2` |
| Gitea chart / app | `12.7.0` / `1.27.3` |
| K9s | `v0.51.0` |
| Helm | `v4.2.4` |

## What 3.2 fixes

- Stages the RKE2 SELinux policy RPM required on SELinux-enabled RHEL 9 nodes.
- Downloads and verifies the RKE2 air-gap image archive, binary archive, checksum file, and offline installer.
- Builds Helm charts with dependencies and fails if dependency resolution fails.
- Renders charts with deployment-aligned values to discover application images.
- Pulls every discovered application image and saves them to `images/bootstrap-images.tar`.
- Validates that every image in `images/images.txt` is actually present in the bootstrap archive.
- Installs the bootstrap image archive into RKE2's native image directory and explicitly imports it after containerd starts.
- Adds Harbor readiness gates, library-project creation/verification, image push validation, and pull-back validation.
- Disables external registry fallback for the air-gapped RKE2 nodes.
- Adds RHEL 9/amd64/default-route/swap/Longhorn preflight checks.
- Fixes the bundle validation regex and makes required artifacts/RPMs hard failures.

RKE2's official air-gap documentation requires the SELinux RPM before RKE2 on SELinux-enabled air-gapped nodes and supports importing image archives through `/var/lib/rancher/rke2/agent/images/`. urlRKE2 air-gap documentationhttps://docs.rke2.io/install/airgap

## 1. Connected staging machine

Use a **RHEL 9 amd64** staging machine with access to:

- RHEL 9 BaseOS/AppStream repositories
- GitHub
- Helm chart repositories
- Docker Hub / Quay / registry.k8s.io / other registries required by the charts

Install the connected-side prerequisites:

```bash
sudo dnf install -y dnf-plugins-core curl tar gzip zstd python3
# Install Docker or Podman and Ansible/ansible-core according to your staging standard.
```

Run with a new or empty destination directory. The builder refuses non-empty destinations so removed components cannot survive from an older bundle:

```bash
chmod +x scripts/prep-offline.sh
./scripts/prep-offline.sh /opt/airgap-bundle
```

The script copies the complete Ansible package into the output directory and downloads/stages the RKE2 artifacts, `rke2-selinux`, Helm charts and dependencies, application images, Ansible collection, and RHEL RPM dependency closure.

Then validate:

```bash
./scripts/validate-bundle.sh /opt/airgap-bundle
```

**Do not transfer the bundle if validation fails.**

Create the transfer archive on RHEL 9 so Linux modes and executable bits are retained:

```bash
sudo tar -C /opt/airgap-bundle -czf /opt/ansible-package-3.2-rhel9.tar.gz .
```

## 2. Transfer into the closed network

Transfer `ansible-package-3.2-rhel9.tar.gz` to the RHEL 9 Ansible controller/jump host, then extract the complete package:

```bash
sudo mkdir -p /opt/airgap
sudo tar -C /opt/airgap -xzf ansible-package-3.2-rhel9.tar.gz
sudo chmod +x /opt/airgap/scripts/*.sh
cd /opt/airgap
```

The controller should have:

```text
/opt/airgap/
├── ansible.cfg
├── inventory/
├── group_vars/
├── host_vars/
├── playbooks/
├── roles/
├── scripts/
├── artifacts/
├── charts/
├── collections/
├── images/
├── rpm/
├── certs/
├── manifests/
└── checksums/
```

Install the bundled Ansible collection offline:

```bash
sudo ./scripts/install-ansible-collections.sh /opt/airgap
```

## 3. Configure inventory and secrets

Edit:

```text
inventory/hosts.ini
host_vars/*.yml
group_vars/all.yml
```

Create an encrypted vault from:

```text
group_vars/vault.yml.example
```

At minimum, set the RKE2 token and Harbor/Gitea credentials in the vault.

## 4. Deploy

Run from the package root:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/site.yml --ask-vault-pass
```

The order is:

1. Bundle validation
2. Common RHEL 9 prerequisites and offline RPM installation
3. Air-gap node preflight
4. RKE2 servers
5. RKE2 agents
6. MetalLB
7. Longhorn
8. Packaged Traefik ingress controller
9. Harbor bootstrap and registry validation
10. Gitea and K9s

## 5. Important air-gap behavior

The RKE2 configuration uses:

```yaml
disable-default-registry-endpoint: true
embedded-registry: true
```

The first setting prevents configured registry mirrors from falling back to the public registry. The second enables RKE2's distributed image mirror. RKE2 requires TCP 5001 and 9345 between nodes when the embedded mirror is enabled. urlRKE2 embedded registry mirror documentationhttps://docs.rke2.io/install/registry_mirror

The deployment also preloads application images into containerd so Harbor can be bootstrapped without needing to pull Harbor's own images from the Internet.

## 6. Harbor bootstrap

Harbor is intentionally brought up before the remaining applications that depend on the private registry.

The Harbor role:

- waits for Harbor components to become ready;
- verifies Harbor API health;
- creates the `library` project if required;
- makes the `library` project available for unauthenticated Kubernetes image pulls;
- pushes the staged application images into Harbor;
- verifies that a Harbor image can be pulled back through containerd.

For production, use HTTPS and an organization-issued CA instead of the HTTP bootstrap configuration.

## 7. Traefik ingress

RKE2 v1.36.4 deploys Traefik by default on new clusters. This package explicitly selects the packaged Traefik controller, configures its MetalLB address with `traefik_vip`, and uses the `traefik` IngressClass for Gitea. Traefik images are supplied by the official RKE2 air-gap image archive, so no separate ingress chart or image download is required.

## 8. Verification after deployment

On the jump host:

```bash
export KUBECONFIG=$HOME/.kube/config
kubectl get nodes -o wide
kubectl get pods -A
kubectl get svc -A
```

On the first RKE2 server, run the read-only review script from the transferred package:

```bash
sudo /opt/airgap/scripts/review-rke2-server.sh | tee /tmp/rke2-server-review.log
```

The script does not read the RKE2 configuration, cluster token, or vault files. It reports RHEL/SELinux RPM state, RKE2 service status and recent logs, cluster nodes and pods, Traefik, services, ingresses, Longhorn storage, and containerd images. Review the collected service logs before sharing them.

Test that a normal Kubernetes image reference resolves without Internet access:

```bash
sudo /var/lib/rancher/rke2/bin/crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock pull docker.io/library/busybox:1.36
```

For a strict air-gap acceptance test, disconnect/block Internet egress and repeat the image pull using an image that exists in Harbor. The pull must succeed without reaching Docker Hub.

## 9. Security note

The embedded RKE2 registry mirror assumes equal trust between cluster members. RKE2 documents that image tags can be poisoned if a node is allowed to introduce a malicious image into its containerd store. For high-integrity environments, prefer image digests and consider whether the embedded mirror fits the security model. citeturn0search1

## 10. What is and is not verified

This package has been **statically validated** for shell syntax and YAML parsing in this environment. A live RHEL 9/RKE2 six-node cluster is not available here, so the package is not honestly represented as having passed a live end-to-end deployment test.

The connected-side `prep-offline.sh` is intentionally the final authority for downloading the exact artifacts/images and building the transferable bundle. It fails instead of silently producing an incomplete air-gap package.
