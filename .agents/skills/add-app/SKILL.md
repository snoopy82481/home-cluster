---
name: add-app
description: Add a Kubernetes application by gathering its deployment requirements, writing Flux and Helm manifests directly under kubernetes/apps, and validating the result.
---

# Add a New Application

This skill is the source of truth for the app-creation workflow and repository conventions below. Ask about the app's needs, then write the required manifests directly. Do not render or depend on `kubernetes/templates/`, MiniJinja, or `just kube create-app`.

Read `.agents/instructions/sorting.instructions.md` before writing manifests. Verify changing facts such as chart versions, image tags, and supported chart values against the current repository and upstream documentation. Existing apps are examples of specific integrations, not defaults to copy wholesale.

## 1. Work out what the app needs

Start with the user's request and inspect the relevant existing namespace and integrations. Research technical facts you can establish yourself; ask the user for missing intent and choices. Group related questions, offer sensible options, and skip anything already answered. Ask follow-up questions only when an answer introduces a new requirement.

Work through these decisions before writing the affected manifests:

| Decision      | What to establish                                                                                                                                                                                                                                                                 |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Identity      | App name and namespace; reuse an existing namespace or create one.                                                                                                                                                                                                                |
| Deployment    | Container with app-template or an upstream Helm chart; long-running service, background worker, or scheduled job. Research the image/chart and recommend the appropriate approach if the user has no preference.                                                                  |
| Networking    | Whether a Service is needed, its ports/protocols, and whether a hostname is wanted. For a route, ask internal or public exposure and establish the hostname. Suggest internal exposure and `<app>.idahobealefamily.com`; do not expose an app publicly without the user's choice. |
| Data          | Whether state must survive restarts, the data paths and capacity, and whether it needs kopiur backup, an existing claim, NFS, or only ephemeral storage. Do not equate all persistence with backup.                                                                               |
| Configuration | Required environment variables, mounted files, Secret names/keys, and external services. Ask for missing configuration choices rather than guessing them.                                                                                                                         |
| Operation     | Dependencies on other Flux Kustomizations, required schedule/timezone, and any user-specified resource or placement constraints.                                                                                                                                                  |

Verify the image's listening port, supported UID/GID, writable paths, and health checks from upstream documentation. Do not ask the user to supply facts you can verify. Summarize the selected deployment shape before writing files; proceed when the needed choices are established without adding a separate approval gate.

Never request secret values in chat or create/edit secrets or ignored files under the repository's agent rules. Reference user-managed Secrets and report any provisioning prerequisite. Do not silently leave an unresolved choice as a placeholder in a deployment manifest.

Useful examples to inspect when relevant:

- `kubernetes/apps/networking/echo-server/`: minimal web app and route.
- `kubernetes/apps/media/recyclarr/`: config file mounts and kopiur persistence.
- `kubernetes/components/kopiur/backup/`: actual PVC and backup substitutions.

Inspect only the non-secret manifests needed for the task.

## 2. Write the app manifests

Inspect an existing destination before editing it. Create this layout directly, adding files only when the selected deployment needs them:

```text
kubernetes/apps/<namespace>/<app>/
├── ks.yaml
└── app/
    ├── kustomization.yaml
    ├── ocirepository.yaml
    ├── helmrelease.yaml
    └── resources/          # optional non-secret mounted configuration
```

Include the appropriate YAML language-server schema comments, following current files of the same resource type.

### Flux Kustomization: ks.yaml

Use `kustomize.toolkit.fluxcd.io/v1`, kind `Kustomization`, and the app name as `metadata.name`. Set:

- `spec.interval: 1h`
- `spec.path: ./kubernetes/apps/<namespace>/<app>/app`
- `spec.prune: true`
- `spec.sourceRef`: kind `GitRepository`, name `flux-system`, namespace `flux-system`
- `spec.targetNamespace`: the selected namespace

Leave `wait`, `commonMetadata`, and `timeout` unset for an ordinary leaf app. Add actual dependencies to `spec.dependsOn`. If another Kustomization depends on this app, establish readiness with targeted `healthChecks` or `healthCheckExprs`, or use `wait: true` when no targeted checks are defined. Do not combine `wait: true` with targeted checks. Merely depending on another app does not require `wait: true` here.

For kopiur-backed storage, add `spec.components: [../../../../components/kopiur/backup]` and `spec.postBuild.substitute.APP` set to the app name. Read the component for current substitutions before adding overrides:

- The PVC is named `${APP}`. There is no `KOPIUR_CLAIM` override.
- Use `KOPIUR_CAPACITY` for the selected capacity, or inherit the component default when appropriate.
- Use `KOPIUR_PUID` and `KOPIUR_PGID` when backup mover ownership must differ from the defaults. Match the app's data ownership.

For another storage design, create or reference the agreed storage without adding the kopiur component automatically. Add `postBuild.substituteFrom` only for ConfigMaps or Secrets whose variables the manifests use. Omit unused `components` and `postBuild` blocks.

### App Kustomization: app/kustomization.yaml

Use `kustomize.config.k8s.io/v1beta1`, kind `Kustomization`. Register `./helmrelease.yaml`, `./ocirepository.yaml`, and any additional resources actually created or already present. Do not reference files that do not exist.

### OCIRepository: app/ocirepository.yaml

Use `source.toolkit.fluxcd.io/v1`, kind `OCIRepository`, with the app name as `metadata.name`. Set `spec.interval: 5m` and `spec.layerSelector` to media type `application/vnd.cncf.helm.chart.content.v1.tar+gzip`, operation `copy`.

