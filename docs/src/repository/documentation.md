# Documentation site

The README introduces the repository. These pages provide the longer architecture and workflow guides.
The site is built with [Zensical](https://zensical.org/docs/get-started/) from Markdown in `docs/src/`.

## Preview locally

From the repository root, create an isolated Python environment and install the pinned builder:

```fish
python3 -m venv .venv-docs
.venv-docs/bin/python -m pip install -r docs/requirements.txt
.venv-docs/bin/zensical serve
```

Open the local URL printed by the server. Changes to documentation rebuild the preview.
The commands work in fish on macOS and Linux without activating the environment.

To check a production build:

```fish
.venv-docs/bin/zensical build --clean --strict
git diff --check
```

The generated site is written to `site/`. Both `.venv-docs/` and build output are excluded from Git.

## Publish to GitHub Pages

The workflow at `.github/workflows/docs.yaml` builds documentation on pull requests and pushes to `main`.
Only pushes to `main`, or a manual run from `main`, deploy the site.
Pull-request jobs have read-only repository permissions and do not publish.

To enable publishing after these files are merged:

1. Open the repository's **Settings → Pages**.
2. Set **Build and deployment → Source** to **GitHub Actions**.
3. Run the **Documentation** workflow from `main`, or merge a documentation change into `main`.
4. Check the deployment URL returned by the workflow.

The configured project URL is `https://snoopy82481.github.io/home-cluster/`.
This is the intended address; adding the files does not activate Pages or establish that the site is deployed.
See [GitHub's custom workflow guide](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages) for the Pages deployment model.

## Add a page

1. Create a Markdown file under `docs/src/`.
2. Add it to the `nav` list in `zensical.toml`.
3. Link to other documentation with relative Markdown paths.
4. Build locally and check the rendered page before opening a pull request.

Use repository-relative code paths when referring to configuration, or link to the repository source when a clickable reference is useful.
Configuration outside `docs/src/` is not copied into the published site.

The builder supports Mermaid code fences. The existing network diagram uses local images;
HTML page URLs are configured without directory suffixes so its `images/` paths resolve beside the page.
Diagram-source Python files are excluded from publication.

## Keep content accurate

Document verified behavior and distinguish planned work from deployed configuration.
Keep secrets, generated node configuration, and resolved templates out of the documentation tree.
For application-specific runbooks, keep the authoritative notes beside the application configuration and link to them from the site.

When changing the builder version, update `docs/requirements.txt` and run a clean build.
