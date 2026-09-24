from __future__ import annotations

import json
import os
import re

import requests

from .logging_config import log
from .registry import PROVIDERS
from .special_class import Provider, RenovateDep


def fetch_pr_body(pr_number: str) -> str:
    log.info(f"Fetching PR body for #{pr_number}")

    repo = os.getenv("GITHUB_REPOSITORY")
    token = os.getenv("GH_APP_TOKEN")

    url = f"https://api.github.com/repos/{repo}/pulls/{pr_number}"

    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
    }

    r = requests.get(url, headers=headers)
    r.raise_for_status()
    return r.json()["body"]


def extract_metadata(pr_body: str) -> list[RenovateDep]:
    """Extract Renovate dependencies from legacy JSON or its current PR table."""
    json_block = re.search(r"```json\s*(.*?)```", pr_body, re.DOTALL)
    if json_block:
        data = json.loads(json_block.group(1))
        return data.get("deps", [])

    dependencies: list[RenovateDep] = []
    pattern = re.compile(
        r"^\|\s*(?:\[[^]]+\]\(https:\/\/(?:redirect\.)?github\.com\/"
        r"(?P<source>[^/)]+\/[^/)#?]+)\)\s*.*?|"
        r"ghcr\.io/(?P<image>atuinsh/atuin|siderolabs/kubelet)\s*|"
        r"registry\.k8s\.io/(?P<kubernetes>kube-(?:apiserver|controller-manager|proxy|scheduler))\s*)\|\s*"
        r"[^|]+\|\s*`(?P<current>[^`]+)`\s*(?:→|->)\s*"
        r"`(?P<new>[^`]+)`\s*\|$",
        re.MULTILINE,
    )

    for match in pattern.finditer(pr_body):
        source = (
            "kubernetes/kubernetes"
            if match.group("kubernetes")
            else match.group("source") or match.group("image")
        )
        dependency: RenovateDep = {
            "depName": source,
            "packageName": source,
            "manager": "",
            "datasource": "",
            "currentVersion": match.group("current"),
            "newVersion": match.group("new"),
            "registryUrl": None,
        }
        if dependency not in dependencies:
            dependencies.append(dependency)

    return dependencies


def providers_for(
    dependencies: list[RenovateDep],
) -> list[tuple[RenovateDep, Provider]]:
    providers: list[tuple[RenovateDep, Provider]] = []
    for dep in dependencies:
        provider = PROVIDERS.get(dep["packageName"].lower())
        if provider:
            providers.append((dep, provider))
    return providers


def rewrite_body(old_body: str, dep: RenovateDep, notes: str) -> str:
    """Replace the dependency's release notes, creating a section when absent."""
    source = re.escape(dep["depName"])
    pattern = re.compile(
        rf"(?P<head><details>\s*<summary>[^\n]*{source}[^\n]*</summary>(?:(?!</details>).)*?"
        r"\[Compare Source\]\([^)]+\))(?P<notes>.*?)"
        r"(?P<end>\s*</details>)",
        re.DOTALL | re.IGNORECASE,
    )
    match = pattern.search(old_body)
    version = dep["newVersion"]
    heading = version if version.startswith("v") else f"v{version}"
    if not match:
        block = (
            f"<details>\n<summary>{dep['depName']}</summary>\n\n"
            f"### {heading} changelog\n\n{notes}\n\n</details>"
        )
        existing = re.search(
            rf"<details>\s*<summary>[^\n]*{source}[^\n]*</summary>.*?</details>",
            old_body,
            re.DOTALL | re.IGNORECASE,
        )
        if existing:
            return old_body[: existing.start()] + block + old_body[existing.end() :]
        release_heading = "### Release Notes\n"
        if release_heading in old_body:
            return old_body.replace(release_heading, f"{release_heading}\n{block}\n", 1)
        configuration = re.search(r"^### Configuration\b", old_body, re.MULTILINE)
        position = configuration.start() if configuration else len(old_body)
        section = f"### Release Notes\n\n{block}\n\n---\n\n"
        return old_body[:position] + "\n" + section + old_body[position:]

    replacement = f"{match.group('head')}\n\n### {heading} changelog\n\n{notes}{match.group('end')}"
    return old_body[: match.start()] + replacement + old_body[match.end() :]


if __name__ == "__main__":
    pr_number = os.getenv("PR_NUMBER")
    if not pr_number:
        raise SystemExit("PR_NUMBER environment variable missing")

    body = fetch_pr_body(pr_number)
    selected = providers_for(extract_metadata(body))
    if not selected:
        log.warning("No supported dependency found")
        print(body)
        raise SystemExit(0)

    new_body = body
    for dep, provider in selected:
        notes = provider(dep)
        if not notes:
            log.warning(f"No changelog entries found for {dep['packageName']}")
            continue
        new_body = rewrite_body(new_body, dep, notes)

    print(new_body)