For app-template, use `spec.url: oci://ghcr.io/bjw-s-labs/helm/app-template`. Read `spec.ref.tag` from a current app-template OCIRepository in the repository, filtering by that exact URL rather than taking a version from an unrelated chart. For an upstream chart, verify its OCI URL and version against upstream documentation. If it requires a different source type, use the supported Flux source/chart wiring instead of inventing an OCI URL. Quote version strings.

### HelmRelease: app/helmrelease.yaml

Use `helm.toolkit.fluxcd.io/v2`, kind `HelmRelease`, with the app name as `metadata.name`. For an OCI source, set `spec.chartRef.kind: OCIRepository` and `spec.chartRef.name` to the matching resource name. Use `spec.interval: 1h`.

For app-template, construct `spec.values` from the selected requirements:

- Use an app-named controller and an `app` container. Set the controller type and schedule as required by the workload. Add `reloader.stakater.com/auto: "true"` to controller annotations for Secret/config reloads.
- Set `containers.app.image.repository` and a verified, quoted `tag`. Plain tags are acceptable; Renovate manages digest pinning and updates. Add only environment variables the image supports; do not assume it recognizes `PORT` or needs `TZ`.
- Set `defaultPodOptions.securityContext` for the image's verified UID/GID, with non-root execution where supported. Set `fsGroup` and `fsGroupChangePolicy: OnRootMismatch` when needed for volume ownership. Do not impose a universal UID/GID.
- Prefer container `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, and `readOnlyRootFilesystem: true` where supported. Add emptyDir mounts for required writable paths such as `/tmp`; do not add writable paths or privileges without an app requirement.
- Choose probes the workload supports. There is no universal `/ping` endpoint. A worker or scheduled job may not need a network probe. Set resource requests/limits appropriate to documented requirements or a comparable workload; identify initial sizing assumptions.
- When networking is needed, use `service.app.controller` set to the app-named controller and define the actual ports/protocols. Omit the Service for a workload that does not listen for connections.
- When an HTTP route is requested, use `route.app.hostnames` and `route.app.parentRefs` with the selected `envoy-internal` or `envoy-external` gateway in namespace `networking`. Keep route/service references aligned and verify the rendered backend. Omit routes otherwise.
- For kopiur, set a persistence item's `existingClaim` to the app name and `globalMounts` to the actual data paths. For existing claims, NFS, or other agreed storage, use the matching chart values. Stateless apps must not reference a PVC.

For an upstream chart, use its documented values and source configuration. Do not apply app-template values or sorting overrides to a different chart. Explicitly wire any separately provisioned PVC into that chart's supported persistence settings.

### Mounted configuration and Secrets

Put non-secret mounted files in `app/resources/` and add a `configMapGenerator` to `app/kustomization.yaml`. Use `generatorOptions.disableNameSuffixHash: true` for stable HelmRelease references. Add `generatorOptions.annotations.kustomize.toolkit.fluxcd.io/substitute: disabled` when the generated configuration must bypass Flux substitution. Add matching configMap mounts, including `subPath` for individual files.

Reference user-managed Secrets by exact name and keys through `envFrom` or `env.valueFrom.secretKeyRef`. Register an existing app-local encrypted manifest when needed without modifying its contents. Do not invent credentials, ExternalSecrets, or a secret backend.

## 3. Register the app and namespace

For a new namespace, write `namespace.yaml` with `apiVersion: v1`, kind `Namespace`, literal `metadata.name: _`, and annotation `kustomize.toolkit.fluxcd.io/prune: disabled`.

Write its `kustomization.yaml` with `apiVersion: kustomize.config.k8s.io/v1beta1`, kind `Kustomization`, `namespace` set to the selected name, component `../../components/common`, and resource `./namespace.yaml`. Include `../../components/kopiur/secret` only when needed for kopiur. For an existing namespace's first kopiur-backed app, add that component if absent without editing its secret contents.

Register `./<app>/ks.yaml` once in the namespace kustomization's resources, in alphabetical position. Preserve unrelated entries. Check current namespace discovery under `kubernetes/flux/cluster/` before registering a namespace elsewhere; do not invent a root kustomization when the current setup uses directory discovery.

Apply the repository's sorting conventions to authored manifests. Do not sort arbitrary configuration embedded inside strings.

## 4. Validate and report

Run these checks with the selected app and namespace:

```fish
kustomize build "kubernetes/apps/$namespace/$app/app"
yamllint --config-file .github/linters/.yamllint.yaml "kubernetes/apps/$namespace/$app"
```

Validate changed namespace manifests too. A plain app-directory build does not expand Flux `spec.components`, apply Flux substitutions, or render the Helm chart. For component integration, use a temporary workspace and an offline Flux build to verify substitutions and generated resources. Render the selected Helm chart with the authored values to check its schema and workload wiring, including Service selectors, route backends, and PVC names where applicable. Avoid printing secret contents during validation.

Check that there are no placeholders, empty image/chart fields, invalid ports, or references to missing local resources. Intentional Flux `${...}` substitutions and chart-supported Helm expressions may remain literal before their respective rendering stages.

Report created files, selected deployment choices, validation results, and provisioning prerequisites. Distinguish local validation from runtime testing. Do not commit, push, open a PR, or apply resources to the cluster unless explicitly requested.
