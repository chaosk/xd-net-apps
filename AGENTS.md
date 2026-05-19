# Agent notes (xd-net-apps)

## Commit messages

Write commit messages the same way you would write a short technical note for teammates.

- **Subject line:** One imperative sentence in plain language (for example “Add …”, “Fix …”, “Document …”). **Do not** use Conventional Commits prefixes (`feat:`, `fix:`, `chore:`), scoped forms like `feat(authentik):`, or all-caps ticket codes in the subject unless the repository already standardizes on them here.
- **Body (optional but preferred for non-trivial changes):** One or more short paragraphs using **complete sentences**, correct grammar, and only information that helps someone understand what changed and why. Avoid telegraphic bullet fragments; if you use bullets, make each bullet a full sentence.

## Logical commits

**One commit = one logical change** — judged by purpose, not by directory. Ask whether you would revert, review, or describe the work as a single unit. Touching several paths or apps is fine when they serve the same change.

**One commit** (examples):

- Right-sizing memory requests and limits across Authentik, Tube Archivist, and Tracearr after one cluster audit — same intent, one review, revert together.
- Adding a new app (manifests, values, README, secrets template) as one deliverable.

**Separate commits** (examples):

- A Tracearr CNPG bootstrap fix and an `AGENTS.md` policy update — unrelated purpose.
- A memory pass and an unrelated new feature in the same session.

Per-app commits are common when each app is an independent deliverable; they are **not** a rule. Do not split one coherent change across apps only because paths differ.

When the user asks to commit and the tree has **unrelated** changes, make multiple commits (stage each group in order). When unsure, prefer **one commit** if the work shares a single sentence of explanation; split when two sentences with no “and” between them would be clearer.

## Pull request descriptions

Use the same standard as commit bodies: complete sentences, good grammar, and relevant detail only—enough for review without repeating the entire diff.

## Vendored Helm charts

Some apps ship an upstream chart under `apps/<app>/vendor/` (for example Tracearr). **Do not edit files inside `vendor/`** — treat that tree as a read-only copy from upstream.

Put all cluster-specific and version overrides in **`values.yaml`**, `kustomization.yaml`, and other manifests **outside** `vendor/` (image `tag`, CNPG, HTTPRoute, resources). To refresh a chart, replace the vendor directory from upstream and re-apply your outer overrides only.

## App READMEs

Document how to install and operate the app: prerequisites, secrets, apply order, and non-obvious wiring (storage classes, Gateway parents, CNPG image quirks worth encoding in manifests).

Do **not** add a **Troubleshooting** section for every bug fixed while standing up a new app. Prefer fixing the manifests or values so a fresh apply works; mention one-off constraints inline in the table or manifest comment when they matter long term (for example CNPG `postgresUID` for a third-party image). Reserve troubleshooting sections for recurring production issues operators hit after the app is already running—not for mistakes caught during initial creation.
