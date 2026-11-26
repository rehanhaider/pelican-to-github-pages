#!/bin/bash
# Builds the action's image, runs it against tests/fixture, and checks what it
# pushes. Each push goes to a local bare repository, so nothing reaches GitHub.
# Needs Docker.
#
# The container gets the environment a runner gives a Docker action: GITHUB_*,
# plus INPUT_* for every input in action.yml, at its default unless a case
# overrides it.
#
# Optional: WHEELHOUSE=/path/to/wheels installs the Python packages from that
# folder instead of PyPI.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
image="${IMAGE:-pelican-to-github-pages:test}"
work="$(mktemp -d)"
failures=0

cleanup() {
    # The container runs as root, so it leaves root-owned files: remove them from inside one.
    docker run --rm -v "$work:/work" --entrypoint rm "$image" -rf /work/cases /work/pip-cache >/dev/null 2>&1 || true
    rm -rf "$work"
}
trap cleanup EXIT

echo "Building $image"
docker build -q -t "$image" "$root" >/dev/null

pip_args=(-v "$work/pip-cache:/root/.cache/pip")
if [ -n "${WHEELHOUSE:-}" ]; then
    pip_args+=(-v "$WHEELHOUSE:/wheels:ro" -e PIP_NO_INDEX=1 -e PIP_FIND_LINKS=/wheels)
fi

# run_case <name> [docker run options]
run_case() {
    local name=$1
    shift
    local dir="$work/cases/$name"
    mkdir -p "$dir"
    cp -a "$root/tests/fixture" "$dir/ws"
    git -C "$dir/ws" init -q -b main
    git -C "$dir/ws" add -A
    git -C "$dir/ws" -c user.name=test -c user.email=test@example.invalid commit -qm fixture
    git init -q --bare "$dir/remote.git"
    # git in the container runs as root and refuses a repository root does not own.
    docker run --rm -v "$dir:/case" --entrypoint chown "$image" -R 0:0 /case/remote.git

    local status=0
    docker run --rm \
        -v "$dir/ws:/github/workspace" -v "$dir/remote.git:/remote.git" -w /github/workspace \
        -e GITHUB_WORKSPACE=/github/workspace -e GITHUB_REPOSITORY=owner/site \
        -e GITHUB_ACTOR=tester -e GITHUB_TOKEN=dummy-token -e GITHUB_REF_NAME=main \
        -e INPUT_GH_PAGES_BRANCH=gh-pages -e INPUT_GH_PAGES_CNAME=none \
        -e INPUT_PELICAN_CONFIG_FILE=publishconf.py -e INPUT_PELICAN_CONTENT_FOLDER=content \
        -e INPUT_PELICAN_THEME_FOLDER= \
        -e GIT_CONFIG_COUNT=1 \
        -e GIT_CONFIG_KEY_0=url./remote.git.insteadOf \
        -e GIT_CONFIG_VALUE_0=https://x-access-token:dummy-token@github.com/owner/site.git \
        -e PIP_DISABLE_PIP_VERSION_CHECK=1 -e PIP_ROOT_USER_ACTION=ignore \
        "${pip_args[@]}" "$@" "$image" >"$dir/log.txt" 2>&1 || status=$?
    echo "$status" >"$dir/status"
    echo "--- $name (exit $status)"
}

remote() { git -c safe.directory='*' -C "$work/cases/$1/remote.git" "${@:2}"; }
status_of() { cat "$work/cases/$1/status"; }
branches() { remote "$1" for-each-ref --format='%(refname:short)' refs/heads | tr '\n' ' ' | sed 's/ $//'; }
has() { remote "$1" cat-file -e "$2:$3" 2>/dev/null; }
lacks() { ! has "$@"; }
cname_is() { [ "$(remote "$1" show "$2:CNAME")" = "$3" ]; }
no_token_in_log() { ! grep -q dummy-token "$work/cases/$1/log.txt"; }
check() {
    local description=$1
    shift
    if "$@"; then
        echo "ok   $description"
    else
        echo "FAIL $description"
        failures=$((failures + 1))
    fi
}
show_log_on_failure() {
    if [ "$failures" -ne "$1" ]; then
        tail -40 "$work/cases/$2/log.txt"
    fi
}

before=$failures
run_case default
check "succeeds" [ "$(status_of default)" = 0 ]
check "pushes only gh-pages" [ "$(branches default)" = gh-pages ]
check "publishes the site at the branch root" has default gh-pages index.html
check "publishes the article" has default gh-pages hello.html
check "publishes static files" has default gh-pages static/_jekyll_probe.txt
check "builds into output/ despite OUTPUT_PATH" lacks default gh-pages public
check "adds .nojekyll" has default gh-pages .nojekyll
check "does not publish the source" lacks default gh-pages pelicanconf.py
check "does not publish requirements.txt" lacks default gh-pages requirements.txt
check "writes no CNAME when the input is none" lacks default gh-pages CNAME
check "keeps the workflow checkout's .git" [ -d "$work/cases/default/ws/.git" ]
check "removes the deploy repository and its token" [ ! -e "$work/cases/default/ws/output/.git" ]
check "does not print the token" no_token_in_log default
show_log_on_failure "$before" default

before=$failures
run_case cname-env -e GH_PAGES_CNAME=example.com
check "env CNAME succeeds" [ "$(status_of cname-env)" = 0 ]
check "env CNAME is written" cname_is cname-env gh-pages example.com
show_log_on_failure "$before" cname-env

before=$failures
run_case cname-input -e GH_PAGES_CNAME= -e INPUT_GH_PAGES_CNAME=example.org
check "input CNAME succeeds" [ "$(status_of cname-input)" = 0 ]
check "empty env falls through to the input" cname_is cname-input gh-pages example.org
show_log_on_failure "$before" cname-input

before=$failures
run_case cname-unset -e INPUT_GH_PAGES_CNAME=
check "unset CNAME succeeds" [ "$(status_of cname-unset)" = 0 ]
check "writes no CNAME when nothing is set" lacks cname-unset gh-pages CNAME
show_log_on_failure "$before" cname-unset

before=$failures
run_case branch-input -e INPUT_GH_PAGES_BRANCH=site
check "branch input succeeds" [ "$(status_of branch-input)" = 0 ]
check "publishes to the branch given under with:" [ "$(branches branch-input)" = site ]
show_log_on_failure "$before" branch-input

before=$failures
run_case env-wins -e GH_PAGES_BRANCH=from-env -e INPUT_GH_PAGES_BRANCH=site
check "env over input succeeds" [ "$(status_of env-wins)" = 0 ]
check "env wins over with:" [ "$(branches env-wins)" = from-env ]
show_log_on_failure "$before" env-wins

run_case same-branch -e INPUT_GH_PAGES_BRANCH=main
check "refuses to publish to the branch being built" [ "$(status_of same-branch)" != 0 ]
check "pushes nothing when it refuses" [ -z "$(branches same-branch)" ]

run_case push-fails -e GIT_CONFIG_KEY_0=url./nonexistent.git.insteadOf
check "fails when the push fails" [ "$(status_of push-fails)" != 0 ]
check "still removes the deploy repository and its token" [ ! -e "$work/cases/push-fails/ws/output/.git" ]

before=$failures
run_case theme -e INPUT_PELICAN_THEME_FOLDER=theme
check "theme folder succeeds" [ "$(status_of theme)" = 0 ]
check "runs npm install in the theme folder" [ -f "$work/cases/theme/ws/theme/package-lock.json" ]
show_log_on_failure "$before" theme

if [ "$failures" -ne 0 ]; then
    echo "$failures check(s) failed"
    exit 1
fi
echo "All checks passed"
