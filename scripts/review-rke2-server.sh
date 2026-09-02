#!/usr/bin/env bash
set -uo pipefail
source /etc/os-release
[[ "${ID:-}" == rhel && "${VERSION_ID%%.*}" == 9 ]] || { echo 'ERROR: this review script requires RHEL 9.' >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo 'ERROR: run this review script as root.' >&2; exit 1; }

KUBECTL=/var/lib/rancher/rke2/bin/kubectl
KUBECONFIG=/etc/rancher/rke2/rke2.yaml
CTR=/var/lib/rancher/rke2/bin/ctr
CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock

section() { printf '\n===== %s =====\n' "$1"; }
run() { printf '+ '; printf '%q ' "$@"; printf '\n'; "$@" || true; }

section 'RHEL and SELinux'
run cat /etc/redhat-release
run getenforce
run rpm -q rke2-selinux container-selinux selinux-policy-targeted

section 'RKE2 service'
run systemctl is-enabled rke2-server
run systemctl is-active rke2-server
run systemctl --no-pager --full status rke2-server

section 'Recent RKE2 logs'
run journalctl -u rke2-server -n 100 --no-pager

if [[ -x "$KUBECTL" && -r "$KUBECONFIG" ]]; then
  section 'Cluster nodes'
  run "$KUBECTL" --kubeconfig "$KUBECONFIG" get nodes -o wide

  section 'Cluster pods'
  run "$KUBECTL" --kubeconfig "$KUBECONFIG" get pods -A -o wide

  section 'Traefik and services'
  run "$KUBECTL" --kubeconfig "$KUBECONFIG" get daemonset rke2-traefik -n kube-system
  run "$KUBECTL" --kubeconfig "$KUBECONFIG" get service -A
  run "$KUBECTL" --kubeconfig "$KUBECONFIG" get ingress -A

  section 'Storage'
  run "$KUBECTL" --kubeconfig "$KUBECONFIG" get storageclass
  run "$KUBECTL" --kubeconfig "$KUBECONFIG" get pvc -A
else
  echo "RKE2 kubectl or server kubeconfig is unavailable; cluster checks were skipped." >&2
fi

if [[ -x "$CTR" && -S "$CONTAINERD_ADDRESS" ]]; then
  section 'Containerd images'
  run "$CTR" --address "$CONTAINERD_ADDRESS" --namespace k8s.io images list
fi
