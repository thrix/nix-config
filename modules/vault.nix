{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.vault;
  vaultAddr = "http://${cfg.address}";
  homeDir = config.home.homeDirectory;
  pluginDir = "${homeDir}/${cfg.pluginDir}";
  dataDir = "${homeDir}/${cfg.dataDir}";
  configFile = "${cfg.configDir}/config.hcl";

  # Absolute path: home-manager activation runs with a restricted PATH that
  # does not include /usr/bin, so a bare `systemctl` is not found there.
  systemctl = "/usr/bin/systemctl --user";

  # On a successful unseal, kick the refresh jobs immediately so dependent
  # consumers (e.g. github-thrix) get a fresh token now instead of waiting up
  # to the timer interval. Runs the oneshot services, not the timers.
  triggerRefreshSnippet = lib.optionalString (cfg.refreshTimers != {}) (
    lib.concatMapStringsSep "\n" (n: ''${systemctl} start vault-refresh-${n}.service 2>/dev/null || true'') (lib.attrNames cfg.refreshTimers)
  );

  unsealScript = let
    checkPreamble = ''
      #!/bin/bash
      export VAULT_ADDR="${vaultAddr}"

      vault_status=$(vault status -format=json 2>/dev/null) || true
      [ -n "$vault_status" ] || exit 0
      is_sealed=$(echo "$vault_status" | jq -r '.sealed' 2>/dev/null)
      [ "$is_sealed" = "true" ] || exit 0
    '';
  in
    {
      "1password" = pkgs.writeShellScript "vault-unseal" ''
        ${checkPreamble}
        unseal_key=$(sg ${cfg.unseal.onePassword.group} -c "op read '${cfg.unseal.onePassword.unsealKeyRef}'" 2>/dev/null) || exit 0
        [ -n "$unseal_key" ] || exit 0
        if vault operator unseal "$unseal_key" >/dev/null 2>&1; then
          ${triggerRefreshSnippet}
        fi
      '';
      "file" = pkgs.writeShellScript "vault-unseal" ''
        ${checkPreamble}
        key_file="${cfg.unseal.file.path}"
        [ -f "$key_file" ] || exit 0
        unseal_key=$(cat "$key_file" 2>/dev/null) || exit 0
        [ -n "$unseal_key" ] || exit 0
        if vault operator unseal "$unseal_key" >/dev/null 2>&1; then
          ${triggerRefreshSnippet}
        fi
      '';
      "manual" = null;
    }
    .${cfg.unseal.method};

  loginScript = {
    "1password" = pkgs.writeShellScript "vault-login" ''
      export VAULT_ADDR="${vaultAddr}"
      root_token=$(sg ${cfg.unseal.onePassword.group} -c "op read '${cfg.unseal.onePassword.rootTokenRef}'" 2>/dev/null) || exit 1
      [ -n "$root_token" ] || { echo "could not read root token from 1Password"; exit 1; }
      vault login "$root_token" >/dev/null 2>&1
      echo "vault login OK"
    '';
    "file" = null;
    "manual" = null;
  }.${cfg.unseal.method};

  hasLoginScript = loginScript != null;
  hasUnsealScript = cfg.unseal.method != "manual";
  hasPlugins = cfg.plugins != [];

  # Re-login snippet for refresh timer scripts — if the vault token is
  # stale (e.g. after vault restart), re-authenticate before running
  # the user's refresh script. Takes the job name as argument for logging.
  mkReloginSnippet = jobName: {
    "1password" = ''
      if ! vault token lookup >/dev/null 2>&1; then
        echo "refresh '${jobName}': vault token stale — re-logging in via 1Password"
        root_token=$(sg ${cfg.unseal.onePassword.group} -c "op read '${cfg.unseal.onePassword.rootTokenRef}'" 2>/dev/null) || {
          echo "refresh '${jobName}': could not read root token — skipping"
          exit 0
        }
        vault login "$root_token" >/dev/null 2>&1 || { echo "refresh '${jobName}': login failed — skipping"; exit 0; }
      fi
    '';
    "file" = "";
    "manual" = "";
  }.${cfg.unseal.method};

  bootstrapScript = let
    opVault = cfg.bootstrap.onePassword.vault;
    opCategory = cfg.bootstrap.onePassword.category;
    opTitle = cfg.bootstrap.onePassword.title;
    storeInstructions = {
      "1password" = ''
        echo ""
        echo "Storing secrets in 1Password (vault: ${opVault}, item: ${opTitle})..."
        sg ${cfg.unseal.onePassword.group} -c "op item create \
          --vault '${opVault}' \
          --category '${opCategory}' \
          --title '${opTitle}' \
          'unseal-key=$unseal_key' \
          'root-token=$root_token'"
        echo "Secrets stored in 1Password."
      '';
      "file" = ''
        echo ""
        echo "Storing unseal key to ${cfg.unseal.file.path}..."
        echo "$unseal_key" > "${cfg.unseal.file.path}"
        chmod 600 "${cfg.unseal.file.path}"
        echo "Unseal key stored."
      '';
      "manual" = ''
        echo ""
        echo "=== STORE THESE SECRETS ==="
        echo ""
        echo "Unseal Key: $unseal_key"
        echo "Root Token: $root_token"
        echo ""
        echo "Store them somewhere safe."
      '';
    };
  in
    pkgs.writeShellScript "vault-bootstrap" ''
      set -euo pipefail

      VAULT_ADDR="''${VAULT_ADDR:-${vaultAddr}}"
      export VAULT_ADDR

      echo "=== HashiCorp Vault Bootstrap ==="
      echo ""

      vault_status=$(vault status -format=json 2>&1) || true
      if echo "$vault_status" | jq -e . >/dev/null 2>&1; then
        :
      else
        echo "ERROR: Vault is not running. Start it with:"
        echo "  systemctl --user start vault"
        exit 1
      fi
      is_initialized=$(echo "$vault_status" | jq -r '.initialized')

      if [ "$is_initialized" = "true" ]; then
        echo "Vault is already initialized."
        is_sealed=$(echo "$vault_status" | jq -r '.sealed')
        if [ "$is_sealed" = "true" ]; then
          echo "Vault is sealed. Run 'vault-unseal' or open a new shell."
        else
          echo "Vault is unsealed and ready."
        fi
        exit 0
      fi

      echo "Initializing vault (1 key share, 1 threshold — personal use)..."
      init_output=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)

      unseal_key=$(echo "$init_output" | jq -r '.unseal_keys_b64[0]')
      root_token=$(echo "$init_output" | jq -r '.root_token')

      ${storeInstructions.${cfg.unseal.method}}

      echo ""
      echo "Unsealing vault..."
      vault operator unseal "$unseal_key" >/dev/null

      echo "Logging in..."
      vault login "$root_token" >/dev/null

      echo ""
      echo "Vault is initialized, unsealed, and ready."
    '';

  # Service file written as real file (not symlink) because in toolbox
  # setups the nix store is not visible to the host systemd.
  # ExecStart uses toolbox to run vault inside the nix container.
  serviceDir = ".config/systemd/user";
  serviceContent = ''
