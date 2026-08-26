# Pangolin rebuild

The edge sits on a single OCI VM (eu-frankfurt-1): Pangolin / Gerbil / Traefik / CrowdSec. Homelab tunnels via **Newt** (`NewtSite` **`xd-net`**). Full stack docs: **xd-net** `pangolin-edge/README.md`.

Dashboard: **https://pangolin.ecksd.ee**. Integration API: **https://pangolin-api.ecksd.ee**.

## When to rebuild

- OCI VM lost / unrecoverable disk
- Intentional destroy + recreate after networking changes
- Compose config drift that is easier to re-push than debug in place

Dashboard org resources and per-app `PublicResource` / HTTPRoute annotations are **not** fully Terraform-owned — after a rebuild you may need to re-paste the setup token and confirm Integration API keys still match **xd-net** `apps/config.auto.tfvars`.

## Full recreate (Terraform)

```bash
cd ~/Projects/xd-net/pangolin-edge
terraform init
terraform apply
```

After apply:

1. Confirm Vercel A records point **only** at `terraform output -raw public_ip` (extra A records break Let's Encrypt; Traefik then serves `TRAEFIK DEFAULT CERT`). `_out/dns-checklist.txt` is a reference copy.
2. Open `terraform output -raw initial_setup_url` and paste `terraform output -raw pangolin_setup_token` if this is a fresh Pangolin DB.
3. Dashboard org **`xd`**; Integration API key must match `pangolin_operator_*` in **xd-net** `apps/config.auto.tfvars`. Update Homepage widget secret (`secrets/homepage-pangolin-widget.yaml`) if the API key rotated.
4. Verify Integration API:

   ```bash
   curl -sS -o /dev/null -w '%{http_code}\n' -L "$(terraform output -raw integration_api_url)/v1/docs"
   ```

5. In-cluster: confirm Newt / pangolin-operator still talk to the edge (`kubectl -n pangolin-system get pods` or the namespaces used by those Helm releases in **xd-net**). Exercise one Pangolin-fronted hostname (for example `auth.ecksd.ee`).

SSH keys default to generated `_out/ssh/pangolin-edge`. OCI auth is `~/.oci/config`. Secrets stay in gitignored `config.auto.tfvars`.

## Re-push compose without recreating OCI

When the VM is healthy but `/opt/pangolin` needs a refresh:

```bash
cd ~/Projects/xd-net/pangolin-edge
./scripts/push-deploy.sh ubuntu@$(terraform output -raw public_ip)
```

After editing `config.yml` on the VM: `docker compose restart pangolin`.

## Destroy

```bash
cd ~/Projects/xd-net/pangolin-edge
terraform destroy
```

Removes the VM, VCN, public IP, and related OCI objects. Homelab apps keep their Pangolin annotations; they simply stop working until a new edge exists and Newt reconnects.
