#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-/opt/airgap}"
source /etc/os-release
[[ "${ID:-}" == rhel && "${VERSION_ID%%.*}" == 9 ]] || { echo 'ERROR: this installer requires RHEL 9.' >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo 'ERROR: run this installer as root.' >&2; exit 1; }
command -v ansible-galaxy >/dev/null 2>&1 || { echo 'ERROR: ansible-galaxy is required.' >&2; exit 1; }
mkdir -p /usr/share/ansible/collections
shopt -s nullglob
files=("$ROOT/collections"/ansible_posix-*.tar.gz "$ROOT/collections"/ansible-posix-*.tar.gz)
if (( ${#files[@]} == 0 )); then
  echo "No ansible.posix collection archive found under $ROOT/collections" >&2
  exit 1
fi
ansible-galaxy collection install "${files[0]}" -p /usr/share/ansible/collections --force
ansible-galaxy collection list | grep -E '^ansible\.posix\s' || true
