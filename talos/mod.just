set default-list
set default-script
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

nodes := `talosctl config info -o yaml | yq -r '[.nodes[] | tostring] | join (" ")'`
talos_version := `yq .spec.talos.version "../kubernetes/apps/system-upgrade/tuppr/upgrades/talosupgrade.yaml"`
kubernetes_version := `yq .spec.kubernetes.version "../kubernetes/apps/system-upgrade/tuppr/upgrades/kubernetesupgrade.yaml"`
proxmox_user := "root"
proxmox_host := "proxmox"
proxmox_iso_dir := "/var/lib/vz/template/iso"
ssh_opts := "-o BatchMode=yes -o ConnectTimeout=5"

[private]
_download_local_atomic url out_path:
    tmp="{{ out_path }}.part"
    fname="$(basename "{{ out_path }}")"
    gum spin --title "Downloading ${fname} ..." -- \
      curl -fL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors --progress-bar \
        -o "${tmp}" "{{ url }}"
    mv -f "${tmp}" "{{ out_path }}"
    sha256sum "{{ out_path }}" | awk '{print $1}'

[private]
_push_remote_atomic local_path remote_path:
    fname="$(basename "{{ local_path }}")"
    gum spin --title "Uploading ${fname} to {{ proxmox_host }} ..." -- \
      scp {{ ssh_opts }} "{{ local_path }}" {{ proxmox_user }}@{{ proxmox_host }}:"{{ remote_path }}"
    ssh {{ ssh_opts }} {{ proxmox_user }}@{{ proxmox_host }} "sha256sum '{{ remote_path }}'" | awk '{print $1}'

[private]
_sync_image_atomic fname url:
    fname="{{ fname }}"
    url="{{ url }}"
    local_path="{{ source_directory() }}/{{ fname }}"
    remote_path="{{ proxmox_iso_dir }}/{{ fname }}"
    local_sha="$(just talos _download_local_atomic "${url}" "${local_path}")"
    remote_sha="$(just talos _push_remote_atomic "${local_path}" "${remote_path}")"
    if [[ "${local_sha}" != "${remote_sha}" ]]; then
      just log error "Checksum mismatch for {{ fname }}" "local" "${local_sha}" "remote" "${remote_sha}"
      exit 2
    fi
    just log info "Uploaded + verified Talos ISO" "file" "{{ fname }}" "checksum" "${remote_sha}" "host" "{{ proxmox_host }}"

[doc('Apply Talos config to a node')]
apply-node node *args:
    just log info "Applying Talos machineconfig" "node" "{{ node }}";
    just talos render-config "{{ node }}" | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Bootstrap the Talos cluster')]
bootstrap:
    talhelper gencommand bootstrap | bash

[doc('Download Talos machine image (atomic: download -> checksum -> push -> verify)')]
download-image version schematic secureboot="true":
    suffix=""
    path="metal-amd64.iso"
    case "{{ secureboot }}" in
      true|1|yes|y|sb)
        suffix="-secureboot"
        path="metal-amd64-secureboot.iso"
        ;;
      false|0|no|n|nsb)
        suffix=""
        path="metal-amd64.iso"
        ;;
      *)
        just log error "secureboot must be true/false (or 1/0, yes/no, sb/nsb)" "value" "{{ secureboot }}"
        exit 2
        ;;
    esac
    short="{{ replace_regex(schematic, '^(.{8}).*', '$1') }}"
    fname="talos-${short}${suffix}.iso"
    url="https://factory.talos.dev/image/{{ schematic }}/{{ version }}/${path}"
    just talos _sync_image_atomic "${fname}" "${url}"
    gum spin --spinner dot --title "Remove local ISO: ${fname}" -- \
      rm -f "{{ source_directory() }}/${fname}"
    just log info "Removed local Talos iso ${fname}"

