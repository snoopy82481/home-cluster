set default-list
set default-script
set positional-arguments
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

opentofu_vm_dir := justfile_dir() + "/infrastructure/opentofu/vm"

[private]
default:
    just -l infra

[private]
_proxmox_tofu command *args:
    cd {{ opentofu_vm_dir }} && doppler run -- tofu {{ command }} {{ args }}

[doc('Initialize proxmox OpenTofu dependencies')]
proxmox-init *args:
    just infra _proxmox_tofu init {{ args }}

[doc('Format proxmox OpenTofu files')]
proxmox-fmt *args:
    just infra _proxmox_tofu fmt {{ args }}

[doc('Validate proxmox OpenTofu configuration')]
proxmox-validate *args:
    just infra _proxmox_tofu validate {{ args }}

[doc('Show the changes OpenTofu will make')]
proxmox-plan env="talos" *args:
    just infra _proxmox_tofu plan -out={{ env }}_plan.tfplan {{ args }}

[doc('Apply the proxmox OpenTofu changes')]
proxmox-apply *args:
    just infra _proxmox_tofu apply -auto-approve {{ args }}

[doc('Apply a saved proxmox OpenTofu plan file')]
proxmox-apply-plan env="talos":
    just infra _proxmox_tofu apply -auto-approve {{ env }}_plan.tfplan

[doc('Destroy proxmox resources')]
proxmox-destroy *args:
    just infra _proxmox_tofu destroy -auto-approve {{ args }}

[doc('Show current proxmox Opentofu outputs')]
proxmox-output *args:
    just infra _proxmox_tofu output {{ args }}
