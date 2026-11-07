#!/bin/sh
set -eu
export LC_ALL=C

repo=${1:?usage: .ci/site.sh REPODIR SITEDIR BASEPATH}
site=${2:?usage: .ci/site.sh REPODIR SITEDIR BASEPATH}
base=${3:?usage: .ci/site.sh REPODIR SITEDIR BASEPATH}
now=$(date -u '+%d-%b-%Y %H:%M')

dates=$(mktemp)
trap 'rm -f "$dates"' EXIT
if [ -f "$repo/index.html" ]; then
    sed -n 's|^<a href="\([^"/]*\)">.*</a> *\([0-9][0-9]-[A-Z][a-z][a-z]-[0-9]\{4\} [0-9][0-9]:[0-9][0-9]\) .*|\1 \2|p' \
        "$repo/index.html" > "$dates"
fi

row() {
    if [ ${#1} -gt 50 ]; then
        shown="$(printf '%.47s' "$1")..&gt;"
        pad=' '
    else
        shown=$1
        pad=$(printf '%-51s|' "$1")
        pad=${pad#"$1"}
        pad=${pad%|}
    fi
    printf '<a href="%s">%s</a>%s%s %19s\n' "$1" "$shown" "$pad" "$2" "$3"
}

page() {
    printf '<html>\n<head><title>Index of %s</title></head>\n<body>\n<h1>Index of %s</h1><hr><pre>' "$1" "$1"
}

rm -rf "$site"
mkdir -p "$site/current"
cp "$repo"/*.xbps "$repo"/*.xbps.sig2 "$repo"/*-repodata "$site/current/"

{
    page "$base/"
    row current/ "$now" -
    printf '</pre><hr></body>\n</html>\n'
} > "$site/index.html"

{
    page "$base/current/"
    printf '<a href="../">../</a>\n'
    for f in $(find "$site/current" -maxdepth 1 -type f ! -name index.html -printf '%f\n' | sort); do
        when=
        case $f in
            *-repodata) ;;
            *) when=$(awk -v f="$f" '$1 == f { print $2, $3; exit }' "$dates") ;;
        esac
        row "$f" "${when:-$now}" "$(stat -c %s "$site/current/$f")"
    done
    printf '</pre><hr></body>\n</html>\n'
} > "$site/current/index.html"
