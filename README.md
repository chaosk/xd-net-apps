# xd-net-apps

GitOps manifests for workloads on the **[xd-net](https://github.com/chaosk/xd-net)** Kubernetes cluster. This
repository is wired from xd-net via Argo CD (Terraform in [`xd-net/apps`](https://github.com/chaosk/xd-net/tree/main/apps)
creates the `Application` and `ApplicationSet`).

## Layout

| Path | Role |
|------|------|
| `apps/<name>/` | Plain Kubernetes YAML; each directory becomes one Argo CD Application and (by convention) a namespace named `<name>`. |
| `apps/argocd-image-updater/` | Argo CD Image Updater controller (`argocd` namespace). Opt-in apps are listed in `image-updater.yaml`. |
| `secrets/` | SOPS-encrypted YAML consumed by the **platform-secrets** Application. |

Cluster install order in [xd-net](https://github.com/chaosk/xd-net): `infra/` → `app-manifests/` → `apps/`.
This repo is only the Git source for Argo CD after `apps/` has been applied.

## Argo CD behavior

- **Application `platform-secrets`** syncs the `secrets/` path using the
  **SOPS** config-management plugin. Set `metadata.namespace` on each
  resource to the namespace where it should live.
- **ApplicationSet `apps`** scans `apps/*` and deploys each subdirectory.
  Automated sync uses `CreateNamespace=true`, so the namespace matches the
  directory name unless you override in manifests.
- Optional **image auto-updates** — add the app to `apps/argocd-image-updater/image-updater.yaml`
  (see `apps/argocd-image-updater/README.md`).

## Add an application

1. Create `apps/<app>/` (for example `apps/my-service/`).
2. Add manifests (`Deployment`, `Service`, `Namespace`, and so on).
3. Commit and push; Argo CD picks up the new path and creates an Application
   named `<app>`.

Optional: add `apps/<app>/kustomization.yaml` if you prefer Kustomize layout;
the Application still uses directory sync from plain Git.

## SOPS and secrets

See `secrets/README.md` for directory-specific notes.

## Git hooks

Commits must be [GPG-signed](https://git-scm.com/book/en/v2/Git-Tools-Signing-Your-Work). [pre-commit](https://pre-commit.com/) runs [require-signed-commits](https://github.com/pre-commit-garage/pre-commit-metadata-hooks) on `git push` and rejects any commit missing a `gpgsig` header.

One-time setup:

```bash
brew install pre-commit   # or: pip install pre-commit
pre-commit install
git config commit.gpgsign true
```
