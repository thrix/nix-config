{
  config,
  lib,
  pkgs,
  ...
}: {
  home.username = "thrix";
  home.homeDirectory = "/home/thrix";

  home.stateVersion = "23.11";

  home.packages = with pkgs; [
    _1password
    _1password-gui
    alejandra
    deadnix
    glab
    htop
    jq
    pre-commit
    shellcheck
    silver-searcher
    yq
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
      "1password-cli"
    ];

  # Environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
  };

  # Restore host specific configuration links, before checking link targets
  home.activation.restoreNixLinks = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    files="
      $HOME/.config/sway/config
      $HOME/.config/waybar/config
      $HOME/.config/waybar/style.css
      $HOME/.mozilla/firefox/profiles.ini
      $HOME/.mozilla/firefox/thrix/containers.json
      $HOME/.mozilla/firefox/thrix/search.json.mozlz4
      $HOME/.mozilla/firefox/thrix/user.js
    "

    for file in $files; do
        [ ! -L "$file".lnk ] && continue
        echo -e "\e[32mRestoring link '$file' from '$file.lnk'\e[0m"
        mv "$file".lnk "$file"
    done
  '';

  # For host configuration we need to create copy of the files, so the host system can see them
  home.activation.createHostConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    files="
      $HOME/.config/sway/config
      $HOME/.config/waybar/config
      $HOME/.config/waybar/style.css
      $HOME/.mozilla/firefox/profiles.ini
      $HOME/.mozilla/firefox/thrix/containers.json
      $HOME/.mozilla/firefox/thrix/search.json.mozlz4
      $HOME/.mozilla/firefox/thrix/user.js
    "

    for file in $files; do
        # Ignore if the file is an ordinary file, home-manager will replace it if needed
        [ ! -L "$file" ] && continue

        # Create copy of the symlinked file
        echo -e "\e[32mStoring link '$file.lnk'\e[0m"
        target=$(readlink -f "$file")
        mv "$file" "$file".lnk

        echo -e "\e[32mCopying '$target' to '$file'\e[0m"
        cp "$target" "$file"
        chmod 644 "$file"
    done
  '';

  # For various final configurations
  home.activation.toolboxSetup = lib.hm.dag.entryAfter ["reloadSystemd"] ''
    # Only for toolbox
    test -f /run/.toolboxenv || exit

    # Set /var/cache/man permissions to the current user
    if [ ! -e /var/cache/man ]; then
      echo -e "\e[32mCreating /var/cache/man\e[0m"
      /usr/bin/sudo mkdir /var/cache/man
    fi

    if [ -e /var/cache/man -a $(stat -c "%u" /var/cache/man) -eq 0 ]; then
      echo -e "\e[32mSet permissions of /var/cache/man to $USER:$USER\e[0m"
      /usr/bin/sudo chown -Rf $USER:$USER /var/cache/man
    fi
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Bash
  programs.bash = {
    enable = true;

    # Required to load nix in nix-toolbox
    initExtra = ''
      test -f /run/.toolboxenv || source $HOME/.bashrc.backup
      source "$HOME/.nix-profile/etc/profile.d/nix.sh"

      foot-title() {
        echo -ne "\\033]0;$1\\007"
      }
    '';

    # Aliases
    shellAliases = {
      # git
      g = "git";

      # ls
      l = "ls -alh";
      ll = "ls -l";
      ls = "ls --color=tty";

      # host commands
      firefox = "flatpak-spawn --host firefox";
      flatpak = "flatpak-spawn --host flatpak";
      podman = "flatpak-spawn --host podman";
      rpm-ostree = "flatpak-spawn --host rpm-ostree";
    };
  };

  # Bat
  programs.bat.enable = true;

  # Firefox
  programs.firefox = {
    enable = true;
    package = null;

    profiles = {
      thrix = {
        id = 0;
        search = {
          default = "Google";
          force = true;
        };
        settings = {
          "browser.startup.homepage" = "https://google.com";
          "browser.search.region" = "CZ";
          "browser.search.isUS" = false;
          "distribution.searchplugins.defaultLocale" = "en-US";
          "general.useragent.locale" = "en-US";
          "browser.bookmarks.showMobileBookmarks" = true;
          "browser.newtabpage.pinned" = [
            {
              title = "Google";
              url = "https://google.com";
            }
          ];
        };
        containers = {
          personal = {
            color = "blue";
            icon = "tree";
            id = 2;
          };
          redhat = {
            color = "red";
            icon = "briefcase";
            id = 1;
          };
        };
      };
    };
  };

  # GitHub CLI
  programs.gh = {
    enable = true;

    settings = {
      editor = "nvim";

      aliases = {
        co = "pr checkout";
      };
    };
  };

  # Git
  programs.git = {
    enable = true;

    aliases = {
      c = "commit";
      cam = "commit --amend -vs";

      p = "push";
      pf = "push --force";
      pr = "pull --rebase";
    };

    delta = {
      enable = true;
    };

    extraConfig = {
      init.defaultBranch = "main";
    };

    userName = "Miroslav Vadkerti";
    userEmail = "mvadkert@redhat.com";
  };

  # Git Cliff
  programs.git-cliff = {
    enable = true;
  };

  # Man
  programs.man = {
    enable = true;
    # generateCaches = true;
  };

  # NixVim
  programs.nixvim = {
    enable = true;

    options = {
      shiftwidth = 2;
      mouse = "";
    };

    plugins = import ./nixvim/plugins.nix;
  };

  # SSH
  programs.ssh = {
    enable = true;
    package = pkgs.emptyDirectory;
    matchBlocks = {
      "*" = {
        extraOptions = {
          IdentityAgent = "~/.1password/agent.sock";
        };
      };
    };
  };

  # Starship
  programs.starship.enable = true;

  # Waybar
  programs.waybar = {
    enable = true;
    package = pkgs.emptyDirectory;
    style = import ./waybar/style.nix;
    settings = import ./waybar/settings.nix;
  };

  # Zoxide
  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
  };

  # Sway
  wayland.windowManager.sway = {
    enable = true;
    package = pkgs.emptyDirectory;
    config = import ./sway/config.nix {inherit lib;};
  };

  # XDG
  xdg = {
    enable = true;

    desktopEntries = {
      "1password" = {
        name = "1password";
        genericName = "1password desktop application";
        exec = "toolbox run --container nix 1password";
        terminal = false;
        categories = ["Application" "Utility"];
      };
    };
  };
}
