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

    # Write raw .repo files. Content is shell-single-quoted via the here-string
    # so `$releasever` etc. land verbatim in the file (no shell expansion).
    ${lib.concatStrings (lib.mapAttrsToList (name: content: ''
        echo -e "\e[32mDNF: configuring repo ${name}\e[0m"
        /usr/bin/sudo tee /etc/yum.repos.d/${name}.repo > /dev/null <<< ${lib.escapeShellArg content}
      '')
      cfg.repos)}

    # Enable Copr repositories. `dnf copr enable` is idempotent under `-y`;
    # `--hub` targets non-default (e.g. internal Red Hat) Copr instances.
    # Best-effort (`|| true`): a copr hub may be unreachable off-VPN, and
    # activation runs under `set -e` — a hard failure would abort `make switch`.
    ${lib.concatMapStringsSep "\n" (c: ''
        _dnf_run "DNF: enabling copr ${c.project}" /usr/bin/sudo dnf -y copr enable ${lib.optionalString (c.hub != null) "--hub ${c.hub} "}${c.project} || true
      '')
      cfg.copr}

    # Install items (dnf handles already-installed items gracefully).
    # Best-effort for the same reason as copr above: an unreachable repo or a
    # missing package must not abort the rest of the home-manager activation.
    if [ -n "$INSTALL" ]; then
      _dnf_run "DNF: installing $INSTALL" /usr/bin/sudo dnf -y install $INSTALL || true
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

    repos = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      example = lib.literalExpression ''
        {
          my-repo = '''
            [my-repo]
            name=My repo
            baseurl=https://example.com/repo/fedora-$releasever/
            enabled=1
            gpgcheck=0
          ''';
        }
      '';
      description = ''
        Raw yum `.repo` files written into `/etc/yum.repos.d`. The attribute
        name becomes `<name>.repo`. Use for third-party repos that are not on
        Copr. Written before Copr repos are enabled and packages installed.
      '';
    };

    copr = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          project = lib.mkOption {
            type = lib.types.str;
            example = "lpol/qa-tools";
            description = "Copr project in `owner/project` form, passed to `dnf copr enable`.";
          };
          hub = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "copr.devel.redhat.com";
            description = ''
              Copr hub hostname (the `--hub` flag). Use for non-default hubs
              such as an internal Red Hat Copr. `null` uses the public Fedora
              Copr.
            '';
          };
        };
      });
      default = [];
      description = ''
        Copr repositories to enable via `dnf copr enable` before installing
        packages. Enabled after `repos` are written.
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
