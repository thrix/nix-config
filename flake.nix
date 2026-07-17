{
  description = "Nix configuration of thrix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs.url = "github:thrix/nixpkgs/dgoss-fix-binary";

    # pinned nixpkgs for winboat — Go 1.26.1 cross-compilation is broken
    # https://github.com/NixOS/nixpkgs/issues/503112
    nixpkgs-winboat.url = "github:nixos/nixpkgs/e38213b91d3786389a446dfce4ff5a8aaf6012f2";

    # pinned nixpkgs for claude-code — nixos-unstable lags master; this commit
    # bumps claude-code to 2.1.170 (Fable 5)
    nixpkgs-claude.url = "github:nixos/nixpkgs/19c1fe4ff9335a9db73772c633e13ac4c7e1897a";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nixpkgs-winboat,
    nixpkgs-claude,
    home-manager,
    nixvim,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        # use winboat from pinned nixpkgs until Go cross-compilation is fixed
        # https://github.com/NixOS/nixpkgs/issues/503112
        (_final: _prev: {
          winboat = (import nixpkgs-winboat {inherit system;}).winboat;
        })
        # use claude-code from pinned nixpkgs master until nixos-unstable catches up
        (_final: _prev: {
          claude-code =
            (import nixpkgs-claude {
              inherit system;
              config.allowUnfree = true;
            }).claude-code;
        })
      ];
    };
  in {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.alejandra;

    homeManagerModules = {
      dnf = import ./modules/dnf.nix;
      hostConfig = import ./modules/host-config.nix;
    };

    homeConfigurations."thrix" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;

      modules = [
        nixvim.homeModules.nixvim
        ./modules/dnf.nix
        ./modules/host-config.nix
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
        ./home.nix
      ];

      extraSpecialArgs = {
        username = "mvadkert";
        homeDirectory = "/home/mvadkert";
      };
    };
  };
}
