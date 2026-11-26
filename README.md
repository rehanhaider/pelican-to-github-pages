# Deploy Pelican to Github Pages

Automated deployment of Pelican SSG generated static websites to GitHub Pages.

> **Maintenance mode.** This action is kept working for existing users and for the setups Pelican's own workflow does not cover: publishing to a branch, themes kept as git submodules, and running `npm install` for a theme. Starting a new site without those needs? Use Pelican's [official GitHub Pages workflow](https://docs.getpelican.com/en/latest/tips.html#publishing-to-github-pages-using-a-custom-github-actions-workflow) instead.

The action installs your `requirements.txt`, builds the site with `pelican`, and force-pushes the contents of the build folder to the root of a `gh-pages` branch, replacing what was there. GitHub Pages then serves that branch.

## Prerequisites
1. Your working directory should be in the `main` branch of your repository.
2. Ensure you have captured your dependencies in `requirements.txt`. If not you can run the below command
```bash
pip freeze > requirements.txt
```

The action runs Python 3.13, so freeze from a Python 3.11 or later environment: current Pelican needs 3.11 or later, and pins frozen on older Python may not install.

## Steps to use
First create a file named at the path `.github/workflows/pelican.yml`
The contents of the file should be
```yaml
name: Deploy

on:
  # Trigger the workflow on push on main branch,
  push:
    branches:
      - main

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v6
      with:
        submodules: 'true'
    - uses: rehanhaider/pelican-to-github-pages@v2.0.0
      env:
        GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        GH_PAGES_CNAME: ${{secrets.DOMAIN_CNAME}}
```

Then, setup a secrets in your repository named `DOMAIN_CNAME` that should contain the URL of your custom domain without the protocol, e.g. `example.com`. This is only required if you have a custom domain, if you want to use the `*.github.io` subdomain, then you don't need this.

After the first run, open **Settings → Pages** in your repository and set the source to **Deploy from a branch**, branch `gh-pages`, folder `/ (root)`.

## Default configuration and overrides
This GitHub action will generate the static website using the following defaults

| Setting | Default | What it does |
| --- | --- | --- |
| `PELICAN_CONFIG_FILE` | `publishconf.py` | Pelican settings file |
| `PELICAN_CONTENT_FOLDER` | `content` | Content folder |
| `PELICAN_THEME_FOLDER` | unset | Folder with a `package.json`; `npm install` runs there before the build |
| `GH_PAGES_BRANCH` | `gh-pages` | Branch the site is published to. It must not be the branch the workflow runs on, because the push replaces the branch. |
| `GH_PAGES_CNAME` | unset | Custom domain written to a `CNAME` file. Unset, empty, or `none` writes no file. |

Set any of them under `with:` or under `env:` in the pelican.yml file. When both are given, `env:` wins, and an empty value counts as unset.
```yaml
    - uses: rehanhaider/pelican-to-github-pages@v2.0.0
      env:
        GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
      with:
        PELICAN_CONFIG_FILE: config-file-name
        PELICAN_CONTENT_FOLDER: content-folder-name
```

The site is always built into `output/`: an `OUTPUT_PATH` in your settings file is ignored. The action also adds a `.nojekyll` file, so GitHub Pages serves the files as built instead of running Jekyll over them.

## Upgrading from v1
- `v1.1.0` to `v1.3.0` pushed the whole repository to `gh-pages` instead of the built site, and deleted the workflow's checkout `.git`. `v1.0.x` no longer builds, because its Node 12 package source is gone. Move to `v2.0.0`.
- Python moved from 3.7/3.8 to 3.13. Refresh `requirements.txt` if its pins do not install there.
- Settings given under `with:` now take effect; before, only `env:` did.
- No empty `CNAME` file is written when no domain is set, and `.nojekyll` is added.
- Workflows need `permissions: contents: write` when the repository's default token is read-only.

## Testing
`tests/run.sh` builds the image and runs it against the small site in `tests/fixture`, then checks what it pushed. Pushes go to a local repository, so nothing reaches GitHub. It needs Docker.
```bash
tests/run.sh
```