[Unit]
Description=HashiCorp Vault
After=network.target

[Service]
Type=simple
ExecStartPre=/usr/bin/toolbox run --container nix mkdir -p ${homeDir}/${cfg.dataDir} ${pluginDir}
ExecStart=/usr/bin/toolbox run --container nix ${cfg.package}/bin/vault server -config=${homeDir}/${configFile}
Restart=on-failure
RestartSec=5
Environment=HOME=${homeDir}
# KillMode=process is critical: when vault is the first consumer of the
# nix toolbox container, toolbox run starts the shared container under
# this service cgroup. With the default control-group kill mode, a
# restart tears down the whole cgroup, killing the container and every
# other terminal running toolbox run. process mode kills only vault.
KillMode=process

[Install]
WantedBy=default.target
  '';

  # Each refresh job: a wrapper script (run inside toolbox) + a oneshot
  # service + a timer. Written as real unit files via activation, same as
  # vault.service, because host systemd cannot follow nix-store symlinks.
  refreshJobs = lib.mapAttrsToList (name: job: rec {
    inherit name;
    unit = "vault-refresh-${name}";
    script = pkgs.writeShellScript "${unit}.sh" ''
      export VAULT_ADDR="${vaultAddr}"
      # stdout/stderr land in the journal under this unit.
      echo "refresh '${name}': starting (VAULT_ADDR=$VAULT_ADDR)"
      # Exit quietly if vault is sealed/unreachable — next tick retries.
      if ! vault status >/dev/null 2>&1; then
        echo "refresh '${name}': vault sealed or unreachable — skipping"
        exit 0
      fi
      ${mkReloginSnippet name}
      ${job.script}
      echo "refresh '${name}': done"
    '';
    serviceFile = ''
[Unit]
Description=Vault credential refresh: ${name}

[Service]
Type=oneshot
Environment=HOME=${homeDir}
# Run inside the nix toolbox so vault/thv and the on-disk vault token
# are available. KillMode=process avoids tearing down the shared
# container cgroup (see vault.service).
ExecStart=/usr/bin/toolbox run --container nix ${script}
KillMode=process
    '';
    timerFile = ''
[Unit]
Description=Timer for Vault credential refresh: ${name}

[Timer]
OnBootSec=2min
OnUnitActiveSec=${job.interval}
Persistent=true

[Install]
WantedBy=timers.target
    '';
  }) cfg.refreshTimers;

  hasRefreshTimers = cfg.refreshTimers != {};
