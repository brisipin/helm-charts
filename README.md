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
present), or create the Secret yourself and point the chart at it.

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
