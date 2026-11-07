#!/bin/sh
flags_file="${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/user-flags.conf"

if [ -r "$flags_file" ]; then
	set -f
	set -- $(sed 's/#.*//' "$flags_file") "$@"
	set +f
fi

exec /usr/lib/obsidian/obsidian "$@"
