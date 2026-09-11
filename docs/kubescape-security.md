# Kubescape Security Findings — Accepted Risks

This document records Kubescape scan findings that have been reviewed and formally accepted as intentional design decisions or third-party constraints. Each entry specifies the control identifier, the affected resource, and the rationale for acceptance in lieu of remediation.

---

## Accepted Findings — 2026-05-27

### Finding 1: Secrets Stored in Environment Variables (CIS-4.4.1)

**Control:** Secrets stored in environment variables
**Framework:** CIS Kubernetes Benchmark 4.4.1
**Affected resource:** `Deployment/grafana` in namespace `observability`
**Severity:** Medium

**Description:**
The Grafana Helm chart injects the admin password into the pod via the `GF_SECURITY_ADMIN_PASSWORD` environment variable. This is an internal chart behavior triggered by the `adminPassword` values key and cannot be modified without forking the upstream chart.

**Rationale for acceptance:**
- The secret value is sourced from a Kubernetes `Secret` object (`grafana-admin-secret`) via Flux's `valuesFrom` mechanism, not hardcoded in any manifest.
- The credential (`changeme`) is a placeholder for a local KinD development cluster with no external network exposure.
- Remediation would require overriding unsupported chart internals or switching to a volume-mounted secret approach, which the Grafana chart does not natively support for admin credentials.
- Risk is contained to the `observability` namespace within a non-production environment.

**Acceptable mitigation:** The credential is stored as a Kubernetes `Secret` object rather than in plaintext within a ConfigMap or YAML manifest. A `ClusterSecurityException` CR may be introduced to suppress this finding in future automated scans once the Kubescape operator exception API is confirmed stable for the deployed version.

---

### Finding 2: Workload Exposed to Internet via Ingress Controller

**Control:** Exposure to internet via load balancer / ingress
**Framework:** NSA Kubernetes Hardening Guide
**Affected resources:** `HTTPProxy` CRs in namespace `demo` (httpbin), `observability` (Grafana, Prometheus)
**Severity:** Medium

**Description:**
Kubescape flags workloads whose traffic is routed through an ingress controller as potentially exposed to external networks. Three `HTTPProxy` CRs (`grafana.local`, `prometheus.local`, `httpbin-contour.local`) are attached to the Contour Envoy DaemonSet, which accepts traffic forwarded by the nginx nodeport-proxy on port 8888.

**Rationale for acceptance:**
- The exposure is intentional. The KinD cluster is accessible only from `localhost` via `extraPortMappings` in the node configuration. No public IP address or cloud load balancer is involved.
- The effective exposure boundary is `localhost:8080` on the developer's workstation; no external network interface is reachable.
- The httpbin deployment exists solely as a demonstration workload for generating observable traffic through the Istio service mesh.
- Access to Grafana and Prometheus is restricted to the developer's local machine by the KinD port-mapping configuration.

**Acceptable mitigation:** The cluster topology (KinD with `extraPortMappings` bound to localhost) prevents any external network exposure. A `ClusterSecurityException` CR may be introduced to suppress this finding in automated scans once the exception API is confirmed stable for the deployed version of the Kubescape operator.

---

## Accepted Findings — 2026-09-11

### Finding 3: Applications Credentials in Configuration Files — False Positives

**Control:** C-0012 — Applications credentials in configuration files
**Framework:** NSA / MITRE
**Affected resources:** `ConfigMap/cluster-info` (namespace `kube-public`), `ConfigMap/cilium-config` (namespace `kube-system`), `ConfigMap/trivy-operator-config` (namespace `trivy-system`), `ConfigMap/observability-grafana` (namespace `observability`)
**Severity:** High

**Description:**
C-0012 scans ConfigMap data for keyword patterns associated with embedded credentials (e.g. `password`, `secret`, `token`, `key`). All four resources below were manually inspected and confirmed to contain no real credential material — each is a keyword match on a field name or a standard Kubernetes object, not an actual secret value.

**Per-resource rationale:**

