#!/usr/bin/env bash
# Prints the end of a log file as ONE GitHub annotation, so the result can be read
# through the public API without logging in. Usage: annotate.sh <file> <title> [level]
set -u
file="$1"
title="$2"
level="${3:-error}"
[ -s "$file" ] || exit 0
# Keep the last ~55 KB (annotation limit is 64 KB) and strip the runner's path prefix.
content=$(tail -c 55000 "$file" | sed -e "s#${GITHUB_WORKSPACE:-/nonexistent}/##g")
content="${content//'%'/'%25'}"
content="${content//$'\r'/'%0D'}"
content="${content//$'\n'/'%0A'}"
echo "::${level} title=${title}::${content}"
