# Folder structure

Paths below are relative to the repository root.

```text
.
├── .agents/                # Repository policy details and task guidance
├── .github/                # Workflows, issue templates, and lint configuration
├── .mise/                  # Tool environment and hooks
├── bootstrap/              # Initial cluster configuration and recipes
├── docs/
│   ├── requirements.txt    # Documentation builder dependency
│   └── src/                # Published Markdown and assets
├── infrastructure/         # OpenTofu Proxmox VM configuration and recipes
├── kubernetes/
│   ├── apps/               # Applications grouped by namespace
│   └── components/         # Reusable Kustomize components
├── talos/                  # Node templates, node overrides, and versions
├── .justfile               # Entry point for operational recipes
├── readme.md               # Repository overview
└── zensical.toml           # Documentation site configuration
```

## Application layout

A typical chart-based application follows this shape. Some apps also have configuration, cluster, or other resource directories.

```text
kubernetes/apps/<namespace>/
├── kustomization.yaml
└── <app>/
    ├── ks.yaml
    └── app/
        ├── kustomization.yaml
        ├── helmrelease.yaml
        └── ocirepository.yaml
```

The namespace-level Kustomize configuration includes `ks.yaml`.
The application's Flux Kustomization points to its resource directory and sets the target namespace.
See [GitOps](../architecture/gitops.md) for the full chain.

## Documentation placement

Cross-cutting guides live in `docs/src/`. Component-specific operational notes belong alongside the component configuration;
link to them from the relevant guide when needed.
Build output goes to `site/` and is not committed.
