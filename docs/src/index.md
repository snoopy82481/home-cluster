# Home Operations

This is the documentation for my home infrastructure and Talos Kubernetes cluster.
Git holds the desired state, Flux delivers application changes, and the surrounding tooling handles provisioning, updates, and observability.

## Explore the cluster

| Guide                                              | What it covers                                               |
| :------------------------------------------------- | :----------------------------------------------------------- |
| [Architecture](architecture/overview.md)           | The main infrastructure layers and where they are configured |
| [GitOps](architecture/gitops.md)                   | How changes travel from Git to applications                  |
| [Network](network-diagram.md)                      | The existing home-network topology and VLAN diagram          |
| [Storage and backups](architecture/storage.md)     | Rook-Ceph, Miroir, and reusable Kopiur components            |
| [Repository workflow](operations/workflow.md)      | Preparing, checking, and reviewing changes                   |
| [Folder structure](repository/folder-structure.md) | Where configuration belongs                                  |
| [Documentation site](repository/documentation.md)  | Previewing, extending, and publishing these pages            |

## Reading these docs

Architecture pages describe checked-in configuration. They do not certify that a service is running, a backup is recoverable, or the network matches its diagram.
Use the linked source locations to check details before making operational changes.

This repository is tailored to one home environment. Provisioning requires private credentials and environment-specific settings;
it is not a ready-to-run cluster template.

## Documentation to grow next

Useful additions include a verified hardware inventory, application-specific notes alongside their configuration,
and recovery procedures backed by recorded restore tests. Add those as the corresponding work is performed so the documentation remains grounded in tested behavior.