in {
  options.vault = {
    enable = lib.mkEnableOption "HashiCorp Vault as a systemd user service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vault-bin;
      description = "Vault package to use.";
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8200";
      description = "Listen address for Vault.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = ".vault-server/data";
      description = "Home-relative path for Vault file storage backend.";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = ".vault-server";
      description = "Home-relative path for Vault configuration files.";
    };

    pluginDir = lib.mkOption {
      type = lib.types.str;
      default = ".vault-server/plugins";
      description = "Home-relative path for Vault plugin binaries.";
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = ''
        Vault plugin packages. Binaries from each package are copied
        to the plugin directory on activation.
      '';
    };

    unseal = {
      method = lib.mkOption {
        type = lib.types.enum ["1password" "file" "manual"];
        default = "manual";
        description = ''
          Unseal method for Vault:
          - `1password`: auto-unseal via 1Password CLI on shell init
          - `file`: auto-unseal from a key file on shell init
          - `manual`: no auto-unseal, user runs `vault operator unseal` manually
        '';
      };

      onePassword = {
        unsealKeyRef = lib.mkOption {
          type = lib.types.str;
          default = "op://vault/hashicorp-vault/unseal-key";
          description = "1Password reference URI for the Vault unseal key.";
        };

        rootTokenRef = lib.mkOption {
          type = lib.types.str;
          default = "op://vault/hashicorp-vault/root-token";
          description = "1Password reference URI for the Vault root token.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "onepassword-cli";
          description = "Unix group required for 1Password CLI integration.";
        };
      };

      file = {
        path = lib.mkOption {
          type = lib.types.str;
          default = "~/.vault-server/unseal-key";
          description = "Path to file containing the Vault unseal key.";
        };
      };
    };

    refreshTimers = lib.mkOption {
      default = {};
      description = ''
        Periodic credential-refresh jobs. Each entry generates a systemd user
        service + timer. The script runs inside the nix toolbox (so vault and
        other toolbox binaries are available) and typically reads a short-lived
        token from Vault and pushes it wherever it is consumed.

        Use this to work around consumers that read a credential once at start
        and cannot refresh in place (e.g. an MCP server reading a token from an
        env var) — the job re-mints and restarts the consumer before expiry.
      '';
      example = lib.literalExpression ''
        {
          github-mcp = {
            interval = "45min";
            script = '''
              token=$(vault read -field=token github/token installation_id=123)
              printf '%s' "$token" | thv secret set github_token
              # thv restart does NOT re-resolve secrets — full recreate required
              thv stop github-mcp 2>/dev/null || true
              thv rm github-mcp 2>/dev/null || true
              thv run --name github-mcp --transport stdio \
                --secret github_token,target=GITHUB_PERSONAL_ACCESS_TOKEN \
                ghcr.io/github/github-mcp-server:latest
            ''';
          };
        }
      '';
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          interval = lib.mkOption {
            type = lib.types.str;
            default = "45min";
            description = "Refresh interval (systemd OnUnitActiveSec value).";
          };
          script = lib.mkOption {
            type = lib.types.lines;
            description = ''
              Shell script body run inside the toolbox. VAULT_ADDR is exported.
              Vault auth uses the on-disk token (~/.vault-token); the job exits
              quietly if Vault is sealed or unreachable.
            '';
          };
        };
      });
    };

    bootstrap = {
      onePassword = {
        vault = lib.mkOption {
          type = lib.types.str;
          default = "vault";
          description = "1Password vault name to store Vault secrets in.";
        };

        category = lib.mkOption {
          type = lib.types.str;
          default = "login";
          description = "1Password item category (e.g. login, password).";
        };

        title = lib.mkOption {
          type = lib.types.str;
          default = "hashicorp-vault";
          description = "1Password item title for Vault secrets.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables = {
      VAULT_ADDR = vaultAddr;
    };

    # Config generated via activation (not home.file) so we can resolve
    # symlinks at runtime. Vault resolves symlinks when validating
    # plugin_directory — on Silverblue /home -> /var/home causes mismatch.
    home.activation.vaultConfig = lib.hm.dag.entryBefore ["vaultService"] ''
      mkdir -p "${homeDir}/${cfg.configDir}"
      REAL_HOME=$(readlink -f "${homeDir}")
      cat > "${homeDir}/${configFile}" << VAULTCFG
ui = true

# Toolbox containers lack CAP_IPC_LOCK
disable_mlock = true

api_addr = "${vaultAddr}"

storage "file" {
  path = "$REAL_HOME/${cfg.dataDir}"
}

listener "tcp" {
  address     = "${cfg.address}"
  tls_disable = 1
}

plugin_directory = "$REAL_HOME/${cfg.pluginDir}"
VAULTCFG
    '';

    home.activation.vaultService = lib.hm.dag.entryAfter ["linkGeneration"] ''
      mkdir -p "${homeDir}/${serviceDir}"
      rm -f "${homeDir}/${serviceDir}/vault.service"
      cat > "${homeDir}/${serviceDir}/vault.service" << 'UNIT'
${serviceContent}
UNIT
      ${systemctl} daemon-reload
      ${systemctl} enable vault.service 2>/dev/null || true
      ${systemctl} restart vault.service 2>/dev/null || true
    '';

    home.activation.vaultPlugins = lib.mkIf hasPlugins (lib.hm.dag.entryAfter ["vaultService"] ''
      mkdir -p "${pluginDir}"
      for src in ${lib.concatMapStringsSep " " (p: "${p}/bin/*") cfg.plugins}; do
        cp -f "$src" "${pluginDir}/"
      done
      chmod +x "${pluginDir}"/* 2>/dev/null || true
    '');

    home.activation.vaultRefreshTimers = lib.mkIf hasRefreshTimers (lib.hm.dag.entryAfter ["vaultService"] ''
      mkdir -p "${homeDir}/${serviceDir}"
      ${lib.concatMapStringsSep "\n" (job: ''
        rm -f "${homeDir}/${serviceDir}/${job.unit}.service" "${homeDir}/${serviceDir}/${job.unit}.timer"
        cat > "${homeDir}/${serviceDir}/${job.unit}.service" << 'UNIT'
${job.serviceFile}
UNIT
        cat > "${homeDir}/${serviceDir}/${job.unit}.timer" << 'UNIT'
${job.timerFile}
UNIT
      '') refreshJobs}
      ${systemctl} daemon-reload
      ${lib.concatMapStringsSep "\n" (job: ''
        ${systemctl} enable --now ${job.unit}.timer 2>/dev/null || true
      '') refreshJobs}
    '');

    home.packages =
      [
        (pkgs.runCommand "vault-bootstrap" {} ''
          mkdir -p $out/bin
          ln -s ${bootstrapScript} $out/bin/vault-bootstrap
        '')
      ]
      ++ lib.optionals hasUnsealScript [
        (pkgs.runCommand "vault-unseal" {} ''
          mkdir -p $out/bin
          ln -s ${unsealScript} $out/bin/vault-unseal
        '')
      ]
      ++ lib.optionals hasLoginScript [
        (pkgs.runCommand "vault-login" {} ''
          mkdir -p $out/bin
          ln -s ${loginScript} $out/bin/vault-login
        '')
      ];
  };
}
