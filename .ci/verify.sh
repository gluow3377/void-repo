#!/bin/bash
set -euo pipefail

url=${1:?usage: .ci/verify.sh URL SITEDIR}
dir=${2:?usage: .ci/verify.sh URL SITEDIR}
cd "$dir"
mapfile -t files < <(find . -type f -printf '%P\n' | LC_ALL=C sort)

for try in 1 2 3 4 5 6; do
    bad=()
    for f in "${files[@]}"; do
        remote=$(curl -fsSL "$url/$f?$(date +%s%N)" | sha256sum) || remote=
        if [ "$remote" != "$(sha256sum < "$f")" ]; then bad+=("$f"); fi
    done
    if (( ${#bad[@]} == 0 )); then
        echo "$url serves all ${#files[@]} files of $dir"
        exit 0
    fi
    echo "Try $try: $url differs for ${bad[*]}"
    sleep 20
done
exit 1
