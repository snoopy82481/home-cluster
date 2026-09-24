import json
from pathlib import Path
import subprocess
import unittest

import yaml

from .main import extract_metadata, providers_for, rewrite_body


KUBERNETES_IMAGES = [
    "registry.k8s.io/kube-apiserver",
    "registry.k8s.io/kube-controller-manager",
    "registry.k8s.io/kube-proxy",
    "registry.k8s.io/kube-scheduler",
]


class EligibilityTests(unittest.TestCase):
    def test_workflow_package_detection(self):
        workflow_path = Path(__file__).resolve().parents[2] / "workflows/changelog.yaml"
        workflow = yaml.safe_load(workflow_path.read_text())
        script = workflow["jobs"]["check-package"]["steps"][0]["with"]["script"]
        cases = [(image, True) for image in KUBERNETES_IMAGES] + [
            ("ghcr.io/siderolabs/kubelet", True),
            ("ghcr.io/atuinsh/atuin", True),
            ("[kubelet](https://redirect.github.com/siderolabs/kubelet)", True),
            ("registry.k8s.io/kube-apiserver-other", False),
            ("ghcr.io/other/image", False),
        ]
        for package, expected in cases:
            with self.subTest(package=package):
                body = f"| {package} | patch | `v1.37.0` → `v1.37.1` |"
                context = {"payload": {"pull_request": {"body": body}}}
                harness = (
                    f"const context = {json.dumps(context)};\n"
                    "const core = {setOutput: (key, value) => console.log(JSON.stringify(value)), info: () => {}};\n"
                    + script
                )
                result = subprocess.check_output(["node", "-e", harness], text=True)
                self.assertEqual(json.loads(result), expected)


class RewriteTests(unittest.TestCase):
    def test_plain_kubernetes_group_without_release_notes(self):
        body = "\n".join(
            f"| {image} | patch | `v1.37.0` → `v1.37.1` |"
            for image in KUBERNETES_IMAGES
        ) + "\n\n### Configuration\n\nKeep this configuration.\n"
        deps = extract_metadata(body)
        self.assertEqual(len(deps), 1)
        dep = deps[0]
        self.assertEqual(dep["packageName"], "kubernetes/kubernetes")
        self.assertEqual(dep["currentVersion"], "v1.37.0")
        self.assertEqual(dep["newVersion"], "v1.37.1")
        self.assertEqual(len(providers_for(deps)), 1)
        result = rewrite_body(body, dep, "- Kubernetes fixes")
        self.assertEqual(result.count("<details>"), 1)
        self.assertIn("### v1.37.1 changelog\n\n- Kubernetes fixes", result)
        self.assertTrue(result.endswith("### Configuration\n\nKeep this configuration.\n"))
        self.assertEqual(rewrite_body(result, dep, "- Kubernetes fixes"), result)

    def test_each_plain_kubernetes_image(self):
        for image in KUBERNETES_IMAGES + ["ghcr.io/siderolabs/kubelet"]:
            with self.subTest(image=image):
                deps = extract_metadata(f"| {image} | patch | `v1.37.0` -> `v1.37.1` |")
                self.assertEqual(len(providers_for(deps)), 1)

    def test_plain_atuin_without_release_notes(self):
        body = (
            "| ghcr.io/atuinsh/atuin | minor | `18.21.0` → `18.22.0` |\n"
            "\n---\n\n### Configuration\n\nKeep this configuration.\n"
        )
        dep = extract_metadata(body)[0]
        self.assertEqual(dep["packageName"], "atuinsh/atuin")
        self.assertEqual(dep["newVersion"], "18.22.0")
        self.assertEqual(len(providers_for([dep])), 1)
        result = rewrite_body(body, dep, "- New feature")
        self.assertIn("### v18.22.0 changelog\n\n- New feature", result)
        self.assertTrue(result.endswith("### Configuration\n\nKeep this configuration.\n"))
        self.assertEqual(rewrite_body(result, dep, "- New feature"), result)
        updated = rewrite_body(result, dep, "- Updated feature")
        self.assertNotIn("- New feature", updated)
        self.assertEqual(updated.count("<details>"), 1)

    def test_linked_package_preserves_other_release_notes(self):
        body = (
            "| [cloudflared](https://redirect.github.com/cloudflare/cloudflared) | minor | `1` → `2` |\n"
            "### Release Notes\n\n"
            "<details>\n<summary>other/project</summary>\nOther notes\n</details>\n"
            "<details>\n<summary>cloudflare/cloudflared</summary>\n"
            "[Compare Source](https://github.com/cloudflare/cloudflared/compare/1...2)\n"
            "Old notes\n</details>\n"
        )
        result = rewrite_body(body, extract_metadata(body)[0], "New notes")
        self.assertIn("Other notes", result)
        self.assertNotIn("Old notes", result)
        self.assertIn("[Compare Source]", result)
        self.assertEqual(result.count("<details>"), 2)

    def test_unknown_plain_image_is_ignored(self):
        self.assertEqual(extract_metadata("| ghcr.io/other/image | minor | `1` → `2` |"), [])
        self.assertEqual(extract_metadata("| registry.k8s.io/kube-apiserver-other | patch | `1` → `2` |"), [])


if __name__ == "__main__":
    unittest.main()