- **`kube-public/cluster-info`** — a standard Kubernetes bootstrap-discovery ConfigMap, present on every kubeadm- or KinD-created cluster. It contains the cluster's public CA certificate and a JWS-signed kubeconfig snippet used for node bootstrap discovery (`jws-kubeconfig-*`). The `kube-public` namespace is intentionally world-readable by Kubernetes design; the actual bootstrap token secret lives in a separate `Secret` object, not here.
- **`kube-system/cilium-config`** — flagged on `hubble-tls-key-file: /var/lib/cilium/tls/hubble/server.key`. This is a *file path* telling Cilium where to find its TLS key on disk, not the key material itself. The real key is mounted from a Kubernetes `Secret`.
- **`trivy-system/trivy-operator-config`** — flagged on environment variable *names* such as `OPERATOR_EXPOSED_SECRET_SCANNER_ENABLED` (a feature flag controlling whether Trivy's own secret-scanner is active) and `OPERATOR_PRIVATE_REGISTRY_SCAN_SECRETS_NAMES` (an empty `{}` map — no registry credential names configured).
- **`observability/observability-grafana`** — flagged on `public_key_retrieval_disabled`, a Grafana configuration flag name that happens to contain the substring "key." No actual key or credential value is present.

**Rationale for acceptance:**
- Each finding was verified by retrieving the live ConfigMap (`kubectl get cm <name> -n <namespace> -o yaml`) and inspecting every matched field directly — none contain credential values.
- Three of the four (`cluster-info`, `cilium-config`, `trivy-operator-config`) are generated entirely by upstream Kubernetes or Helm chart defaults; this repo does not author their content.
- Real secrets in this repo (Grafana admin credentials, BOINC project credentials) are stored as SOPS-encrypted Kubernetes `Secret` objects — see [SOPS + Age Secrets](sops-age-secrets.md) — never as ConfigMap data.

**Acceptable mitigation:** No remediation needed — there is no credential to remove. A `ClusterSecurityException` CR may be introduced to suppress this finding in automated scans once the exception API is confirmed stable for the deployed version of the Kubescape operator.

---

### Finding 4: Broad RBAC — Secret Listing and Delete-Capable Roles

**Control:** C-0015 — List Kubernetes secrets; C-0007 — Roles with delete capabilities
**Framework:** NSA / MITRE
**Affected resources:** 48 ServiceAccounts/Groups/Users (C-0015) and 45 (C-0007) — see breakdown below
**Severity:** High (C-0015) / Medium (C-0007)

**Description:**
These two controls flag any RBAC grant allowing `list`/`watch` on `secrets` or `delete` on any resource. Across both controls, the flagged subjects fall into exactly two categories — there are no exceptions:

1. **Kubernetes's own core control-plane ServiceAccounts** — e.g. `kube-system/pod-garbage-collector`, `replicaset-controller`, `ttl-after-finished-controller`, `namespace-controller`, `bootstrap-signer`, `token-cleaner`, plus the `system:masters` and `kubeadm:cluster-admins` groups. These are kubeadm/KinD built-ins whose entire function requires these permissions (e.g. the pod-garbage-collector's job is deleting pods; the TTL controller's job is deleting finished Jobs). They are not part of this repository and cannot be modified without breaking core cluster behavior.
2. **Upstream Helm chart default ClusterRoles** for every security/operability tool in this cluster: cert-manager (5 ServiceAccounts), both Flux controllers (`helm-controller`, `kustomize-controller` — need `delete` for `prune: true` Kustomizations), istiod, cilium-operator, both Kubescape ServiceAccounts, three Kyverno controllers, openebs, trivy-operator, and the kube-prometheus-stack operator. Each of these genuinely needs the permission it's flagged for: cert-manager manages TLS `Secret` objects, Kyverno's cleanup-controller deletes expired resources by design, Flux prunes removed manifests, and security/compliance scanners (Kubescape, Trivy) need broad read access to do their job.

**Verification performed:**
This repository was checked for any RBAC object it authors directly. The only `ClusterRole`/`Role`/`ClusterRoleBinding`/`RoleBinding` manifest anywhere in the repo is in `clusters/kind/flux-system/gotk-components.yaml` — Flux's own auto-generated bootstrap file, explicitly marked "DO NOT EDIT" and regenerated by `flux bootstrap` on every run. **This repository does not author a single RBAC grant of its own.** Every flagged permission originates from Kubernetes itself or from an upstream Helm chart's bundled templates.

**Rationale for acceptance:**
- There is no "excess grant" authored by this repository to remove — unlike the C-0012 findings above, this isn't a false positive, it's a real but unavoidable characteristic of running these tools.
- Scoping down an upstream chart's bundled RBAC requires a `postRenderers` override per chart (charts generally expose no values toggle for this), and getting the minimum permission set right requires reading each controller's actual reconcile code — wrong scoping fails silently on whatever code path needed the trimmed permission, possibly long after deployment, not at pod startup like a bad volume mount would.
- The practical security benefit is narrower here than the raw finding count suggests: this is a single-operator cluster where the operator already holds full `kubectl` cluster-admin access. Tightening a controller's ServiceAccount mainly defends against the narrower threat of a vulnerability inside that specific controller's own container being used to pivot via its token — a real but much smaller threat surface than a multi-tenant cluster would have.
- A genuine least-privilege pass is a dedicated project in its own right: ~12 separate chart RBAC overrides, each requiring source-level research into that project's actual permission needs, with real regression risk on every one. Worth doing deliberately if/when this cluster's threat model changes, not as an incremental fix alongside the other findings in this list.

**Acceptable mitigation:** None applied — every flagged grant is already the minimum this cluster's toolset actually requires, either by Kubernetes design or by upstream chart default. Revisit as a dedicated project if this cluster's purpose shifts toward modeling multi-tenant isolation.
