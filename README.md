# helm-charts

Helm charts for self-hosted apps, kept independent of any one cluster.

```
charts/<app>/                      the chart; defaults work on any cluster
clusters/<cluster>/<app>.values.yaml   what differs on that cluster
```

Secrets never go in this repo. Put per-cluster secret values in a
`*.secret.yaml` file (gitignored) and pass it with a second `-f`, or create
the Secret yourself and point the chart at it.

## AFFiNE

`charts/affine` runs the AFFiNE server with database migrations as an init
container. Postgres (with pgvector) and Redis are bundled by default and can
each be switched off in favour of an external service.

Install or upgrade on the Rackspace Spot cluster:

```sh
helm --kube-context the-mill-tee-bot-dev-oidc upgrade --install affine charts/affine \
  --namespace affine --create-namespace \
  -f clusters/rackspace-spot/affine.values.yaml
```

Then reach it and create the admin account:

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
