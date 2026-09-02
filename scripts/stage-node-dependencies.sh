#!/usr/bin/env bash
# Optional helper for manual staging. Ansible performs the same operations.
set -euo pipefail
ROOT="${1:-/opt/airgap}"
source /etc/os-release
[[ "${ID:-}" == rhel && "${VERSION_ID%%.*}" == 9 ]] || { echo 'ERROR: this helper requires RHEL 9.' >&2; exit 1; }
command -v dnf >/dev/null 2>&1 || { echo 'ERROR: dnf is required.' >&2; exit 1; }
[[ $EUID -eq 0 ]] || { echo 'ERROR: run this helper as root.' >&2; exit 1; }
SOURCE="$(readlink -f "$ROOT")"
TARGET="$(readlink -f /opt/airgap)"
mkdir -p /opt/airgap/{rpm,images}
if [[ "$SOURCE" != "$TARGET" ]]; then
  cp -a "$ROOT/rpm/." /opt/airgap/rpm/
  cp -a "$ROOT/images/bootstrap-images.tar" /opt/airgap/images/
fi
if compgen -G '/opt/airgap/rpm/*.rpm' >/dev/null; then
  dnf -y --disablerepo='*' install /opt/airgap/rpm/*.rpm
  modprobe iscsi_tcp
  systemctl enable --now iscsid
else
  echo 'ERROR: no RPMs found in /opt/airgap/rpm.' >&2
  exit 1
fi
