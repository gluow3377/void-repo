<div align="center">

# void-repo

[![Void Linux](https://img.shields.io/badge/Void_Linux-478061?logo=voidlinux&logoColor=white)](https://voidlinux.org)
[![x86_64-glibc](https://img.shields.io/badge/x86__64-glibc-478061)](#)
[![Build](https://github.com/gluow3377/void-repo/actions/workflows/repository.yml/badge.svg)](https://github.com/gluow3377/void-repo/actions/workflows/repository.yml)

Unofficial XBPS repository for [Void Linux](https://voidlinux.org) with packages
that are not available in the official repositories.

</div>

## Installation

### 1. Add the repository

```sh
echo 'repository=https://gluow3377.github.io/void-repo/current' | sudo tee /etc/xbps.d/20-gluow3377.conf
```

### 2. Sync and import the key

```sh
sudo xbps-install -S
```

XBPS will ask you to import the public key. Accept it only if the prompt looks exactly like this:

```
`https://gluow3377.github.io/void-repo/current' repository has been RSA signed by "gluow3377 <344402541+gluow3377@users.noreply.github.com>"
Fingerprint: 8c:63:18:e4:c1:ea:71:a2:92:71:98:92:7c:25:43:13
Do you want to import this public key? [Y/n]
```

### 3. Install packages

```sh
sudo xbps-install helium-bin
```

List all packages in the repository:

```sh
xbps-query -i -M --repository=https://gluow3377.github.io/void-repo/current -s ''
```

## Packages

| Package | Description |
| --- | --- |
| [adw-gtk3](https://github.com/lassekongo83/adw-gtk3) | Unofficial GTK3 port of the libadwaita theme |
| [ayugram-desktop](https://github.com/AyuGram/AyuGramDesktop) | Desktop Telegram client with good customisation |
| [font-jetbrains-mono-nerd](https://www.nerdfonts.com) | JetBrains Mono typeface patched with Nerd Fonts glyphs |
| [font-iosevka-nerd](https://www.nerdfonts.com) | Iosevka typeface patched with Nerd Fonts glyphs |
| [helium-bin](https://helium.computer) | Private, fast, and honest Chromium-based web browser |
| [lavat](https://github.com/AngelJumbo/lavat) | Little program that simulates a lava lamp in the terminal |
| [ly](https://codeberg.org/fairyglade/ly) | Lightweight TUI display manager |
| [noctalia](https://github.com/noctalia-dev/noctalia) | Sleek, customizable desktop shell crafted for Wayland |
| [noctalia-greeter](https://github.com/noctalia-dev/noctalia-greeter) | Minimal greetd greeter matching the look and feel of Noctalia Shell |
| [throne](https://throneproj.github.io) | Cross-platform GUI proxy utility powered by sing-box |
| [tlottie](https://github.com/dkaraush/tlottie) | Rust library for drawing Lottie animations (build dependency of ayugram-desktop) |
| [ueberzugpp](https://github.com/jstkdng/ueberzugpp) | Drop-in replacement for ueberzug written in C++ |
| [zen-browser](https://zen-browser.app) | Privacy-focused web browser based on Firefox |

### Templates only

These templates live in [srcpkgs/](srcpkgs/) but are not published, so you have to build them yourself:

| Package | Why it is not published |
| --- | --- |
| [obsidian](https://obsidian.md) | Restricted license: binaries can't be redistributed |
| [font-times-new-roman](https://corefonts.sourceforge.net) | Restricted license: fonts can't be redistributed |
| [PrismLauncher-offline](https://prismlauncher.org) | Prism Launcher patched to allow offline accounts, built locally only |

## Building templates yourself

Copy the templates into an up-to-date [void-packages](https://github.com/void-linux/void-packages) clone and build them with `xbps-src`:

```sh
git clone --depth 1 https://github.com/void-linux/void-packages
git clone https://github.com/gluow3377/void-repo
cp -r void-repo/srcpkgs/* void-packages/srcpkgs/
cd void-packages
./xbps-src binary-bootstrap
./xbps-src pkg ly
sudo xbps-install -R hostdir/binpkgs ly
```

Restricted packages (`obsidian`, `font-times-new-roman`) also need this before building:

```sh
echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf
```

## How it works

On every push to `main`, [GitHub Actions](.github/workflows/repository.yml) builds the templates in a `void-glibc-full`
container against the latest void-packages, signs the packages and publishes them to GitHub Pages.
Only packages whose `version_revision` is not published yet get rebuilt, so a changed template needs a `revision` bump to reach the repository.

## License

Released under the [MIT License](LICENSE).

---
*Not affiliated with the official Void Linux project.*
