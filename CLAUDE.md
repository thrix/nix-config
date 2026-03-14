# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a [Home Manager](https://github.com/nix-community/home-manager) flake-based Nix configuration for a developer laptop running Fedora Silverblue (Bootable Containers). It manages dotfiles, packages, and program configuration for two users: `thrix` and `mvadkert`.

The setup runs inside a [nix-toolbox](https://thrix.github.io/nix-toolbox) container, with host system binaries accessed via `flatpak-spawn --host`.

## Common Commands

```bash
# Apply home-manager configuration (also aliased as `hs` in shell)
make switch

# Format all Nix files (uses alejandra)
alejandra .

# Check for dead Nix code
deadnix .

# Install pre-commit hooks
make install/pre-commit
```

## Architecture

### Entry Points

- **`flake.nix`** — defines two `homeConfigurations` (`thrix` and `mvadkert`), both using `home.nix` with different `username`/`homeDirectory` args. Uses nixpkgs-unstable, home-manager, and nixvim inputs.
- **`home.nix`** — the main Home Manager module. Configures all programs, packages, environment variables, and activation scripts.

### Key Modules

- **`pkgs/custom.nix`** — a single custom derivation `fedoraHost` that creates wrapper scripts for host-side binaries (podman, swaymsg, firefox, etc.) and token-injecting wrappers for Testing Farm CLI and Artemis CLI variants using 1Password secrets.
- **`nixvim/plugins.nix`** — NixVim plugin configuration (LSP servers, treesitter, telescope, cmp, efmls). LSP servers `ansiblels` and `jinja_lsp` use `package = null` (expected to come from the host/toolbox).
- **`waybar/settings.nix`** and **`waybar/style.nix`** — Waybar bar configuration and CSS.
- **`sway/config.nix`** — Sway window manager configuration.

### Host Integration Pattern

Because the config runs in a toolbox container, several programs use `package = pkgs.emptyDirectory` to avoid installing the package via Nix while still generating config files (foot terminal, ssh, waybar, firefox). The `fedoraHost` custom package provides wrapper scripts that delegate to the host via `flatpak-spawn --host`.

### Activation Scripts

`home.nix` defines custom activation scripts:
- **`restoreNixLinks`** — runs before `checkLinkTargets`; restores `.lnk` backup files back to their original paths before Home Manager replaces symlinks.
- **`createHostConfig`** — runs after `linkGeneration`; converts Home Manager symlinks to real copies (so the Silverblue host can read them), and copies `.desktop` files to `~/.local/share/applications`.
- **`toolboxSetup`** — runs after `reloadSystemd`; only runs inside toolbox; fixes `/var/cache/man` permissions.

### Pre-commit Hooks

Configured in `.pre-commit-config.yaml`:
- `alejandra` — Nix formatter
- `deadnix` — removes unused Nix bindings
- `gitleaks` — secrets scanning
- Standard hooks: end-of-file-fixer, trailing-whitespace, check-toml

## Nix Formatting

Use `alejandra` for formatting (not `nixfmt`). It is available as both a flake formatter (`nix fmt`) and a pre-commit hook.
