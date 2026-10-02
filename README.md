# helm-charts

Helm charts for self-hosted apps, kept independent of any one cluster.

```
helmfile.yaml.gotmpl                   every release, per cluster
charts/<app>/                          the chart; defaults work on any cluster
clusters/<cluster>/<app>.values.yaml   what differs on that cluster
```

## Deploying

[helmfile](https://helmfile.readthedocs.io) installs everything a cluster
should run. Each cluster is a helmfile environment bound to a kube context,
and `-e` is required:

```sh
helmfile -e rackspace-spot diff    # what would change
helmfile -e rackspace-spot apply   # make it so
```

Needs `helm`, `helmfile`, and the `helm-diff` plugin.

Secrets never go in this repo. Put per-cluster secret values in
`clusters/<cluster>/<app>.secret.yaml` (gitignored; helmfile picks it up when
present), or create the Secret yourself and point the chart at it. A
committed `<app>.secret.example.yaml` next to it shows which keys that
cluster needs and where the real values live.

## CI

Every pull request and push to `main` runs three checks
(`.github/workflows/lint.yml`):

| Check | What it catches |
|---|---|
| `lint` | `helm lint` failures, templates that don't render, manifests that don't match the Kubernetes schema (kubeconform), and committed `*.secret.yaml` files |
| `chart-version` | A chart whose files changed without a version bump (pull requests only) |
| `server-dry-run` | Anything only the real API server knows: admission rejections, immutable-field changes, missing storage classes. Runs `helm upgrade --install --dry-run=server` for each release on the Rackspace Spot cluster; nothing is persisted |

`server-dry-run` needs a kubeconfig in the `KUBE_CONFIG_RACKSPACE_SPOT`
repo secret and skips with a warning without it (fork pull requests never
get it). One-time setup, run by hand with your own cluster login:

```sh
kubectl apply -f clusters/rackspace-spot/ci-access.yaml

TOKEN=$(kubectl get secret github-actions-helm-charts-token -n affine -o jsonpath='{.data.token}' | base64 -d)
SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
cat <<EOF | gh secret set KUBE_CONFIG_RACKSPACE_SPOT --repo brisipin/helm-charts
apiVersion: v1
kind: Config
current-context: github-actions-helm-charts
clusters:
  - name: rackspace-spot
    cluster:
      server: ${SERVER}
      certificate-authority-data: ${CA}
contexts:
  - name: github-actions-helm-charts
    context:
      cluster: rackspace-spot
      namespace: affine
      user: github-actions-helm-charts
users:
  - name: github-actions-helm-charts
    user:
      token: ${TOKEN}
EOF
```

A dry run needs the same permissions as the real request, so that account
can create and update the charts' resource kinds in the `affine` namespace
and read its Secrets. It cannot delete, and has no access elsewhere.

## AFFiNE

`charts/affine` runs the AFFiNE server with database migrations as an init
container. Postgres (with pgvector) and Redis are bundled by default and can
each be switched off in favour of an external service.

After `helmfile -e rackspace-spot apply`, reach it and create the admin
account:

```sh
kubectl -n affine rollout status deploy/affine
kubectl -n affine port-forward svc/affine 3010:3010
# open http://localhost:3010/admin
```

Common switches (see `charts/affine/values.yaml` for all of them):

| Goal | Values |
|---|---|
| Public hostname | `server.externalUrl`, `ingress.enabled`, `ingress.host` |
| Managed Postgres | `postgres.enabled=false`, `externalDatabase.url` |
| Files in S3 | `storage.type=s3`, `storage.s3.*` |
| Invite emails | `mailer.enabled=true`, `mailer.*` |
| Close sign-ups | `config.auth.allowSignup=false` |

The chart generates the session signing key and the bundled Postgres password
on first install and reads them back from the cluster on upgrade. Tools that
render without cluster access (`helm template`, Argo CD) would regenerate
them each time; with those, create the Secret yourself and set
`secret.existingSecret`.

The uploaded-files volume is kept on `helm uninstall`. The bundled Postgres
volume is too (StatefulSet claims are never deleted by Helm). Delete the
claims by hand to start clean.
