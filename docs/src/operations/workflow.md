# Repository workflow

## Prepare a change

Read `AGENTS.md` for repository policy. Tools and environment settings are managed through mise;
operational recipes are exposed through Just.

From the repository root, list the recipes:

```fish
just --list
```

Review a recipe before running it. Bootstrap, infrastructure, Talos, and Kubernetes recipes can change live resources.
Tool installation can also install Git hooks through the mise post-install hook.

## Application changes

Applications belong under `kubernetes/apps/<namespace>/<app>/`.
Use the neighboring application structure and the add-app guidance in `.agents/skills/add-app/SKILL.md`.
Check the namespace's `kustomization.yaml` includes the application and review its target namespace, dependencies, secrets, and storage.

For YAML changes, follow `.agents/instructions/sorting_instructions.md` and preserve embedded configuration strings.
Keep credentials out of manifests and documentation.

## Local validation

For Kubernetes manifest changes, the repository recommends:

```fish
flate test all --path ./kubernetes/apps
flate diff all --path ./kubernetes/apps --base origin/main
```

Run these from an environment with the repository's tools available and an up-to-date `origin/main` reference.
They may fetch upstream chart sources. Review rendered changes before merging.

These checks do not establish live health, CRD compatibility, secret availability, or successful recovery.
Template rendering can resolve credentials; keep any resolved output out of logs, commits, and documentation.

Documentation-only changes use the [documentation build](../repository/documentation.md), link checks, and whitespace checks.

## Review and delivery

Keep changes focused. Dependency reviews need upstream release or source evidence, in addition to Renovate's description.
Use [Conventional Commits](../repository/semantic-git-messages.md) when preparing a commit.

After review and merge to `main`, Flux can reconcile application changes.
Live applies, manual reconciliations, upgrades, deletions, and bootstrap operations are separate operational actions.
