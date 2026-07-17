{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}: let
  nixPackages = with pkgs; [
    _1password-cli
    alejandra
    asdf-vm
    bats
    claude-code
    cloud-nuke
    codex
    cosign
    deadnix
    dgoss
    dnsutils
    google-cloud-sdk
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
    opencode
    openshift
    packer
    rclone
    ruby
    shellcheck
    shfmt
    silver-searcher
    stern
    toolhive
    vault-bin
    yamllint
    yq-go
  ];

  customPkgs = import ./pkgs/custom.nix {inherit pkgs username;};
  customPackages = with customPkgs; [
    fedoraHost
  ];

  # GPU-accelerated GUI apps. On a non-NixOS host their bundled Mesa looks for
  # drivers under /run/opengl-driver/lib (the NixOS path), which doesn't exist
  # on Fedora Silverblue / inside the toolbox — so GPU init fails and they fall
  # back to software rendering. nixGL wraps each binary with a consistent Nix
  # Mesa stack (mesa/nixGLIntel works for the AMD GPU too).
  # NOTE: only the bin wrapper is nixGL-aware. The toolbox desktop entries
  # launch these by bare command name, so the wrapped bin on PATH takes effect.
  graphicalPackages = map config.lib.nixGL.wrap (with pkgs; [
    winboat
    discord
    _1password-gui
    dropbox
    slack
  ]);

  # shared settings across various programs
  terminalType = "screen-256color";
  terminalHistoryLimit = 100000;

  # Optional private config (RH-internal dnf repos/copr/packages, hostnames…).
  # Made visible to the flake by staging it in the Git index; flakes ignore
  # untracked files, so an absent file falls back to an empty attrset.
  private =
    if builtins.pathExists ./home-private.nix
    then import ./home-private.nix
    else {};
