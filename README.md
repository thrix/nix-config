# nix-config

Nix configurations of thrix.

Used to manage developer laptop based on Bootable Containers and [nix-toolbox](https://thrix.github.io/nix-toolbox).

## Home Manager Modules

### `hostConfig`

Materializes Home Manager symlinks as real files so the Silverblue host can read them from
outside the toolbox container. Useful for any config file that a host-side program (sway,
waybar, foot, firefox) needs to access directly.

#### Usage

In your `flake.nix`:

```nix
inputs = {
  nix-config = {
    url = "github:thrix/nix-config";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.home-manager.follows = "home-manager";
  };
};

homeConfigurations."alice" = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  modules = [
    inputs.nix-config.homeManagerModules.hostConfig
    ./home.nix
  ];
};
```

In your `home.nix`:

```nix
hostConfig = {
  enable = true;

  # Automatically materialize all xdg.desktopEntries as real files
  xdgDesktopEntries = true;

  # Any other Home Manager-managed files the host needs to read
  files = [
    ".config/sway/config"
    ".config/waybar/config"
  ];
};
```
