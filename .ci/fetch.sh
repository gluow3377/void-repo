#!/bin/sh
set -eu

url=${1:?usage: .ci/fetch.sh URL DIR}
dir=${2:?usage: .ci/fetch.sh URL DIR}
arch=$(xbps-uhelper arch)
nocache="?$(date +%s)"

mkdir -p "$dir"
index=$(mktemp -d)
trap 'rm -rf "$index"' EXIT

if ! xbps-fetch -o "$index/$arch-repodata" "$url/$arch-repodata$nocache" 2> "$index/error"; then
    if grep -q "Not Found" "$index/error"; then
        echo "Nothing is published at $url yet: starting from an empty repository."
        exit 0
    fi
    cat "$index/error" >&2
    exit 1
fi

xbps-fetch -o "$dir/index.html" "$url/index.html$nocache" > /dev/null 2>&1 || rm -f "$dir/index.html"

n=0
for pkgver in $(xbps-query -i --repository="$index" -s '' | awk '{ print $2 }'); do
    for f in "$pkgver.$arch.xbps" "$pkgver.$arch.xbps.sig2"; do
        if xbps-fetch -o "$dir/$f" "$url/$f$nocache" > /dev/null; then
            n=$((n + 1))
        else
            rm -f "$dir/$f"
        fi
    done
done
echo "Downloaded $n published files."
