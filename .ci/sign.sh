#!/bin/sh
set -eu

dir=${1:?usage: .ci/sign.sh REPODIR}
: "${XBPS_PRIVKEY:?XBPS_PRIVKEY is not set}"
: "${XBPS_SIGNEDBY:?XBPS_SIGNEDBY is not set}"

set -- "$dir"/*.xbps
if [ ! -e "$1" ]; then
    echo "sign.sh: no packages in $dir" >&2
    exit 1
fi

key=$(mktemp)
trap 'rm -f "$key"' EXIT
printf '%s\n' "$XBPS_PRIVKEY" > "$key"

xbps-rindex --sign --signedby "$XBPS_SIGNEDBY" --privkey "$key" "$dir"
for pkg; do
    if [ -e "$pkg.sig2" ]; then
        xbps-rindex --sign-pkg --force --privkey "$key" "$pkg"
    else
        xbps-rindex --sign-pkg --privkey "$key" "$pkg"
    fi
done
