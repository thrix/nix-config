{lib, ...}: let
  modifier = "Mod4";
  terminal = "foot";
in {
  modifier = modifier;
  terminal = terminal;
  menu = "rofi -terminal '${terminal}' -show combi -combi-modes drun#run -modes combi";

  bars = [
    {
      position = "top";
      command = "waybar";
    }
  ];

  fonts = {
    size = 11.0;
  };

  keybindings = lib.mkOptionDefault {
    "${modifier}+Return" = "exec ${terminal} toolbox enter nix";
    "${modifier}+Shift+Return" = "exec ${terminal}";
  };

  output = {
    "*" = {
      bg = "$(ls ~/.config/home-manager/background/* | shuf -n1) fill";
    };
  };

  startup = [
    {
      command = "toolbox run --container nix 1password";
    }
  ];
}
