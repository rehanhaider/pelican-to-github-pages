#!/bin/bash

set -e

# Each setting comes from the step's `env:` first, then from its `with:` inputs,
# which the runner passes as INPUT_*. An empty value counts as unset, so an
# unset secret falls through to the input or the default.
GH_PAGES_BRANCH="${GH_PAGES_BRANCH:-${INPUT_GH_PAGES_BRANCH:-gh-pages}}"
GH_PAGES_CNAME="${GH_PAGES_CNAME:-${INPUT_GH_PAGES_CNAME:-}}"
PELICAN_CONFIG_FILE="${PELICAN_CONFIG_FILE:-${INPUT_PELICAN_CONFIG_FILE:-publishconf.py}}"
PELICAN_CONTENT_FOLDER="${PELICAN_CONTENT_FOLDER:-${INPUT_PELICAN_CONTENT_FOLDER:-content}}"
PELICAN_THEME_FOLDER="${PELICAN_THEME_FOLDER:-${INPUT_PELICAN_THEME_FOLDER:-}}"

echo "REPO: $GITHUB_REPOSITORY"
echo "ACTOR: $GITHUB_ACTOR"

# The deploy force-pushes, so publishing to the branch being built would replace
# the site's source with its output.
if [ "$GH_PAGES_BRANCH" = "${GITHUB_REF_NAME:-}" ]; then
    echo "::error::GH_PAGES_BRANCH is '$GH_PAGES_BRANCH', the branch this workflow runs on. Publishing there would overwrite the source with the built site."
    exit 1
fi

remote_repo="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
remote_branch="$GH_PAGES_BRANCH"
output_dir="$PWD/output"

# The deploy repository's config holds the token: remove it however the script exits.
trap 'rm -rf "$output_dir/.git"' EXIT

echo 'Installing 🐍 Python Requirements'
pip install -r requirements.txt

if [ -n "$PELICAN_THEME_FOLDER" ]; then
    echo 'Installing Node Modules 🧰 '
    pushd "$PELICAN_THEME_FOLDER"
    npm install
    popd
fi

echo 'Building site 👷 '
pelican "$PELICAN_CONTENT_FOLDER" -o output -s "$PELICAN_CONFIG_FILE"

echo "Setting Git safe directory (CVE-2022-24765)"
git config --global --add safe.directory "$output_dir"

echo 'Publishing to GitHub Pages 📤 '
echo 'change into output directory'
pushd output
git init
git remote add deploy "$remote_repo"
git checkout "$remote_branch" || git checkout --orphan "$remote_branch"
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
if [ -n "$GH_PAGES_CNAME" ] && [ "$GH_PAGES_CNAME" != "none" ]
then
    echo "$GH_PAGES_CNAME" > CNAME
fi
# Without this, Pages runs Jekyll over the site and drops paths starting with "_".
touch .nojekyll
git add .

echo "Files to Commit: $(git ls-files | wc -l)"
git commit -m "[ci skip] Automated deployment to GitHub Pages on $(date +%s%3N)"
git push deploy "$remote_branch" --force
rm -fr .git
echo 'leave output directory'
popd

echo 'Successfully 🎉🕺💃 🎉 deployed to interwebs 🕸'
