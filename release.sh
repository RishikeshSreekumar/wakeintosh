#!/bin/sh
# Publishes a release: builds zip + dmg, creates the GitHub release, and updates
# the cask in RishikeshSreekumar/homebrew-tap.
# Usage: VERSION=1.1 ./release.sh
set -e
cd "$(dirname "$0")"

: "${VERSION:?Set VERSION, e.g. VERSION=1.1 ./release.sh}"
REPO="RishikeshSreekumar/wakeintosh"
TAP="RishikeshSreekumar/homebrew-tap"
export VERSION

if [ -n "$(git status --porcelain)" ]; then
    echo "Working tree not clean; commit first." >&2
    exit 1
fi

./package.sh

# Commit the cask's new version/sha, tag and push.
git add Casks/wakeintosh.rb
git diff --cached --quiet || git commit -m "Release v$VERSION"
git tag "v$VERSION"
git push origin HEAD "v$VERSION"

NOTES="$(mktemp)"
sed "s/{{VERSION}}/$VERSION/g" RELEASE_NOTES.md > "$NOTES"
gh release create "v$VERSION" -R "$REPO" --title "Wakeintosh $VERSION" --notes-file "$NOTES" \
    "dist/Wakeintosh-$VERSION.dmg" "dist/Wakeintosh-$VERSION.zip"

# Update the cask in the tap, committed as this repo's git identity.
NAME="$(git config user.name)"
EMAIL="$(git config user.email)"
SHA=$(gh api "repos/$TAP/contents/Casks/wakeintosh.rb" --jq .sha 2>/dev/null || true)
gh api -X PUT "repos/$TAP/contents/Casks/wakeintosh.rb" \
    -f message="Brew cask update for wakeintosh version v$VERSION" \
    -f content="$(base64 -i Casks/wakeintosh.rb)" \
    -f "author[name]=$NAME" -f "author[email]=$EMAIL" \
    -f "committer[name]=$NAME" -f "committer[email]=$EMAIL" \
    ${SHA:+-f sha="$SHA"} >/dev/null

echo "Released v$VERSION"
echo "https://github.com/$REPO/releases/tag/v$VERSION"
