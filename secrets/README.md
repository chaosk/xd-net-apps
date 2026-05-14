# secrets

YAML in this directory is synced by Argo CD **platform-secrets** (see
**xd-net** `apps/argocd-gitops.tf`). Files should be **SOPS-encrypted**
before you push.

## Adding new secrets

1. Add a normal Kubernetes `Secret` manifest under `secrets/<name>.yaml` with the right
   `metadata.name` and `metadata.namespace` for the app (see the table below for
   conventions).
2. Put values in `stringData` (or `data`) as usual. **Only lines you mark are
   encrypted:** add a **trailing** inline comment `# sops:encrypt` on each scalar that
   should become ciphertext (see [`.sops.yaml`](../.sops.yaml):
   `encrypted_comment_regex: sops:encrypt`). Anything without that marker stays
   plaintext in the decrypted file (useful for non-secrets like hostnames or usernames
   you want readable in-cluster after sync).

3. Encrypt before you push (never commit plaintext credentials to a shared remote):

   ```bash
   sops --encrypt --in-place secrets/<name>.yaml
   ```

   Alternatively, create and edit in one step: `sops secrets/<name>.yaml` (SOPS writes
   an encrypted file from the start).

4. If this is a new app or namespace, ensure **platform-secrets** in **xd-net** still
   includes the path (or pattern) so Argo CD syncs the file.

## Editing existing ones

1. Decrypt, edit, and re-encrypt in your editor:

   ```bash
   sops secrets/<name>.yaml
   ```

   You need the **age** private key that matches the recipient in `.sops.yaml` (e.g.
   `SOPS_AGE_KEY_FILE` or `age` keyring on your machine).

2. Save and commit the updated ciphertext only; CI and peers must not see plaintext
   diffs on lines that carry `# sops:encrypt`.

### Migrating files that used `encrypted_regex`

Older commits may still have `encrypted_regex: ^(data|stringData)$` inside the file’s
`sops:` metadata (whole `stringData` / `data` maps were encrypted). To move to comment
markers:

1. `sops -d secrets/<name>.yaml > /tmp/<name>.yaml` (or `sops secrets/<name>.yaml` and
   save as plaintext elsewhere briefly).
2. Edit plaintext: add ` # sops:encrypt` on each value that should stay encrypted; remove
   the old `sops:` block if present (a decrypt step already strips it).
3. Replace `secrets/<name>.yaml` with that YAML and run
   `sops --encrypt --in-place secrets/<name>.yaml`.

Until you do this, existing files still decrypt and work; new encrypts follow
`.sops.yaml` only when the file is re-encrypted without the old metadata.

## Apps that expect secrets here

| Encrypted file (example name) | `metadata.namespace` | Purpose |
|------------------------------|----------------------|---------|
| `authentik-secret-key.yaml` | `authentik` | Authentik app signing key (`authentik-secret-key`, key `secret_key`). |
| `authentik-db.yaml` | `authentik` | CNPG bootstrap + Authentik DB password (`authentik-db`, keys `username`, `password`). |
| `authentik-geoip.yaml` | `authentik` | MaxMind GeoLite2 updater (`authentik-geoip`, keys `account_id`, `license_key`). See [GeoIP](https://docs.goauthentik.io/sys-mgmt/ops/geoip/). |
| `immich-db.yaml` | `immich` | CNPG bootstrap + Immich connection (`immich-db`, keys `username`, `password`, `host`, `user`, `dbname`). |
