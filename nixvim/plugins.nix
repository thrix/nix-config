{
  airline.enable = true;

  efmls-configs = {
    enable = true;

    setup = {
      go = {
        formatter = "gofmt";
        linter = "go_revive";
      };

      python = {
        formatter = "ruff";
        linter = "ruff";
      };
    };
  };

  lsp = {
    enable = true;

    servers = {
      ansiblels = {
        enable = true;
      };

      bashls = {
        enable = true;
      };

      nixd = {
        enable = true;
      };

      pyright = {
        enable = true;
      };

      yamlls = {
        enable = true;
      };
    };
  };

  mini = {
    enable = true;

    mockDevIcons = true;

    modules = {
      icons = {
        enable = true;
      };
    };
  };

  telescope = {
    enable = true;
  };

  treesitter = {
    enable = true;

    settings = {
      auto_install = true;
      ensure_installed = [
        "git_config"
        "git_rebase"
        "gitattributes"
        "gitcommit"
        "gitignore"
        "just"
        "make"
        "python"
      ];
    };
  };
}
