{
  # config,
  lib,
  pkgs,
  ...
}: let
  nixPackages = with pkgs; [
    _1password-cli
    _1password-gui
    alejandra
    asdf-vm
    bats
    claude-code
    cloud-nuke
    deadnix
    dgoss
    discord
    dnsutils
    dropbox
    glab
    gnumake
    goss
    htop
    httpie
    ibmcloud-cli
    iosevka
    jira-cli-go
    jq
    just
    kubectl
    kubevirt
    nomad
    openshift
    packer
    pre-commit
    ruby
    shellcheck
    shfmt
    silver-searcher
    slack
    stern
    vault-bin
    yamllint
    yq-go
  ];

  customPkgs = import ./pkgs/custom.nix {inherit pkgs;};
  customPackages = with customPkgs; [
    fedoraHost
  ];

  # shared settings across various programs
  terminalType = "screen-256color";
  terminalHistoryLimit = 100000;
in {
  home.username = "thrix";
  home.homeDirectory = "/home/thrix";

  home.stateVersion = "23.11";

  home.packages = nixPackages ++ customPackages;

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
      "1password-cli"
      "claude-code"
      "discord"
      "dropbox"
      "firefox-bin"
      "firefox-bin-unwrapped"
      "firefox-release-bin-unwrapped"
      "nomad"
      "packer"
      "slack"
      "vault-bin"
    ];

  # Environment variables
  home.sessionVariables = {
    # standard env vars
    EDITOR = "nvim";
    PAGER = "less -Rf";

    # TERM set to `foot` is not recognized everywhere
    TERM = terminalType;

    # 1password
    SSH_AUTH_SOCK = "$HOME/.1password/agent.sock";
    OP_BIOMETRIC_UNLOCK_ENABLED = "true";
    OP_PLUGIN_ALIASES_SOURCED = "1";

    # Testing Farm
    PYTHON_KEYRING_BACKEND = "keyring.backends.null.Keyring";

    HELLO = "meho";

    # tmt
    TMT_WORKDIR_ROOT = "$HOME/.local/share/tmt";

    # python requests
    REQUESTS_CA_BUNDLE = "/etc/pki/tls/certs/ca-bundle.crt";

    # dgoss
    CONTAINER_RUNTIME = "podman";
  };

  # Restore host specific configuration links, before checking link targets
  home.activation.restoreNixLinks = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    files="
      $HOME/.config/foot/foot.ini
      $HOME/.config/sway/config
      $HOME/.config/waybar/config
      $HOME/.config/waybar/style.css
      $HOME/.local/share/applications/mimeapps.list
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
      $HOME/.config/foot/foot.ini
      $HOME/.config/sway/config
      $HOME/.config/waybar/config
      $HOME/.config/waybar/style.css
      $HOME/.local/share/applications/mimeapps.list
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

    desktop_entries="
      1password
      discord
      slack
    "

    for entry in $desktop_entries; do
      src="$HOME/.nix-profile/share/applications/$entry.desktop"

      # do not break if the file does not yet exist
      test -e $src || continue

      echo -e "\e[32mCreating desktop entry '$entry.desktop'\e[0m"
      cp -f $src $HOME/.local/share/applications
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
           if test -f /run/.toolboxenv; then
      source "$HOME/.nix-profile/etc/profile.d/nix.sh"
           else
      # fallback to original bashrc outside of toolbox
      source $HOME/.bashrc.backup
           fi

           # Add local bin path
           export PATH="$HOME/.local/bin:$PATH"

           # Add onepassword-cli group required for 1password CLI integration to work
           if ! grep -q onepassword-cli /etc/group; then
      echo "Adding 'onepassword-cli' group"
      sudo groupadd -f onepassword-cli
      sudo usermod -aG onepassword-cli thrix
           fi

           # 1password needs to be run with the correct group for app CLI integration to work
           run-op() {
      sg onepassword-cli -c "op $*"
           }

           # set foot title
           foot-title() {
      echo -ne "\\033]0;$1\\007"
           }

           # set foot white theme
           foot-white() {
      # White background
      printf '\e]11;#ffffff\a'

      # Dark gray foreground (text)
      printf '\e]10;#2e2e2e\a'

      # Blue cursor for visibility
      printf '\e]12;#005f87\a'
           }

           # resolve issues with dbus activation environment
           flatpak-spawn --host --env=DISPLAY=:0 dbus-update-activation-environment --all --systemd
    '';

    # Aliases
    shellAliases = {
      # git
      g = "git";

      # ls
      l = "ls -alh";
      ll = "ls -l";
      ls = "ls --color=tty";

      # home-manager
      hs = "make -C $HOME/git/github.com/thrix/nix-config switch";

      # nvim
      n = "nvim";
      nd = "nvim -d";

      # 1password with plugins
      op = "run-op";
      gh = "run-op plugin run -- gh";
      glab = "run-op plugin run -- glab";

      # redhat
      rh-kinit = "op read \"op://redhat/Red\\ Hat\\ Kerberos/password\" | kinit $(op read \"op://redhat/Red\\ Hat\\ Kerberos/kinit_username\")";
      oc-login-osd = "oc login --server=https://api.cyborg.fio9.p1.openshiftapps.com:6443 --token=$(ocp-sso-token https://api.cyborg.fio9.p1.openshiftapps.com:6443)";
    };
  };

  # Bat
  programs.bat.enable = true;

  # Direnv
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
  };

  # Firefox
  programs.firefox = {
    enable = true;
    # NOTE: does not support well with pkgs.emptyDirectory
    package = null;

    profiles = {
      thrix = {
        id = 0;
        search = {
          default = "google";
          force = true;
        };
        settings = {
          browser.startup.homepage = "https://google.com";
          browser.search.region = "CZ";
          browser.search.isUS = false;
          distribution.searchplugins.defaultLocale = "en-US";
          general.useragent.locale = "en-US";
          browser.bookmarks.showMobileBookmarks = true;
          browser.newtabpage.pinned = [
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

  programs.foot = {
    enable = true;
    package = pkgs.emptyDirectory;
    settings = {
      main = {
        term = "xterm-256color";
        font = "monospace:size=12";
      };

      scrollback = {
        lines = terminalHistoryLimit;
      };

      url = {
        osc8-underline = "always";
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
      cf = "commit -m fixup";
      caf = "commit -a -m fixup";
      cam = "commit --amend -vs";

      p = "push";
      pf = "push --force";
      pm = "push -o merge_request.create";
      pmd = "push -o merge_request.create -o merge_request.draft";
      pms = "push -o merge_request.create -o merge_request.target=staging";
      pr = "pull --rebase --autostash";

      r = "rebase";
      ri2 = "git rebase -i HEAD~2";
      ri3 = "git rebase -i HEAD~3";
      ri4 = "git rebase -i HEAD~4";
      ri5 = "git rebase -i HEAD~5";
      ri6 = "git rebase -i HEAD~6";
    };

    delta = {
      # 2024-08-18 - disabled due to https://github.com/NixOS/nixpkgs/issues/332957, does not compile
      # enable = true;

      options = {
        line-numbers = true;
        side-by-side = true;
      };
    };

    difftastic = {
      enable = true;
    };

    extraConfig = {
      init.defaultBranch = "main";
      push.autoSetupRemote = "true";
    };

    userName = "Miroslav Vadkerti";
    userEmail = "mvadkert@redhat.com";
  };

  # Git Cliff
  programs.git-cliff = {
    enable = true;
  };

  # K9s
  programs.k9s = {
    enable = true;
  };

  # Man
  programs.man = {
    enable = true;
    generateCaches = true;
  };

  # NixVim
  programs.nixvim = {
    enable = true;

    globals = {
      mapleader = " ";
    };

    opts = {
      expandtab = true;
      relativenumber = true;
      shiftwidth = 2;
      mouse = "";
    };

    # Configure diagnostics
    diagnostic.settings = {
      virtual_text = {
        enable = true;
        spacing = 2;
        prefix = "●";
      };

      underline = true;
      update_in_insert = true;

      signs = {
        enable = true;
        config = {
          Error = {text = "✘";};
          Warn = {text = "▲";};
          Info = {text = "";};
          Hint = {text = "⚑";};
        };
      };
    };

    # Colorscheme
    colorschemes.tokyonight = {
      enable = true;

      settings = {
        style = "night";
      };
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
      "mvadkert" = {
        hostname = "10.0.198.38";
        user = "mvadkert";
      };
    };
  };

  # Starship
  programs.starship.enable = true;

  # Tmux
  programs.tmux = {
    enable = true;
    clock24 = true;
    historyLimit = terminalHistoryLimit;
    shortcut = "a";
    terminal = terminalType;
    extraConfig = ''
      set -g default-terminal "tmux-256color"
    '';
  };

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
    package = customPkgs.fedoraHost;

    config = import ./sway/config.nix {inherit lib;};

    # Not able to make the validation work for now :(
    checkConfig = false;

    # Disable systemd integration, managed by Silverblue.
    systemd.enable = false;
  };

  # Xdg
  xdg = {
    enable = true;
    desktopEntries = {
      "1password" = {
        name = "1Password";
        type = "Application";
        exec = "toolbox run --container nix 1password %U";
        icon = "1password";
        categories = ["Network" "Security"];
      };
      dropbox = {
        name = "Dropbox";
        type = "Application";
        exec = "toolbox run --container nix dropbox";
        icon = "dropbox";
        categories = ["Network" "FileTransfer"];
      };
      discord = {
        name = "Discord";
        type = "Application";
        exec = "toolbox run --container nix discord %U";
        icon = "discord";
        categories = ["Network" "InstantMessaging"];
      };
      "firefox" = {
        name = "Firefox";
        type = "Application";
        exec = "flatpak-spawn --host firefox %U";
        icon = "firefox";
        categories = ["Application" "Network" "WebBrowser"];
      };
      slack = {
        name = "Slack";
        type = "Application";
        exec = "toolbox run --container nix slack %U";
        icon = "slack";
        categories = ["Network" "InstantMessaging"];
      };
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "google-chrome.desktop";
        "x-scheme-handler/http" = "google-chrome.desktop";
        "x-scheme-handler/https" = "google-chrome.desktop";
        "x-scheme-handler/slack" = "slack.desktop";
        "x-directory/normal" = "org.gnome.Nautilus.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
        "application/x-windsurf" = "windsurf.desktop";
      };
    };
  };

  # Kanshi
  # services.kanshi = {
  #   enable = true;
  #   package = pkgs.emptyDirectory;
  #   profiles = {
  #     undocked = {
  #       name = "undocked";
  #       outputs = [
  #         { name = "eDP-1"; status = true; mode = "1920x1080"; position = "0,0"; }
  #         { name = "*"; status = false; }
  #       ];
  #     };
  #     "docked" = {
  #       name = "docked";
  #       outputs = [
  #         { name = "DP-7"; status = true; mode = "1920x1080"; position = "0,0"; }
  #         { name = "DP-9"; status = true; mode = "1680x1050"; position = "1920,0"; }
  #         { name = "eDP-1"; status = true; mode = "1920x1080"; position = "1920,1050"; }
  #       ];
  #     };
  #     "presentation" = {
  #       name = "presentation";
  #       outputs = [
  #         { name = "eDP-1"; status = true; mode = "1920x1080"; position = "0,0"; }
  #         { name = "*"; status = true; position = "1920,0"; }
  #       ];
  #     };
  #   };
  # };
}
