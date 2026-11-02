# Storage and data protection

## Storage configuration

| Component | Repository location              | Purpose                                                             |
| :-------- | :------------------------------- | :------------------------------------------------------------------ |
| Rook-Ceph | `kubernetes/apps/rook-ceph/`     | Ceph operator, CSI drivers, and cluster configuration               |
| Miroir    | `kubernetes/apps/miroir-system/` | Additional storage configuration                                    |
| Kopiur    | `kubernetes/components/kopiur/`  | Reusable backup, snapshot, restore, and repository-secret resources |

The Rook cluster HelmRelease declares storage classes including `ceph-block` and `ceph-filesystem`, along with snapshot classes.
Check `kubernetes/apps/rook-ceph/rook-ceph/cluster/helmrelease.yaml` for their current settings.

## Shared backup components

`kubernetes/components/kopiur/backup/` includes a PVC, a restore resource, a snapshot policy, and a snapshot schedule.
The PVC defaults to `ceph-block`, and the snapshot class defaults to `csi-ceph-blockpool` through Flux substitutions.
The snapshot policy also references `miroir-slow` for its mover storage.
`kubernetes/components/kopiur/secret/` supplies the shared external-secret resource.

An application must include and configure the relevant components for them to take effect.
Their presence in this repository does not establish backup coverage for every application.

## Reviewing a storage change

Before changing a storage class, volume, or backup policy:

1. Find the applications that consume the resource or include the component.
2. Review the current PVCs, snapshots, and backup jobs through authorized read-only checks.
3. Inspect rendered changes for renamed or removed resources, storage-class changes, and pruning effects.
4. Confirm recovery requirements and a tested restore path before making an operational change.

A Ready workload is not evidence of a recoverable backup. Record restore-test results when recovery procedures are exercised,
including the source backup, destination, data checks, and any application-level verification.

## Recovery documentation

Recovery procedures should live alongside the affected application's configuration, with links added here as they are validated.
There is no verified end-to-end recovery procedure documented on this page yet.
