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
    "${modifier}+Return" = "exec ${terminal} toolbox enter nix --silent";
    "${modifier}+Shift+Return" = "exec ${terminal}";
    "${modifier}+Shift+p" = "exec toolbox run --container nix 1password --quick-access";
  };

  output = {
    "*" = {
      bg = "$(ls ~/.config/home-manager/background/* | shuf -n1) fill";
    };
  };

  startup = [
    {
      command = "toolbox run --container nix 1password --silent";
      always = true;
    }
    {
      command = "/usr/libexec/polkit-gnome-authentication-agent-1";
      always = true;
    }
    {
      command = "nm-applet";
      always = true;
    }
  ];
}
