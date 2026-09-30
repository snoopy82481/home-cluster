#!/usr/bin/env -S just --justfile

set minimum-version := '1.55.0'

set default-list
set default-script
set lazy
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

[group('Bootstrap')]
mod bootstrap "bootstrap"

[group('Kube')]
mod kube "kubernetes"

[group('Talos')]
mod talos "talos"

[group('Infrastructure')]
mod infra "infrastructure"

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

# Render a Jinja template with Doppler secrets as its context.
[positional-arguments]
[private]
template file='-' *args:
    file="$1"
    shift
    doppler_context="$(doppler secrets download --project home-cluster --config prd_kubernetes --format json --no-file --no-fallback --no-check-version </dev/null | jq 'map_values(. as $value | try (fromjson | if type == "object" or type == "array" then . else $value end) catch $value)')"
    minijinja-cli --config-file .minijinja.toml --format json "$file" <(printf '%s\n' "$doppler_context") "$@"
