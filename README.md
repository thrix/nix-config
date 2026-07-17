# nix-config

Nix configurations of thrix.

Used to manage developer laptop based on Bootable Containers and [nix-toolbox](https://thrix.github.io/nix-toolbox).

## Home Manager Modules

### `hostConfig`

Materializes Home Manager symlinks as real files so the Silverblue host can read them from
outside the toolbox container. Useful for any config file that a host-side program (sway,
waybar, foot, firefox) needs to access directly.

#### Usage

In your `flake.nix`:

```nix
inputs = {
  nix-config = {
    url = "github:thrix/nix-config";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };
};

homeConfigurations."alice" = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    inputs.nix-config.homeManagerModules.hostConfig
    ./home.nix
  ];
};
```

In your `home.nix`:

```nix
hostConfig = {
  enable = true;

  # Automatically materialize all xdg.desktopEntries as real files
  xdgDesktopEntries = true;

  # Any other Home Manager-managed files the host needs to read
  files = [
    ".config/sway/config"
    ".config/waybar/config"
  ];
};
```

### `vault`

Runs [HashiCorp Vault](https://www.vaultproject.io/) as a systemd user service with
pluggable auto-unseal and plugin management. Designed for personal use — generates
short-lived tokens (GitHub, GitLab) instead of managing long-lived PATs.

#### Features

- Vault server as a systemd user service (file storage, localhost only, UI enabled)
- Pluggable unseal: `1password`, `file`, or `manual`
- Plugin management: copies plugin binaries from nix store to Vault's plugin directory
- Manual unseal via `vault-unseal` command (also re-logins and triggers refresh timers)
- Web UI at `http://127.0.0.1:8200/ui`

#### Usage

In your `flake.nix`:

```nix
inputs = {
  nix-config = {
    url = "github:thrix/nix-config";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };
};

homeConfigurations."alice" = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    inputs.nix-config.homeManagerModules.vault
    ./home.nix
  ];
};
```

In your `home.nix`:

```nix
# Minimal — manual unseal
vault.enable = true;

# With 1Password auto-unseal
vault = {
  enable = true;
  unseal.method = "1password";
};

# With file-based auto-unseal
vault = {
  enable = true;
  unseal = {
    method = "file";
    file.path = "~/.vault/unseal-key";
  };
};
```

#### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `vault.enable` | bool | `false` | Enable Vault service |
| `vault.package` | package | `pkgs.vault-bin` | Vault package |
| `vault.address` | string | `"127.0.0.1:8200"` | Listen address |
| `vault.dataDir` | string | `".vault-server/data"` | Storage path (home-relative) |
| `vault.configDir` | string | `".vault-server"` | Config path (home-relative) |
| `vault.pluginDir` | string | `".vault-server/plugins"` | Plugin path (home-relative) |
| `vault.plugins` | list of packages | `[]` | Plugin packages to install |
| `vault.unseal.method` | enum | `"manual"` | `"1password"`, `"file"`, or `"manual"` |
| `vault.unseal.onePassword.unsealKeyRef` | string | `"op://vault/hashicorp-vault/unseal-key"` | 1Password URI for unseal key |
| `vault.unseal.onePassword.rootTokenRef` | string | `"op://vault/hashicorp-vault/root-token"` | 1Password URI for root token |
| `vault.unseal.onePassword.group` | string | `"onepassword-cli"` | Unix group for `op` CLI |
| `vault.unseal.file.path` | string | `"~/.vault/unseal-key"` | Path to unseal key file |

#### Bootstrap

After `make switch`:

```bash
# 1. Check Vault is running
systemctl --user status vault

# 2. Initialize Vault (one-time)
vault-bootstrap

# 3. Store the printed unseal key + root token in 1Password
#    (vault-bootstrap prints the exact command)

# 4. Open a new shell — auto-unseal happens via biometric prompt

# 5. Verify
vault status
```

#### GitHub App Short-lived Tokens

To replace long-lived GitHub PATs with 1-hour auto-expiring tokens:

1. [Create a GitHub App](https://github.com/settings/apps/new) with needed permissions
2. Install it on your account/orgs
3. Download the private key (`.pem`)
4. Run `vault-setup-github` — it registers the plugin and configures the App

```bash
# Get a short-lived token
vault read -field=token github/token

# Use the ght alias
export GITHUB_TOKEN=$(ght)
```

#### GitLab Short-lived Group Access Tokens

To replace long-lived GitLab PATs with short-lived group access tokens, via the
[vault-plugin-secrets-gitlab](https://github.com/ilijamt/vault-plugin-secrets-gitlab)
plugin. Both `gitlab.com` and `gitlab.cee.redhat.com` are supported as named
configs (`com` and `cee`) under a single `gitlab/` mount.

1. Create a GitLab token with the `api` scope and **Owner** on the group you
   want to mint tokens for (a personal access token, or a group access token —
   no instance-admin rights required)
2. Run `vault-setup-gitlab` — it registers the plugin, enables the engine, and
   prompts for the instance + group/role details. Run it once per instance
   (use names `com` and `cee`)

```bash
# Get a short-lived token
vault read -field=token gitlab/token/com

# Use the glt / glt-cee aliases
export GITLAB_TOKEN=$(glt)        # gitlab.com
export GITLAB_TOKEN=$(glt-cee)    # gitlab.cee.redhat.com
```

The `gitlab-mcp` and `gitlab-cee-mcp` refresh timers re-mint these tokens and
recreate the corresponding toolhive MCP servers before each lease expires, the
same way `github-thrix` does.
