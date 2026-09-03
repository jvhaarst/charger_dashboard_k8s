# charger_dashboard_k8s

Helm chart for the **EV charge point availability dashboard**, published as a Helm
repository via GitHub Pages so it can be added as a chart repository in Rancher.

- **Live site:** https://laadpaal.vanhaarst.net
- **Image:** `ghcr.io/jvhaarst/charger_dashboard` (built from
  [jvhaarst/charger_dashboard](https://github.com/jvhaarst/charger_dashboard))

The dashboard reads NDW DOT-NL, the Dutch national access point, and keeps its own
history — which is why this chart has a volume and zeildashboard's does not.

## How updates flow

```
 dashboard code change ───▶ new image  ghcr.io/jvhaarst/charger_dashboard:0.1.N
                                       │
                                       ▼
                 Renovate (this repo) bumps Chart.yaml appVersion
                                       │
                                       ▼
              helm-release workflow publishes a new chart version
                                       │
                                       ▼
                       Rancher sees the new chart version
```

- `renovate.json` watches the `ghcr.io/jvhaarst/charger_dashboard` tag in
  `charger-dashboard/Chart.yaml` (`appVersion`) via the Docker datasource and
  opens a PR when a newer image is published.
- Merging to `main` (or any change under `charger-dashboard/`) triggers
  `.github/workflows/helm-release.yaml`, which packages the chart (version
  auto-set to `<base>.<run_number>`) and publishes it + an updated `index.yaml`
  to GitHub Pages.

## Use it

Add the repo in Rancher (Apps → Repositories) or with the Helm CLI:

```bash
helm repo add charger-dashboard https://jvhaarst.github.io/charger_dashboard_k8s
helm repo update
helm upgrade --install laadpaal charger-dashboard/charger-dashboard \
  --namespace charger-dashboard --create-namespace
```

## Configuration

| Value | Default | Notes |
|-------|---------|-------|
| `image.repository` | `ghcr.io/jvhaarst/charger_dashboard` | |
| `image.tag` | `""` | Empty → uses the chart `appVersion` (Renovate-managed). |
| `ingress.host` | `laadpaal.vanhaarst.net` | Needs a public DNS record for Let's Encrypt. |
| `ingress.clusterIssuer` | `letsencrypt-production` | cert-manager ClusterIssuer. |
| `config.bbox` | Business & Science Park | `minLon,minLat,maxLon,maxLat`; the API caps a box at 1.0 degree². |
| `config.pollSeconds` | `300` | Seconds between recorded observations. |
| `config.cacheSeconds` | `60` | Seconds a fetched response counts as fresh. |
| `config.mergeMetres` | `10` | Same-operator stations closer than this show as one site; `0` disables. |
| `config.retainDays` | `365` | History retention, both tables; `0` keeps everything. ~50MB per year for the default bbox. |
| `config.ocpiSeconds` | `3600` | How often to refresh which sockets are *dead*, from NDW's bulk OCPI file (~18MB per refresh). `0` disables it. |
| `persistence.enabled` | `true` | Without it the history dies with the pod. |
| `persistence.storageClass` | `longhorn` | Set explicitly — the cluster has more than one class marked default. |
| `persistence.size` | `1Gi` | |
| `replicaCount` | `1` | Not tunable in practice: one poller thread, one SQLite writer, RWO volume. |

## Notes on shape

- **`strategy: Recreate`.** The volume is ReadWriteOnce, so a rolling update
  would deadlock waiting for the old pod to release it.
- **The PVC is annotated `helm.sh/resource-policy: keep`**, so uninstalling the
  release does not delete accumulated history.
- **Liveness hits `/livez`, readiness hits `/healthz`.** `/healthz` reads the
  history database; `/livez` touches nothing. Pointing liveness at storage
  turned a longhorn stall into a restart loop — 18 kills in four hours, exit
  code 0, nothing in the app's own logs. Readiness may still fail during a
  stall, which correctly takes the pod out of the Service without killing it.
- **Probe budgets are deliberately generous** (`probes.timeoutSeconds: 5`,
  `probes.failureThreshold: 5`): a 4KiB fsync on this hardware has been seen
  taking 14 seconds mid-rebuild.

## Local development

```bash
helm lint charger-dashboard
helm template laadpaal charger-dashboard --namespace charger-dashboard
```