in {
  home.username = username;
  home.homeDirectory = homeDirectory;

  home.stateVersion = "23.11";

  home.packages = nixPackages ++ customPackages ++ graphicalPackages;

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

    # tmt
    TMT_WORKDIR_ROOT = "$HOME/.local/share/tmt";

    # python requests
    REQUESTS_CA_BUNDLE = "/etc/pki/tls/certs/ca-bundle.crt";

    # dgoss
    CONTAINER_RUNTIME = "podman";

    # testing-farm CLI
    TESTING_FARM_PUBLIC_IP_RESOLVE_TRIES = 10;
    # Tighter watch tick makes `testing-farm watch` feel responsive.
    TESTING_FARM_WATCH_TICK = 3;
  };

  vault = {
    enable = true;
    unseal = {
      method = "1password";
      onePassword = {
        unsealKeyRef = "op://redhat/hashicorp-vault/unseal-key";
        rootTokenRef = "op://redhat/hashicorp-vault/root-token";
      };
    };
    bootstrap.onePassword.vault = "redhat";
    plugins = [
      (import ./pkgs/vault-plugin-secrets-github.nix {inherit pkgs;})
      (import ./pkgs/vault-plugin-secrets-gitlab.nix {inherit pkgs;})
    ];

    # GitHub App installation tokens expire after 1h. The github-thrix MCP
    # server (run via toolhive) reads the token from the encrypted toolhive
    # secret `github_thrix_token` once at start, so it cannot refresh in
    # place. Re-mint the token and restart the server before expiry.
    refreshTimers.github-thrix = {
      interval = "45min";
      script = ''
        token=$(vault read -field=token github/token installation_id=135664734) || exit 0
        [ -n "$token" ] || { echo "no token returned from vault"; exit 0; }
        echo "minted github token (length ''${#token})"
        printf '%s' "$token" | thv secret set github_thrix_token
        # thv restart does NOT re-resolve secrets — it reuses the old env.
        # Full stop+rm+run is required to pick up the updated secret.
        echo "recreating github-thrix with fresh token"
        thv stop github-thrix 2>/dev/null || true
        thv rm github-thrix 2>/dev/null || true
        thv run \
          --name github-thrix \
          --transport stdio \
          -e MCP_TRANSPORT=stdio \
          --secret github_thrix_token,target=GITHUB_PERSONAL_ACCESS_TOKEN \
          ghcr.io/github/github-mcp-server:v0.23.0
      '';
    };

    # GitLab group access tokens, minted via the vault-plugin-secrets-gitlab
    # engine (roles `com` and `cee`). Same problem as github-thrix: the gitlab
    # MCP server reads its token from a toolhive secret once at start, so
    # re-mint and recreate it before the token's lease expires. One timer per
    # instance — gitlab.com and gitlab.cee.redhat.com.
    refreshTimers.gitlab-mcp = {
      interval = "45min";
      script = ''
        token=$(vault read -field=token gitlab/token/com) || exit 0
        [ -n "$token" ] || { echo "no token returned from vault"; exit 0; }
        echo "minted gitlab.com token (length ''${#token})"
        printf '%s' "$token" | thv secret set gitlab_token
        echo "recreating gitlab-mcp with fresh token"
        thv stop gitlab-mcp 2>/dev/null || true
        thv rm gitlab-mcp 2>/dev/null || true
        thv run \
          --name gitlab-mcp \
          --transport stdio \
          -e MCP_TRANSPORT=stdio \
          -e USE_PIPELINE=true \
          -e USE_MILESTONE=true \
          --secret gitlab_token,target=GITLAB_PERSONAL_ACCESS_TOKEN \
          ghcr.io/thrix/gitlab-mcp:latest
      '';
    };

    refreshTimers.gitlab-cee-mcp = {
      interval = "45min";
      script = ''
        token=$(vault read -field=token gitlab/token/cee) || exit 0
        [ -n "$token" ] || { echo "no token returned from vault"; exit 0; }
        echo "minted gitlab.cee token (length ''${#token})"
        printf '%s' "$token" | thv secret set gitlab_cee_token
        echo "recreating gitlab-cee-mcp with fresh token"
        thv stop gitlab-cee-mcp 2>/dev/null || true
        thv rm gitlab-cee-mcp 2>/dev/null || true
        thv run \
          --name gitlab-cee-mcp \
          --transport stdio \
          -e MCP_TRANSPORT=stdio \
          -e USE_PIPELINE=true \
          -e USE_MILESTONE=true \
          -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
          -e GITLAB_API_URL=https://gitlab.cee.redhat.com/api/v4 \
          --secret gitlab_cee_token,target=GITLAB_PERSONAL_ACCESS_TOKEN \
          ghcr.io/thrix/gitlab-mcp:latest
      '';
    };
  };

  dnf = {
    enable = true;
    # Packages from public Fedora repos. RH-internal repos, the qa-tools Copr,
    # and packages that need them live in home-private.nix (merged below).
    install =
      [
        # toolchain / build deps
        "autoconf"
        "automake"
        "clang"
        "expect"
        "gcc"
        "git"
        "golang"
        "inotify-tools"
        "krb5-devel"
        "libcurl-devel"
        "libffi-devel"
        "libpq-devel"
        "libtool"
        "libvirt-devel"
        "libxml2-devel"
        "libxslt-devel"
        "nodejs-npm"
        "openssl-devel"
        "popt-devel"
        "python3"
        "python3-devel"
        "python3.9"
        "python3-libselinux"
        "python3-rpm"
        "redhat-rpm-config"
        "rpm-build"

        # CLI tools / utilities
        "bind-utils"
        "bootc"
        "btop"
        "codespell"
        "copyq"
        "diskus"
        "direnv"
        "eza"
        "gcal"
        "git-lfs"
        "gum"
        "hugo"
        "ImageMagick"
        "jq"
        "ncdu"
        "openldap-clients"
        "parallel"
        "pipx"
        "poppler-utils"
        "postgresql"
        "sqlite"
        "tig"
        "trivy"
        "valkey"
        "xxd"

        # containers / virtualization
        "buildah"
        "gitleaks"
        "helm"
        "libvirt"
        "podman"
        "podman-docker"
        "skopeo"
        "virt-manager"
        "virt-viewer"
        "wine"
        "winetricks"

        # python libraries
        "python3-boto3"
        "python3-botocore"
        "python3-fedora-distro-aliases"
        "python3-hvac"
        "python3-jinja2-cli"
        "python3-nitrate"
        "python3-openstacksdk"

        # ansible / testing
        "ansible"
        "ansible-core"
        "beakerlib"
        "hatch"
        "pre-commit"
        "python3-hatch-vcs"
        "rubygem-asciidoctor"
        "standard-test-roles"
        "tmt+provision-virtual"
        "tox"

        # Fedora/RHEL packaging & cloud tooling
        "awscli2"
        "bodhi-client"
        "centpkg"
        "koji"
        "krb5-workstation"

        # java
        "java-latest-openjdk-devel"
      ]
      ++ (private.dnfInstall or []);

    # RH-internal yum repos (e.g. beaker) — defined in home-private.nix.
    repos = private.dnfRepos or {};

    # Copr repositories (e.g. the internal qa-tools hub) — from home-private.nix.
    copr = private.dnfCopr or [];

    # releaseInstall = {
    #   "41" = ["some-f41-item"];
    # };
    # upgradeAll = false;
  };

  hostConfig = {
    enable = true;
    xdgDesktopEntries = true;
    files = [
      ".config/foot/foot.ini"
      ".config/sway/config"
      ".config/waybar/config"
      ".config/waybar/style.css"
      ".local/share/applications/mimeapps.list"
      ".mozilla/firefox/profiles.ini"
      ".mozilla/firefox/${username}/containers.json"
      ".mozilla/firefox/${username}/search.json.mozlz4"
      ".mozilla/firefox/${username}/user.js"
    ];
  };

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

      # forges
      gh = "GITHUB_TOKEN=\$(ght) gh";
      glab = "run-op plugin run -- glab";

      # vault
      ght = "vault read -field=token github/token installation_id=135664734";
      glt = "vault read -field=token gitlab/token/com";
      glt-cee = "vault read -field=token gitlab/token/cee";

      # redhat
      rh-kinit = "op read \"op://redhat/Red\\ Hat\\ Kerberos/password\" | kinit $(op read \"op://redhat/Red\\ Hat\\ Kerberos/kinit_username\")";
      oc-login-osd = "oc login --server=https://api.cyborg.fio9.p1.openshiftapps.com:6443 --token=$(ocp-sso-token https://api.cyborg.fio9.p1.openshiftapps.com:6443)";
      oc-login-mp = "oc login --server https://api.mpp-e1-prod.9e4s.p1.openshiftapps.com:6443 --token=$(ocp-sso-token https://api.mpp-e1-prod.9e4s.p1.openshiftapps.com:6443)";
      oc-login-itup = "oc login --server https://api.prod-scale-spoke1-aws-us-east-1.prod-scale-mgmthub1-aws-us-east-1.itup.redhat.com:443 --token=$(ocp-sso-token https://api.prod-scale-spoke1-aws-us-east-1.prod-scale-mgmthub1-aws-us-east-1.itup.redhat.com:443)";
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
    configPath = ".mozilla/firefox";

    profiles = {
      default = {
        # Keep the generated profile path aligned with hostConfig.files and
        # the Silverblue host Firefox instance.
        name = username;
        path = username;
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

      key-bindings = {
        show-urls-copy = "Control+Shift+y";
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

    settings = {
      alias = {
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

      user = {
        name = "Miroslav Vadkerti";
        email = "mvadkert@redhat.com";
      };

      init = {
        defaultBranch = "main";
      };

      push = {
        autoSetupRemote = "true";
      };

      signing.format = "openpgp";
    };
  };

  # Git Diffstatic
  programs.difftastic = {
    enable = true;
    git.enable = true;
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
      list = true;
      listchars = "tab:› ,space:·,leadmultispace:· ,trail:·,precedes:«,extends:»,eol:¬";
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

    # Plugins
    plugins = import ./nixvim/plugins.nix;

    # Extra plugins not managed by nixvim modules
    extraPlugins = [pkgs.vimPlugins.plenary-nvim];

    # Extra config
    extraConfigLua = ''
      vim.filetype.add({
        extension = {
          fmf = "yaml",
        },
      })
    '';
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
      # Chrome lives on the Fedora host, but the sway session (and its
      # launchers) run inside the nix-toolbox container. Exec calls the
      # fedoraHost `google-chrome` wrapper, which delegates to the host via
      # flatpak-spawn (same pattern as the firefox wrapper). Keeping Exec a
      # plain command (no shell metacharacters) satisfies desktop-file-validate,
      # and the first word `google-chrome` resolves both in the container (the
      # wrapper) and on the host (/usr/bin/google-chrome), so
      # `xdg-settings set default-web-browser google-chrome.desktop` no longer
      # fails validation from either side.
      "google-chrome" = {
        name = "Google Chrome";
        genericName = "Web Browser";
        type = "Application";
        exec = "google-chrome %U";
        icon = "google-chrome";
        categories = ["Network" "WebBrowser"];
        mimeType = ["text/html" "x-scheme-handler/http" "x-scheme-handler/https"];
      };
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