[doc("Remove old Talos machine images (local + proxmox)")]
remove-image:
    shopt -s nullglob
    files=({{ source_directory() }}/*.iso)
    if (( ${#files[@]} == 0 )); then
      mapfile -t files < <(
        ssh {{ ssh_opts }} {{ proxmox_user }}@{{ proxmox_host }} \
          "find '{{ proxmox_iso_dir }}' -maxdepth 1 -type f -name 'talos-*.iso' -printf '%f\n'"
      )
      if (( ${#files[@]} == 0 )); then
        just log error "No Talos ISO found locally or on {{ proxmox_host }}"
        exit 0
      fi
      for fname in "${files[@]}"; do
        gum spin --spinner dot --title "Deleting remote ISO on {{ proxmox_host }}: ${fname}" -- \
          ssh {{ ssh_opts }} {{ proxmox_user }}@{{ proxmox_host }} "rm -f '{{ proxmox_iso_dir }}/${fname}'"
        just log info "Removed Talos iso ${fname}"
      done
      exit 0
    fi
    for iso in "${files[@]}"; do
      fname="$(basename "$iso")"
      gum spin --spinner dot --title "Deleting local ISO: ${fname}" -- rm -f "$iso"
      gum spin --spinner dot --title "Deleting remote ISO on {{ proxmox_host }}: ${fname}" -- \
        ssh {{ ssh_opts }} {{ proxmox_user }}@{{ proxmox_host }} "rm -f '{{ proxmox_iso_dir }}/${fname}'"
      just log info "Removed Talos iso ${fname}"
    done

[doc('Update Talos machine image from version + schematic (remove old images, then download new one)')]
update-image version schematic secureboot="true":
    just talos remove-image
    just talos download-image "{{ version }}" "{{ schematic }}" "{{ secureboot }}"
    # just infra proxmox-init
    # just infra proxmox-plan
    # just infra proxmox-apply

[confirm('Reboot node ' + node + ' [y|N] ?')]
[doc('Reboot a node')]
reboot-node node:
    talosctl -n {{ node }} reboot -m powercycle

[confirm('Reboot all nodes in the cluster [y|N] ?')]
[doc('Reboot all nodes in the cluster')]
reboot-all:
    talosctl reboot -m powercycle -n {{ nodes }}

[private]
_render-template file *args:
    just template "{{ file }}" <(sops exec-file --filename talsecret.yaml --input-type yaml --output-type yaml "{{ source_directory() }}/talsecret.sops.yaml" "yq '.certs_pem = (.certs | with_entries(.value |= with_entries(.value |= @base64d))) | .sa_pem = (.serviceaccount | with_entries(.value |= @base64d))' {}") -f yaml {{ args }}

[doc('Render Talos config for a node')]
render-config node:
    schematic="$(just talos schematic-id "{{ node }}")"
    role="controlplane"

    if [[ -f "{{ source_directory() }}/nodes/worker/{{ node }}.yaml.j2" ]]; then
      role="worker"
    fi

    talosctl machineconfig patch <(just talos _render-template "{{ source_directory() }}/cluster.yaml.j2" -D "schematic=${schematic}") \
      -p @<(just talos _render-template "{{ source_directory() }}/${role}.yaml.j2") \
      -p @<(just template "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2")

[confirm('Reset node ' + node + ' [y|N] ?')]
[doc('Reset a node')]
reset-node node:
    talosctl -n "{{ node }}" reset --reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --wait=false

[confirm('Shutdown node ' + node + ' [y|N] ?')]
[doc('Shutdown a node')]
shutdown-node node *args:
    talosctl -n "{{ node }}" shutdown --force {{ args }}

[confirm('Shutdown all nodes in the cluster [y|N] ?')]
[doc('Shutdown all nodes in the cluster')]
shutdown-all *args:
    talosctl -n "{{ nodes }}" shutdown --force {{ args }}

[confirm('Upgrade Kubernetes to ' + version + ' [y|N] ?')]
[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version=kubernetes_version:
    talosctl -n "$(talosctl config info -o yaml | yq -e '.endpoints[0]')" upgrade-k8s --to {{ version }}

[confirm('Upgrade node ' + node + ' [y|N] ?')]
[doc('Upgrade Talos version on a node')]
upgrade-node node *args:
    talosctl -n "{{ node }}" upgrade -i "$(just talos machine-image {{ node }})" -m powercycle --timeout=10m {{ args }}

[confirm('Upgrade all nodes in the cluster to ' + version + ' [y|N] ?')]
[doc('Upgrade all nodes in the cluster')]
upgrade-all version=talos_version:
    for node in nodes.split(','); do
      just talos upgrade-node "${node}"
      # talosctl -n "${node}" upgrade -i "$(just talos machine-image ${node})" -m powercycle --timeout=10m
    done

[private]
schematic-file node="":
    file="{{ source_directory() }}/schematic.yaml.j2"
    if [[ -n "{{ node }}" ]]; then
        for f in "{{ source_directory() }}"/nodes/*/"{{ node }}".schematic.yaml.j2; do
            [[ -f "$f" ]] && file="$f"
        done
    fi
    echo "$file"

[private]
schematic-id node="":
    curl -sX POST --data-binary @<(just template "$(just talos schematic-file "{{ node }}")") "https://factory.talos.dev/schematics" | jq -r '.id'

[doc('Get the machine image for a given node')]
[private]
machine-role node:
    just template "{{ source_directory() }}/nodes/{{ node }}.yaml.j2" | yq -er 'select(.machine) | .machine.type'

[doc('Get the machine image for a given node')]
[private]
machine-image node:
    just talos _render-template talos/cluster.yaml.j2 '-D schematic=$(just talos schematic-id "{{ node }}")' | yq -r -e 'select(.kind == "UnattendedInstallConfig") | .installer.image'
