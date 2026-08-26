# Age / SOPS rotation checklist

GitOps secrets under `secrets/` are encrypted with **SOPS** + **Age**. Argo CD decrypts them in the **platform-secrets** Application via the SOPS CMP sidecar (Age key from **xd-net** `apps/sops.age.keys.txt`, mounted as `SOPS_AGE_KEY_FILE`).

Public recipient in this repo: `.sops.yaml` (`age19q6u…`). Private key stays on the operator machine and in the gitignored Terraform file — **never commit private keys**.

## Rotate (high level)

Treat rotation as a short planned outage for secret sync. Keep the **old** private key until every ciphertext file and the cluster Secret are on the **new** key.

1. **Generate a new Age keypair** (offline / password manager):

   ```bash
   age-keygen -o sops.age.keys.txt.new
   ```

   Note the new public key (`age1…`) printed by `age-keygen`.

2. **Update recipients in Git** — edit `.sops.yaml` so every `age:` entry lists **both** old and new public keys (multi-recipient). Commit that change first so re-encryption can use either key.

3. **Re-encrypt every file** under `secrets/`:

   ```bash
   export SOPS_AGE_KEY_FILE=/path/to/old-or-both.keys.txt
   find secrets -name '*.yaml' -print0 | xargs -0 -n1 sops updatekeys -y
   # or: sops -r -i --add-age <new-pubkey> secrets/<file>.yaml
   ```

   Prefer `sops updatekeys` after `.sops.yaml` lists the new recipient. Confirm `sops -d secrets/<file>.yaml` works with **only** the new private key before removing the old recipient.

4. **Drop the old recipient** from `.sops.yaml`, run `sops updatekeys` again so ciphertext is new-key-only, and commit.

5. **Update the operator workstation** — replace `SOPS_AGE_KEY_FILE` / local `keys.txt` with the new private key. Store a sealed backup of the private key offline.

6. **Update Argo CD** — in **xd-net** `apps/`, replace gitignored `sops.age.keys.txt` with the new private key material (same path as `argocd_sops_age_key_file`, default `./sops.age.keys.txt`). Then:

   ```bash
   cd ~/Projects/xd-net/apps
   terraform apply
   ```

   That refreshes the Kubernetes Secret mounted into the cmp-sops sidecar.

7. **Verify decrypt in-cluster** — sync **platform-secrets** in Argo CD (hard refresh if needed). Confirm Secrets still appear in app namespaces and no CMP errors in the `platform-secrets` Application.

8. **Retire the old private key** only after Git history on `master` encrypts solely to the new public key and Argo CD has been applied. Assume old key material may still exist in local backups and previous Terraform state — treat those as sensitive until wiped.

## Day-to-day (no rotation)

```bash
export SOPS_AGE_KEY_FILE=~/Projects/xd-net/apps/sops.age.keys.txt
sops secrets/<name>.yaml          # edit
sops --encrypt --in-place …       # if creating plaintext then encrypting
```

See `secrets/README.md` for file inventory and `# sops:encrypt` / nested-key rules.

## Failure modes

| Symptom | Likely cause |
|---------|----------------|
| `platform-secrets` CMP decrypt errors | Cluster Secret still has old/wrong key; terraform apply missed |
| Local `sops` fails with MAC / no key | `SOPS_AGE_KEY_FILE` points at wrong file; `.sops.yaml` recipient mismatch |
| Only some files decrypt | Partial `updatekeys`; re-run against every `secrets/*.yaml` |
