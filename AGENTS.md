# Agent notes (xd-net-apps)

## Commit messages

Write commit messages the same way you would write a short technical note for teammates.

- **Subject line:** One imperative sentence in plain language (for example “Add …”, “Fix …”, “Document …”). **Do not** use Conventional Commits prefixes (`feat:`, `fix:`, `chore:`), scoped forms like `feat(authentik):`, or all-caps ticket codes in the subject unless the repository already standardizes on them here.
- **Body (optional but preferred for non-trivial changes):** One or more short paragraphs using **complete sentences**, correct grammar, and only information that helps someone understand what changed and why. Avoid telegraphic bullet fragments; if you use bullets, make each bullet a full sentence.

## Pull request descriptions

Use the same standard as commit bodies: complete sentences, good grammar, and relevant detail only—enough for review without repeating the entire diff.

## App READMEs

Document how to install and operate the app: prerequisites, secrets, apply order, and non-obvious wiring (storage classes, Gateway parents, CNPG image quirks worth encoding in manifests).

Do **not** add a **Troubleshooting** section for every bug fixed while standing up a new app. Prefer fixing the manifests or values so a fresh apply works; mention one-off constraints inline in the table or manifest comment when they matter long term (for example CNPG `postgresUID` for a third-party image). Reserve troubleshooting sections for recurring production issues operators hit after the app is already running—not for mistakes caught during initial creation.
