#!/usr/bin/env bash
# upload.sh - Upload files to github.com/amittal2026/file_upload
#
# Collaborators: files are committed directly to the repository.
# Everyone else: files go to your fork and a pull request is opened for review.
#
# Requires: git (https://git-scm.com) and GitHub CLI (https://cli.github.com)
#
# Usage: ./upload.sh [-d folder] [-m "message"] FILE_OR_FOLDER [MORE ...]

set -euo pipefail

REPO="amittal2026/file_upload"
MAX_BYTES=$((100 * 1024 * 1024))   # GitHub rejects files over 100 MB
WARN_BYTES=$((50 * 1024 * 1024))

usage() {
  cat <<EOF
Usage: $(basename "$0") [-d folder] [-m "message"] FILE_OR_FOLDER [MORE ...]

  -d folder   Folder in the repository to upload into (default: repository root)
  -m message  Short description of the upload (default: "Upload N item(s)")
  -h          Show this help

Examples:
  $(basename "$0") report.pdf
  $(basename "$0") -d acme-ltd -m "Q3 documents" report.pdf scans/
EOF
}

die()  { echo "Error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

DEST=""
MSG=""
while getopts ":d:m:h" opt; do
  case $opt in
    d) DEST="${OPTARG#/}"; DEST="${DEST%/}" ;;
    m) MSG="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))
[ $# -gt 0 ] || { usage; exit 1; }

command -v git >/dev/null 2>&1 || die "git is not installed. Get it from https://git-scm.com/downloads"
command -v gh  >/dev/null 2>&1 || die "GitHub CLI (gh) is not installed. Get it from https://cli.github.com"

# --- Check inputs and file sizes -------------------------------------------
ITEMS=()
for p in "$@"; do
  [ -e "$p" ] || die "Not found: $p"
  [ "$p" = "/" ] || p="${p%/}"
  ITEMS+=("$(cd "$(dirname "$p")" && pwd)/$(basename "$p")")   # absolute path
done

while IFS= read -r -d '' f; do
  size=$(( $(wc -c < "$f") ))
  if [ "$size" -gt "$MAX_BYTES" ]; then
    die "$f is larger than 100 MB, which GitHub does not accept. Split it into smaller parts or contact the repository owner."
  elif [ "$size" -gt "$WARN_BYTES" ]; then
    echo "Warning: $f is over 50 MB; the upload may be slow." >&2
  fi
done < <(find "${ITEMS[@]}" -type f -print0)

[ -n "$MSG" ] || MSG="Upload ${#ITEMS[@]} item(s)"

# --- Sign in to GitHub (first run only) ------------------------------------
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  info "Sign in to GitHub (one-time). Follow the prompts."
  gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git --hostname github.com >/dev/null 2>&1 || true

ME=$(gh api user --jq .login)
MY_ID=$(gh api user --jq .id)
BASE=$(gh api "repos/$REPO" --jq .default_branch) || die "Can't access $REPO. Check the repository name and your access."
CAN_PUSH=$(gh api "repos/$REPO" --jq '.permissions.push // false')

# --- Prepare a temporary working copy --------------------------------------
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
R="$WORK/repo"

info "Preparing upload..."
# Partial, sparse clone: downloads history metadata, not every existing file.
git clone --quiet --filter=blob:none --sparse "https://github.com/$REPO.git" "$R"
git -C "$R" config user.name "$ME"
git -C "$R" config user.email "$MY_ID+$ME@users.noreply.github.com"
git -C "$R" config core.autocrlf false   # keep files byte-for-byte identical

TARGET="$R"
if [ -n "$DEST" ]; then
  git -C "$R" sparse-checkout add "$DEST"
  TARGET="$R/$DEST"
else
  for item in "${ITEMS[@]}"; do
    [ -d "$item" ] && git -C "$R" sparse-checkout add "$(basename "$item")"
  done
fi
mkdir -p "$TARGET"

for item in "${ITEMS[@]}"; do
  cp -R "$item" "$TARGET/"
done

git -C "$R" add -A
if git -C "$R" diff --cached --quiet; then
  die "Nothing to upload: these files are already in the repository, unchanged."
fi
git -C "$R" commit --quiet -m "$MSG"

# --- Upload ----------------------------------------------------------------
if [ "$CAN_PUSH" = "true" ]; then
  info "Uploading directly (you are a collaborator)..."
  if ! git -C "$R" push --quiet origin "HEAD:$BASE"; then
    # Someone else uploaded in the meantime: catch up and try again.
    git -C "$R" pull --quiet --rebase origin "$BASE"
    git -C "$R" push --quiet origin "HEAD:$BASE"
  fi
  echo
  echo "Done. Your files are at: https://github.com/$REPO/tree/$BASE${DEST:+/$DEST}"
else
  info "Submitting for review via your fork..."
  FORK=$(gh api -X POST "repos/$REPO/forks" --jq .full_name)   # returns the existing fork if you have one
  FORK_OWNER="${FORK%%/*}"
  gh repo sync "$FORK" --branch "$BASE" >/dev/null 2>&1 || true   # best effort; fine if it fails

  BRANCH="upload-$(date +%Y%m%d-%H%M%S)"
  git -C "$R" remote add fork "https://github.com/$FORK.git"

  # A brand-new fork can take a few seconds to become ready.
  pushed=false
  for _ in 1 2 3 4 5 6; do
    if git -C "$R" push --quiet fork "HEAD:refs/heads/$BRANCH" 2>/dev/null; then pushed=true; break; fi
    sleep 5
  done
  $pushed || die "Could not upload to your fork ($FORK). Please try again in a minute."

  PR_URL=$(gh pr create --repo "$REPO" --base "$BASE" --head "$FORK_OWNER:$BRANCH" \
    --title "$MSG" \
    --body "Files submitted by @$ME using upload.sh${DEST:+ (folder: \`$DEST\`)}.")
  echo
  echo "Done. Your files were submitted for review: $PR_URL"
  echo "They'll appear in the repository once the owner approves them."
fi
