{
  description = "Nix configuration of thrix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # nixpkgs.url = "github:thrix/nixpkgs/dgoss-fix-binary";

    # EXAMPLE: pin free package
    # pinned nixpkgs for winboat — Go 1.26.1 cross-compilation is broken
    # https://github.com/NixOS/nixpkgs/issues/503112
    # nixpkgs-winboat.url = "github:nixos/nixpkgs/e38213b91d3786389a446dfce4ff5a8aaf6012f2";

    # pinned nixpkgs for claude-code — 2.1.219 adds Claude Opus 5 support, which
    # nixpkgs-unstable doesn't have yet. This is the head of the open bump PR
    # NixOS/nixpkgs#545319; drop the pin once it merges.
    nixpkgs-claude.url = "github:samestep/nixpkgs/e29c342b51311d226c93f22b5d431f44f707760c";

    # pinned nixpkgs for rtk — 0.43.0 was merged to master (NixOS/nixpkgs#545266)
    # but nixpkgs-unstable hasn't caught up yet; drop once it does.
    nixpkgs-rtk.url = "github:nixos/nixpkgs/02508d54de0308f84f80830e86b9d95a6fdd6d62";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixGL wraps Nix-built graphical apps so they find GPU drivers on a
    # non-NixOS host (Fedora Silverblue). Used to give winboat hardware accel.
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    # nixpkgs-winboat,
    nixpkgs-claude,
    nixpkgs-rtk,
    home-manager,
    nixvim,
    nixgl,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        # use winboat from pinned nixpkgs until Go cross-compilation is fixed
        # https://github.com/NixOS/nixpkgs/issues/503112
        # (_final: _prev: {
        #   winboat = (import nixpkgs-winboat {inherit system;}).winboat;
        # })
        # use claude-code from the pinned bump PR until it lands in nixpkgs-unstable
        (_final: _prev: {
          claude-code =
            (import nixpkgs-claude {
              inherit system;
              config.allowUnfree = true;
            }).claude-code;
        })
        # use rtk 0.43.0 from master (NixOS/nixpkgs#545266) until nixpkgs-unstable catches up
        (_final: _prev: {
          rtk = (import nixpkgs-rtk {inherit system;}).rtk;
        })
      ];
    };
  in {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;

    homeManagerModules = {
      dnf = import ./modules/dnf.nix;
      hostConfig = import ./modules/host-config.nix;
      vault = import ./modules/vault.nix;
    };

    homeConfigurations."thrix" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [
        nixvim.homeModules.nixvim
        ./modules/dnf.nix
        ./modules/host-config.nix
        ./modules/vault.nix
        # Expose nixGL packages so home.nix can wrap GPU apps (winboat).
        {targets.genericLinux.nixGL.packages = nixgl.packages;}
        ./home.nix
      ];

      extraSpecialArgs = {
        username = "thrix";
        homeDirectory = "/home/thrix";
      };
    };

    homeConfigurations."mvadkert" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [
        nixvim.homeModules.nixvim
        ./modules/dnf.nix
        ./modules/host-config.nix
        ./modules/vault.nix
        # Expose nixGL packages so home.nix can wrap GPU apps (winboat).
        {targets.genericLinux.nixGL.packages = nixgl.packages;}
        ./home.nix
      ];

      extraSpecialArgs = {
        username = "mvadkert";
        homeDirectory = "/home/mvadkert";
      };
    };
  };
}
