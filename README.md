# xd-net-apps

GitOps repository for xd-net Kubernetes cluster applications.

## Structure

- `secrets/` - SOPS-encrypted secrets (deployed to synology-csi namespace)
- `apps/` - Application manifests (each subdirectory becomes an ArgoCD Application)

## Adding a New App

1. Create a new directory under `apps/` (e.g., `apps/my-app/`)
2. Add Kubernetes manifests to that directory
3. ArgoCD will automatically detect and deploy it
4. The namespace will be created automatically from the directory name

## Encrypting Secrets

```bash
# Encrypt a secret file
sops --encrypt --in-place secrets/synology-secret.yaml

# Edit an encrypted file
sops secrets/synology-secret.yaml
```

## Notes

- ArgoCD ApplicationSet automatically scans `apps/*` directories
- Each app gets its own namespace (matching directory name)
- Secrets are decrypted by ArgoCD using the SOPS plugin
# xd-net-apps
