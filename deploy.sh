#!/usr/bin/env bash
#
# Deploy this site to https://jackchuang.github.io
#
# Run this on YOUR machine, with YOUR GitHub credentials. It never asks you
# for a token — it uses the auth you already have (gh CLI or your SSH key).
#
#   chmod +x deploy.sh && ./deploy.sh
#
set -euo pipefail

USER="JackChuang"
REPO="JackChuang.github.io"
URL="https://jackchuang.github.io/"

say()  { printf '\n\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
die()  { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

# --- sanity checks --------------------------------------------------------
[[ -f _config.yml && -d _includes ]] || die "run this from inside the site folder (the one with _config.yml)"

grep -q 'pWhK' _includes/counters.html \
  || die "_includes/counters.html has lost the Flag Counter id — stop and restore it before publishing"
# The ClustrMaps widget is no longer on the page, but its d= hash is kept in a
# comment in that file and cannot be regenerated, so this guard stays.
grep -q 'VQmG81oa9' _includes/counters.html \
  || die "_includes/counters.html has lost the ClustrMaps hash — stop and restore it before publishing"
say "✓ visitor counter ids intact (Flag Counter pWhK live, ClustrMaps 1bgq9 archived)"

command -v git >/dev/null || die "git not found"

# --- confirm --------------------------------------------------------------
say "About to publish to a PUBLIC repository:"
echo "    github.com/$USER/$REPO   ->   $URL"
echo
read -r -p "Continue? [y/N] " reply
[[ "$reply" =~ ^[Yy]$ ]] || { echo "aborted."; exit 0; }

# --- commit ---------------------------------------------------------------
if [[ ! -d .git ]]; then
  git init -b main
else
  git checkout -B main
fi
git add -A
git diff --cached --quiet || git commit -m "Port personal site from blogs.tlos.vt.edu to GitHub Pages"

# --- create + push --------------------------------------------------------
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  say "Using the gh CLI (already authenticated)"

  if gh repo view "$USER/$REPO" >/dev/null 2>&1; then
    git remote get-url origin >/dev/null 2>&1 \
      || git remote add origin "https://github.com/$USER/$REPO.git"
    git push -u origin main
  else
    gh repo create "$REPO" --public --source=. --remote=origin --push
  fi

  say "Enabling GitHub Pages"
  gh api --method POST "repos/$USER/$REPO/pages" \
      -H "Accept: application/vnd.github+json" \
      -f "source[branch]=main" -f "source[path]=/" 2>/dev/null \
    || warn "Pages may already be enabled — check Settings → Pages if the site 404s."
else
  warn "gh CLI not found or not logged in."
  echo "Create the repo yourself first (it must be named exactly $REPO):"
  echo "    https://github.com/new?name=$REPO"
  echo "Then, with Pages set to branch 'main' / folder '(root)':"
  echo
  read -r -p "Repo created? Press Enter to push, or Ctrl-C to stop. "
  git remote get-url origin >/dev/null 2>&1 \
    || git remote add origin "git@github.com:$USER/$REPO.git"
  git push -u origin main
fi

# --- done -----------------------------------------------------------------
say "Pushed. First build takes 1–2 minutes."
cat <<EOF

  $URL

Then verify, in this order:

  1. All four visitor widgets render in the footer.
  2. The Flag Counter totals match the old site
     -> https://s01.flagcounter.com/more/pWhK
  3. The ClustrMaps map is NOT blank
     -> https://clustrmaps.com/site/1bgq9
     If it is blank, add jackchuang.github.io to the registered site there.

Then update the website field on your GitHub profile and LinkedIn, and leave a
forwarding note on the old blogs.tlos.vt.edu page — it cannot 301 for you.
EOF
