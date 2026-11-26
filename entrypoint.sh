#!/bin/bash

set -e

echo "REPO: $GITHUB_REPOSITORY"
echo "ACTOR: $GITHUB_ACTOR"

remote_repo="https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
remote_branch=${GH_PAGES_BRANCH:=gh-pages}

echo 'Installing 🐍 Python Requirements'
pip install -r requirements.txt

if [ -n "$PELICAN_THEME_FOLDER" ]; then
    echo 'Installing Node Modules 🧰 '
    pushd $PELICAN_THEME_FOLDER
    npm install
    popd
fi

echo 'Building site 👷 '
pelican ${PELICAN_CONTENT_FOLDER:=content} -o output -s ${PELICAN_CONFIG_FILE:=publishconf.py}

echo "Setting Git safe directory (CVE-2022-24765)"
echo "git config --global --add safe.directory ${GITHUB_WORKSPACE}"
git config --global --add safe.directory "${GITHUB_WORKSPACE}"

echo 'Publishing to GitHub Pages 📤 '
echo 'change into output directory'
pushd output
git init
git remote add deploy "$remote_repo"
git checkout $remote_branch || git checkout --orphan $remote_branch
git config user.name "${GITHUB_ACTOR}"
git config user.email "${GITHUB_ACTOR}@users.noreply.github.com"
if [ "$GH_PAGES_CNAME" != "none" ]
then
    echo "$GH_PAGES_CNAME" > CNAME
fi
git add .

echo -n 'Files to Commit:' && ls -l | wc -l
git commit -m "[ci skip] Automated deployment to GitHub Pages on $(date +%s%3N)"
git push deploy $remote_branch --force
rm -fr .git
echo 'leave output directory'
popd

echo 'Successfully 🎉🕺💃 🎉 deployed to interwebs 🕸'
