#!/bin/bash
set -euo pipefail
shopt -s nullglob extglob

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
OUT=$(realpath -m -- "${1:?usage: .ci/build.sh OUTDIR}")
REPO=$OUT/repo
VP=${VOID_PACKAGES:-/void-packages}
VP_URL=https://github.com/void-linux/void-packages
ARCH=$(xbps-uhelper arch)
MASTERDIR=$VP/masterdir-$ARCH

msg() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> WARNING:\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

unset XBPS_ALLOW_RESTRICTED

xsrc() {
    (cd "$VP" && sudo -E -u builder ./xbps-src -m "$MASTERDIR" "$@")
}

in_list() {
    local item=$1 x
    shift
    for x; do [ "$x" = "$item" ] && return 0; done
    return 1
}

arch_ok() {
    local archs=$1 f match='' nonegation=''
    [ -n "$archs" ] || return 0
    set -f
    for f in $archs; do
        nonegation=${f##\~*}
        f=${f#\~}
        if [[ $ARCH = @($f) ]]; then
            match=1
            break
        fi
    done
    set +f
    if [ -z "$nonegation" ] && [ -n "$match" ]; then return 1; fi
    if [ -n "$nonegation" ] && [ -z "$match" ]; then return 1; fi
    return 0
}

produced() {
    local name
    for name in "${!want[@]}"; do
        if [ "${owner[$name]}" = "$1" ] && [ -z "$(find "$bin" -name "${want[$name]}" -print -quit)" ]; then
            warn "$1: ${want[$name]} was not produced"
            return 1
        fi
    done
}

write_list() {
    local file=$1
    shift
    : > "$file"
    if (( $# )); then printf '%s\n' "$@" > "$file"; fi
}

[ "$(id -u)" -eq 0 ] || die "run this as root inside the build container"
rm -f "$OUT/ready"
mkdir -p "$REPO"

id builder >/dev/null 2>&1 || useradd -G xbuilder -M builder
if [ ! -d "$VP/.git" ]; then
    msg "Cloning void-packages"
    git clone --depth 1 "$VP_URL" "$VP"
fi
printf 'XBPS_CHROOT_CMD=uchroot\n' > "$VP/etc/conf"

templates=()
for dir in "$ROOT"/srcpkgs/*/; do
    name=${dir%/}
    name=${name##*/}
    [ -f "$ROOT/srcpkgs/$name/template" ] || continue
    rm -rf "${VP:?}/srcpkgs/$name"
    cp -RP "$ROOT/srcpkgs/$name" "$VP/srcpkgs/$name"
    [ -L "$ROOT/srcpkgs/$name" ] || templates+=("$name")
done
(( ${#templates[@]} )) || die "no templates in $ROOT/srcpkgs"
chown -R builder:builder "$VP"
msg "Templates: ${templates[*]}"

local_only=()
if [ -f "$ROOT/.ci/local-only" ]; then
    read -r -a local_only <<< "$(sed 's/#.*//' "$ROOT/.ci/local-only" | tr '\n' ' ')"
fi

declare -A want=() owner=()
queue=() skipped=()
for pkg in "${templates[@]}"; do
    if in_list "$pkg" "${local_only[@]}"; then
        skipped+=("$pkg: listed in .ci/local-only")
        continue
    fi
    vars=$(printf '%s\n' restricted version revision subpackages archs |
        xsrc show-pkg-var "$pkg" && echo .) || die "cannot read $pkg/template"
    mapfile -t v <<< "$vars"
    if (( ${#v[@]} != 6 )) || [ "${v[5]}" != . ]; then
        die "unexpected show-pkg-var output for $pkg: $vars"
    fi
    restricted=${v[0]} version=${v[1]} revision=${v[2]} subpackages=${v[3]}
    if [ -n "$restricted" ]; then
        skipped+=("$pkg: restricted=$restricted (not redistributable)")
        continue
    fi
    if ! arch_ok "${v[4]}"; then
        skipped+=("$pkg: archs=\"${v[4]}\" excludes $ARCH")
        continue
    fi
    missing=()
    for name in "$pkg" $subpackages; do
        want[$name]=$name-${version}_$revision.$ARCH.xbps
        owner[$name]=$pkg
        if [ ! -f "$REPO/${want[$name]}" ]; then
            missing+=("${want[$name]}")
        fi
    done
    if (( ${#missing[@]} )); then
        msg "$pkg: to build (${missing[*]})"
        queue+=("$pkg")
    else
        msg "$pkg: ${version}_$revision is already published"
    fi
done
for s in "${skipped[@]}"; do msg "Skipping $s"; done

built=() failed=()
if (( ${#queue[@]} )); then
    bin=$VP/hostdir/binpkgs
    rm -rf "$bin"
    mkdir -p "$bin"
    published=("$REPO"/*.xbps)
    if (( ${#published[@]} )); then
        cp -p "${published[@]}" "$bin/"
        xbps-rindex -a "$bin"/*.xbps
    fi
    chown -R builder:builder "$VP/hostdir"

    if [ ! -f "$MASTERDIR/.xbps_chroot_init" ]; then
        msg "Bootstrapping the build chroot"
        xsrc binary-bootstrap
    fi

    order=$(xsrc sort-dependencies "${queue[@]}") || die "cannot sort ${queue[*]}"
    for pkg in $order; do
        in_list "$pkg" "${queue[@]}" || continue
        msg "Building $pkg"
        if xsrc -j"$(nproc)" pkg "$pkg" && produced "$pkg"; then
            built+=("$pkg")
        else
            warn "$pkg failed to build"
            failed+=("$pkg")
        fi
    done
    for pkg in "${queue[@]}"; do
        if ! in_list "$pkg" "${built[@]}" "${failed[@]}"; then
            warn "$pkg was not built"
            failed+=("$pkg")
        fi
    done

    while IFS= read -r -d '' f; do
        cp -p "$f" "$REPO/"
    done < <(find "$bin" -name '*.xbps' -print0)
fi

for f in "$REPO"/*.xbps; do
    file=${f##*/}
    name=$(xbps-uhelper getpkgname "${file%.*.xbps}" 2>/dev/null) || name=
    if [ -z "$name" ] || [ -z "${want[$name]+set}" ]; then
        msg "Removing $file: not published"
        rm -f "$f" "$f.sig2"
    elif [ "$file" != "${want[$name]}" ] && [ -f "$REPO/${want[$name]}" ]; then
        msg "Removing $file: replaced by ${want[$name]}"
        rm -f "$f" "$f.sig2"
    fi
done
for f in "$REPO"/*.sig2; do
    [ -f "${f%.sig2}" ] || rm -f "$f"
done

rm -f "$REPO"/*-repodata "$REPO"/*-stagedata
published=("$REPO"/*.xbps)
if (( ${#published[@]} )); then
    msg "Indexing ${#published[@]} packages"
    xbps-rindex -a "${published[@]}"
fi

write_list "$OUT/built" "${built[@]}"
write_list "$OUT/failed" "${failed[@]}"
write_list "$OUT/skipped" "${skipped[@]}"
touch "$OUT/ready"
if [ -n "${HOST_UID:-}" ]; then
    chown -R "$HOST_UID:${HOST_GID:-$HOST_UID}" "$OUT"
fi
msg "Built: ${built[*]:-nothing}"
if (( ${#failed[@]} )); then
    warn "Failed: ${failed[*]}"
fi
