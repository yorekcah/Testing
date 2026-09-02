# Changelog

## 3.2.0
- Reduced the deployment stack to RKE2 with packaged Traefik, MetalLB, Longhorn, Harbor, Gitea, and K9s.
- Updated RKE2 to v1.36.4+rke2r1 and retained current stable pins for the remaining stack.
- Removed Istio, Garage, Velero, K8sGPT, and all related charts, images, variables, checks, and credentials.
- Added RKE2 SELinux RPM staging for RHEL 9 air-gapped nodes.
- Added strict Helm dependency-build failure handling.
- Reworked connected-side image discovery to render charts with deployment-aligned values.
- Added bootstrap image archive completeness validation.
- Added Harbor readiness, `library` project validation/creation, seed push validation, and pull-back validation.
- Added offline preflight checks.
- Fixed bundle validator regex and required-RPM checks.
