{
  config,
  lib,
  ...
}: let
  cfg = config.dnf;

  installScript = ''
    test -f /run/.toolboxenv || exit

    FEDORA_RELEASE=$(. /etc/os-release && echo "$VERSION_ID")

    INSTALL="${lib.concatStringsSep " " cfg.install}"

    ${lib.concatStrings (lib.mapAttrsToList (release: items: ''
        if [ "$FEDORA_RELEASE" = "${release}" ]; then
          INSTALL="$INSTALL ${lib.concatStringsSep " " items}"
        fi
      '')
      cfg.releaseInstall)}

    # Helper: run command with gum spinner if available, fallback to echo
    _dnf_run() {
      local title="$1"; shift
      if command -v gum &>/dev/null; then
        gum spin --spinner dot --title "$title" -- "$@"
      else
        echo -e "\e[32m$title\e[0m"
        "$@"
      fi
    }

    # Install items (dnf handles already-installed items gracefully)
    if [ -n "$INSTALL" ]; then
      _dnf_run "DNF: installing $INSTALL" /usr/bin/sudo dnf -y install $INSTALL
    fi

    # Upgrade all packages
    ${lib.optionalString cfg.upgradeAll ''
      _dnf_run "DNF: upgrading all packages" /usr/bin/sudo dnf -y upgrade
    ''}
  '';
in {
  options.dnf = {
    enable = lib.mkEnableOption "DNF package management in toolbox containers";

    install = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["krb5-workstation" "@development-tools" "/path/to/local.rpm"];
      description = ''
        Items to install via `dnf install`. Accepts anything dnf supports:
        package names, group names (@group), paths, URLs, provides, etc.
        Installed regardless of Fedora release version.
      '';
    };

    releaseInstall = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      example = {
        "41" = ["some-f41-pkg"];
        "42" = ["some-f42-pkg"];
      };
      description = ''
        Per-Fedora-release items to install. Keys are VERSION_ID strings
        (e.g. "41", "42"). Items are only installed when that release is
        detected via /etc/os-release.
      '';
    };

    upgradeAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "When true, run `dnf -y upgrade` (all packages) on every activation.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation = {
      dnfInstall = lib.hm.dag.entryAfter ["reloadSystemd"] installScript;
    };
  };
}
