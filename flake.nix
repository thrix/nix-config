{
  description = "Nix configuration of thrix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      # https://github.com/nix-community/home-manager/pull/5074
      url = "github:nix-community/home-manager";
      # url = "github:thrix/home-manager/waybar-package-null";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nixvim, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations."thrix" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [ 
	  nixvim.homeManagerModules.nixvim
	  ./home.nix
	];
      };
    };
}
