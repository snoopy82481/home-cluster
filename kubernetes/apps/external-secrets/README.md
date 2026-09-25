# Doppler migration: Kubernetes foundation

The operator uses the upstream ESO chart, pinned to 2.11.0. The `doppler`
ClusterSecretStore reads `home-cluster / prd_kubernetes`. Access is initially
limited to `external-secrets` and `media`; expand it only as namespaces migrate.
Anyone permitted to create ExternalSecrets in those namespaces can request keys
accessible through this store. The token must not grant access to bootstrap,
Talos, or OpenTofu credentials.

## Provisioning prerequisite

Create a read-only service token for `home-cluster / prd_kubernetes` in Doppler.
Do not use a personal token, paste the token into chat, or commit it to Git.
Provision it as the user-managed Kubernetes Secret `doppler-token`, in namespace
`external-secrets`, with key `dopplerToken`. No Secret manifest is included here.
The store cannot become Ready until that Secret exists and authenticates.

Keep an independent recovery path for provisioning this token after a rebuild.
ESO cannot fetch its own initial credential from Doppler without authenticating.

## Deployment and validation gates

1. Review and deploy the foundation through the normal GitOps workflow.
2. Confirm the `external-secrets` HelmRelease is Ready. The store Kustomization
   depends on that health check so CRDs and controllers are installed first.
3. Provision the authentication Secret and confirm ClusterSecretStore `doppler`
   and Kustomization `external-secrets-doppler` become Ready.
4. Choose one media application for the pilot. Map its existing Secret names,
   keys, type, and decoded values to explicit Doppler keys. Do not import the
   entire config into each application's Secret.
5. Sync into a separate comparison Secret first. Compare decoded bytes without
   displaying them, including multiline/file contents. Decode existing Secret
   `data` exactly once; preserve `stringData` as plaintext before upload.
6. Before switching to the original Secret name, protect the existing Secret
   against Flux pruning and verify that protection is applied. Retire its SOPS
   resource from Flux management before enabling ESO writes to that same name.
   Keep the encrypted source and age recovery key until rollback is verified.
7. Verify Secret readiness, application access, a controlled update, and restart
   behavior. Continue application by application, then migrate shared
   `cluster-secrets` using separate producer/consumer Kustomizations.

The current common namespace component still includes SOPS resources. This is
intentional coexistence, not the final SOPS-free bootstrap design. Talos,
OpenTofu, Flux Git credentials, and bootstrap secrets remain unchanged.

For rollback, stop ESO reconciliation for the pilot before restoring SOPS
management. Choose and verify target ownership/deletion policies before cutover;
`deletionPolicy: Retain` alone does not prevent garbage collection when deleting
an ExternalSecret that owns its target Secret. Do not delete the operator or its
CRDs while migrated applications depend on it.

## Official references

- [ESO installation](https://external-secrets.io/latest/introduction/getting-started/)
- [ESO Doppler provider](https://external-secrets.io/latest/provider/doppler/)
- [Doppler service tokens](https://docs.doppler.com/docs/service-tokens)
- [ESO lifecycle policies](https://external-secrets.io/latest/guides/ownership-deletion-policy/)
