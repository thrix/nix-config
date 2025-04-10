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
    # terminal
    "${modifier}+Return" = "exec ${terminal} toolbox enter nix";
    "${modifier}+Shift+Return" = "exec ${terminal}";

    # 1password
    "${modifier}+Shift+p" = "exec toolbox run --container nix 1password --quick-access";

    # brightness
    "XF86KbdBrightnessUp" = "exec brightnessctl s 5%+";
    "XF86MonBrightnessUp" = "exec brightnessctl s 5%+";
    "XF86KbdBrightnessDown" = "exec brightnessctl s 5%-";
    "XF86MonBrightnessDown" = "exec brightnessctl s 5%-";

    # audio
    "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
    "XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +5%";
    "XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -5%";

    # emoticon chooser
    "Ctrl+Alt+e" = "exec flatpak run com.tomjwatson.Emote";

    # screen lock
    "Ctrl+Alt+l" = "exec swaylock";
  };

  input = {
    "*" = {
      # NOTE: this influences waybar
      "xkb_layout" = "us,cz(qwerty)";
      # NOTE: alt+shift to toggle keyboard layout
      # NOTE: capslock detection in waybar needs settings both capslocks
      #       https://github.com/Alexays/Waybar/issues/2215
      "xkb_options" = "grp:alt_shift_toggle";
    };
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
      # NOTE: Fedora 41 removed polkit-gnome, use `mate-polkit` instead
      command = "/usr/libexec/polkit-mate-authentication-agent-1";
      always = true;
    }
    {
      command = "nm-applet";
      always = true;
    }
    {
      # https://github.com/swaywm/sway/wiki#systemd-and-dbus-activation-environments
      command = "dbus-update-activation-environment --systemd --all";
      always = true;
    }
  ];
}
