set default-list
set default-script
set no-exit-message
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'
controller := `talosctl config info -o yaml | yq -e '.endpoints[0]'`
controllers := `talosctl config info -o yaml | yq -r '[.endpoints[] | tostring] | join (" ")'`
nodes := `talosctl config info -o yaml | yq -r '[.nodes[] | tostring] | join (" ")'`

[confirm('Bootstrap cluster? [y|N]')]
[doc('Bootstrap a Talos & Kubernetes cluster end-to-end')]
cluster: nodes k8s (kubeconfig "node") base apps kubeconfig

[private]
nodes:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    for n in {{ nodes }}; do
        if ! op=$(just --yes talos apply-node "$n" --insecure 2>&1); then
            if [[ "$op" == *"certificate required"* ]]; then
                just log info "Talos already configured, skipping apply of config" "stage" "{{ recipe_name() }}" "node" "$n"
                continue
            fi
            just log fatal "Failed to apply Talos configuration" "stage" "{{ recipe_name() }}" "node" "$n" "output" "$op"
        fi
    done

[private]
k8s:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    until op=$(talosctl -n "{{ controller }}" bootstrap 2>&1 || true) && [[ "$op" == *"AlreadyExists"* ]]; do
        just log info "Kubernetes bootstrap in progress. Retrying in 5 seconds..." "stage" "{{ recipe_name() }}"
        sleep 5
    done

[private]
kubeconfig lb="cilium":
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! talosctl kubeconfig -n "{{ controller }}" -f --force-context-name main {{ justfile_dir() }}; then
        just log fatal "Failed to fetch kubeconfig" "stage" "{{ recipe_name() }}"
    fi
    if [[ "{{ lb }}" != "cilium" ]]; then
        if ! kubectl config set-cluster main --server "https://{{ controller }}:6443"; then
            just log fatal "Failed to set kubectl cluster server address" "stage" "{{ recipe_name() }}"
        fi
    fi

[private]
base: api-ready nodes-ready
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! kustomize build {{ source_directory() }}/kustomize/personal | just template - | yq 'with(select(.kind == "Secret" and (.stringData | tag) == "!!str"); .stringData |= from_json)' | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply personal manifests" "stage" "{{ recipe_name() }}"
    fi
    if ! helmfile -f "{{ source_directory() }}/helmfile.d/crds.yaml" template -q | yq ea -e 'select(.kind == "CustomResourceDefinition")' | kubectl apply --server-side --force-conflicts -f -; then
        just log fatal "Failed to apply base crds" "stage" "{{ recipe_name() }}"
    fi

[private]
apps:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! helmfile -f "{{ source_directory() }}/helmfile.d/apps.yaml" sync --hide-notes; then
        just log fatal "Failed to sync helmfile" "stage" "{{ recipe_name() }}"
    fi

# Wait until every apiserver answers /readyz. Helm and kubectl calls after this stage are not retried.
[private]
api-ready:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    for c in {{ controllers }}; do
        until [[ "$(curl -ks -o /dev/null -w '%{http_code}' --connect-timeout 2 "https://${c}:6443/readyz")" == "200" ]]; do
            just log info "Waiting for kube-apiserver. Retrying in 5 seconds..." "stage" "{{ recipe_name() }}" "node" "$c"
            sleep 5
        done
    done

# Wait until every node registers as Ready=False. They only become Ready=True once the CNI is healthy.
[private]
nodes-ready:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    if ! kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..." "stage" "{{ recipe_name() }}"
            sleep 5
        done
    fi

[private]
apply-secrets:
    just log info "Running stage..." "stage" "{{ recipe_name() }}"
    # export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-{{ source_directory() }}/../age.key}"

    if kubectl create namespace flux-system --dry-run=client --output=yaml | kubectl apply --server-side --force-conflicts -f - &>/dev/null; then
        just log info "Namespace flux-system created" "stage" "{{ recipe_name() }}"
    else
        just log info "Namespace flux-system already exists" "stage" "{{ recipe_name() }}"
    fi

    for secret in \
        "{{ source_directory() }}/github-deploy-key.sops.yaml" \
        "{{ kubernetes_dir }}/components/common/sops/cluster-secrets.sops.yaml" \
        "{{ kubernetes_dir }}/components/common/sops/sops-age.sops.yaml"
    do
        name="$(basename "$secret" ".sops.yaml")"
        if just template "$secret" | kubectl --namespace flux-system apply --server-side --filename - &>/dev/null; then
            just log info "Secret resource is up-to-date" "resource=${name}" "stage" "{{ recipe_name() }}"
            continue
        else
            just log fatal "Failed to apply secret" "resource=${name}"
        fi
    done

[private]
apply-secret file:
    if [[ ! -f "{{ file }}" ]]; then
        just log warn "File does not exist" "file={{ file }}"
        exit 0
    fi

    resource="$(basename "{{ file }}" ".sops.yaml")"

    # Check whether secret is up-to-date
    if sops exec-file "{{ file }}" "kubectl --namespace flux-system diff --filename {}" &>/dev/null; then
        just log info "Secret resource is up-to-date" "resource=${resource}"
        exit 0
    fi

    # Apply secret
    if ! sops exec-file "{{ file }}" "kubectl --namespace flux-system apply --server-side --filename {}" &>/dev/null; then
        just log error "Failed to apply secret" "resource=${resource}"
    fi
