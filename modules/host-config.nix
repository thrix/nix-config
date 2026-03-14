{
  config,
  lib,
  ...
}: let
  cfg = config.hostConfig;

  desktopFiles =
    lib.optionals cfg.xdgDesktopEntries
    (map (name: ".local/share/applications/${name}.desktop")
      (lib.attrNames config.xdg.desktopEntries));

  allFiles = cfg.files ++ desktopFiles;

  restoreScript =
    "source ${./host-config-lib.sh}\n"
    + lib.concatMapStrings (file: ''
      _hc_restore_file "$HOME/${file}"
    '')
    allFiles;

  createScript =
    "source ${./host-config-lib.sh}\n"
    + lib.concatMapStrings (file: ''
      _hc_create_file "$HOME/${file}"
    '')
    allFiles;
in {
  options.hostConfig = {
    enable = lib.mkEnableOption "host config file materialization";

    files = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [".config/sway/config" ".config/waybar/config"];
      description = ''
        Home-relative paths to materialize as real files for host access.
        Home Manager normally creates symlinks into the Nix store, which the
        Silverblue host cannot follow from outside the toolbox container.
        Files listed here are copied to real files after each switch.
      '';
    };

    xdgDesktopEntries = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When true, automatically materialize all desktop entries declared via
        xdg.desktopEntries. Paths are derived directly from that option — adding
        a new entry in xdg.desktopEntries is sufficient, no need to list it here too.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation = {
      restoreNixLinks = lib.hm.dag.entryBefore ["checkLinkTargets"] restoreScript;
      createHostConfig = lib.hm.dag.entryAfter ["linkGeneration"] createScript;
    };
  };
}
