#!/bin/sh
# Uso: ./start.sh <usuario/repo | link de GitHub | link de DeepWiki> [--lang <idioma>]
set -eu

if [ $# -lt 1 ]; then
  echo "Uso: ./start.sh <usuario/repo | link de GitHub | link de DeepWiki> [--lang <idioma>]" >&2
  exit 1
fi

input=$1
shift

# Normalizar a usuario/repo: quitar query/fragment, "/" final y ".git"
input=${input%%\?*}
input=${input%%\#*}
input=${input%/}
input=${input%.git}

case "$input" in
  *github.com/*) input=${input#*github.com/} ;;
  *deepwiki.com/*) input=${input#*deepwiki.com/} ;;
esac

user=${input%%/*}
rest=${input#*/}
repo=${rest%%/*}
slug="$user/$repo"

case "$slug" in
  */*/*|*//*|/*|*/) echo "Error: no pude extraer usuario/repo de '$1'." >&2; exit 1 ;;
esac
if [ "$user" = "$input" ] || [ -z "$user" ] || [ -z "$repo" ]; then
  echo "Error: se esperaba <usuario/repo>, link de GitHub o link de DeepWiki." >&2
  exit 1
fi

name=$repo

npx tsx src/index.ts "$slug" --output "$name.pdf" "$@"
cp deepwiki.md "$name.txt"
echo "Generados: $name.txt y $name.pdf"
