#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-/opt/airgap}"
source /etc/os-release
[[ "${ID:-}" == rhel && "${VERSION_ID%%.*}" == 9 ]] || { echo 'ERROR: bundle validation requires RHEL 9.' >&2; exit 1; }
fail=0
req() { [[ -e "$ROOT/$1" ]] || { echo "MISSING: $ROOT/$1"; fail=1; }; }
req ansible.cfg
req inventory/hosts.ini
req group_vars/all.yml
req playbooks/site.yml
req roles
req scripts/prep-offline.sh
req artifacts/rke2-install.sh
req artifacts/rke2.linux-amd64.tar.gz
req artifacts/rke2-images.linux-amd64.tar.zst
req artifacts/sha256sum-amd64.txt
req artifacts/rke2-selinux-0.23-1.el9.noarch.rpm
req artifacts/helm-linux-amd64.tar.gz
req artifacts/kubectl
req artifacts/k9s_Linux_amd64.tar.gz
req charts/metallb-0.16.1.tgz
req charts/longhorn-1.12.1.tgz
req charts/harbor-1.19.2.tgz
req charts/gitea-12.7.0.tgz
req images/bootstrap-images.tar
req images/images.txt
req rpm
req collections
req checksums/SHA256SUMS
if grep -Eq '^trust_local_ca:[[:space:]]*true([[:space:]]|$)' "$ROOT/group_vars/all.yml" 2>/dev/null; then req certs/ca.crt; fi
shopt -s nullglob
charts=("$ROOT"/charts/*.tgz); rpms=("$ROOT"/rpm/*.rpm)
(( ${#charts[@]} == 4 )) || { echo "ERROR: expected exactly 4 Helm charts in $ROOT/charts, found ${#charts[@]}"; fail=1; }
(( ${#rpms[@]} > 0 )) || { echo "MISSING: no RPMs in $ROOT/rpm"; fail=1; }
for excluded_role in istio garage velero k8sgpt minio nginx_ingress; do
  [[ ! -e "$ROOT/roles/$excluded_role" ]] || { echo "UNEXPECTED: excluded role $ROOT/roles/$excluded_role"; fail=1; }
done
if [[ -s "$ROOT/images/images.txt" ]] && grep -Eiq '(^|[/.-])(istio|garage|velero|k8sgpt|minio|ingress-nginx)([/.:_-]|$)' "$ROOT/images/images.txt"; then
  echo "UNEXPECTED: excluded component found in $ROOT/images/images.txt"
  fail=1
fi
if ! compgen -G "$ROOT/rpm/rke2-selinux-*.rpm" >/dev/null; then echo "MISSING: rke2-selinux RPM in $ROOT/rpm"; fail=1; fi
if [[ -f "$ROOT/checksums/SHA256SUMS" ]]; then (cd "$ROOT" && sha256sum -c checksums/SHA256SUMS) || fail=1; fi
if [[ -s "$ROOT/images/images.txt" && -f "$ROOT/images/bootstrap-images.tar" ]]; then
  tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  if tar -xOf "$ROOT/images/bootstrap-images.tar" manifest.json > "$tmpdir/manifest.json" 2>/dev/null; then
    python3 - "$ROOT/images/images.txt" "$tmpdir/manifest.json" <<'PY' || fail=1
import json,sys
wanted=[x.strip() for x in open(sys.argv[1]) if x.strip()]
manifest=json.load(open(sys.argv[2]))
tags={tag for item in manifest for tag in (item.get('RepoTags') or [])}
missing=[x for x in wanted if x not in tags]
if missing:
    print('MISSING FROM bootstrap-images.tar:'); print('\n'.join(missing)); sys.exit(1)
print(f'Bootstrap archive contains all {len(wanted)} manifest images.')
PY
  else echo "ERROR: bootstrap-images.tar has no manifest.json"; fail=1; fi
fi
echo "Image manifest: $(wc -l < "$ROOT/images/images.txt") images"
echo "RPMs staged: ${#rpms[@]}"
echo "Charts staged: ${#charts[@]}"
if (( fail )); then echo "OFFLINE BUNDLE VALIDATION: FAILED"; exit 1; fi
echo "OFFLINE BUNDLE VALIDATION: PASSED"
