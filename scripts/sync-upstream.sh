#!/usr/bin/env bash
# Локальный синк форка с апстримом (rebase-стратегия).
#   ./sync-upstream.sh          — подтянуть апстрим и перебазировать ветку fork
#   ./sync-upstream.sh --dry    — только показать, что нового в апстриме
set -euo pipefail

UPSTREAM_URL="https://github.com/nikkinikki-org/OpenWrt-nikki.git"
UPSTREAM_BRANCH="main"
MIRROR_BRANCH="main"
FORK_BRANCH="fork"

cd "$(git rev-parse --show-toplevel)"

git remote get-url upstream >/dev/null 2>&1 || git remote add upstream "$UPSTREAM_URL"
git remote set-url --push upstream DISABLED
git config rerere.enabled true

echo "==> fetch"
git fetch --tags upstream "$UPSTREAM_BRANCH"
git fetch --tags origin

echo "==> новое в апстриме относительно $FORK_BRANCH:"
git log --oneline --no-merges "$FORK_BRANCH..upstream/$UPSTREAM_BRANCH" || true
echo "==> последний тег апстрима: $(git tag --list 'v*' --sort=-v:refname --merged "upstream/$UPSTREAM_BRANCH" | head -n 1)"

if [ "${1:-}" = "--dry" ]; then
  exit 0
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "!! рабочее дерево грязное — закоммитьте или спрячьте изменения (git stash)" >&2
  exit 1
fi

echo "==> зеркалим $MIRROR_BRANCH"
git checkout "$MIRROR_BRANCH"
git merge --ff-only "upstream/$UPSTREAM_BRANCH"
git push origin "$MIRROR_BRANCH"

echo "==> rebase $FORK_BRANCH"
git checkout "$FORK_BRANCH"
if git rebase "upstream/$UPSTREAM_BRANCH"; then
  git push --force-with-lease origin "$FORK_BRANCH"
  echo "==> готово"
else
  cat >&2 <<'EOF'
!! конфликт rebase. Действия:
     git status                 # посмотреть конфликтные файлы
     <править файлы>
     git add -A && git rebase --continue
     git push --force-with-lease origin fork
   Отменить всё:  git rebase --abort
EOF
  exit 1
fi
