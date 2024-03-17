{
  mainBar = {
    height = 30;
    spacing = 3;
    modules-left = [
      "sway/workspaces"
      "sway/mode"
      "sway/scratchpad"
    ];
    modules-center = [
      # "sway/window"
      "idle_inhibitor"
    ];
    modules-right = [
      "pulseaudio"
      "network"
      "cpu"
      "memory"
      "temperature"
      "backlight"
      "keyboard-state"
      "battery"
      "battery#bat2"
      "sway/language"
      "clock"
      "tray"
    ];
    keyboard-state = {
      numlock = true;
      capslock = true;
      format = "{name} {icon}";
      format-icons = {
        locked = "";
        unlocked = "";
      };
    };
    "sway/language" = {
      format = "{flag} {short}";
    };
    "sway/mode" = {
      format = "<span style=\"italic\">{}</span>";
    };
    "sway/scratchpad" = {
      format = "{icon} {count}";
      show-empty = false;
      format-icons = ["" ""];
      tooltip = true;
      tooltip-format = "{app}: {title}";
    };
    idle_inhibitor = {
      format = "{icon}";
      format-icons = {
        activated = "";
        deactivated = "";
      };
    };
    tray = {
      icon-size = 21;
      spacing = 10;
    };
    clock = {
      timezone = "Europe/Prague";
      tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      format = "{:%H:%M:%S}";
      format-alt = "{:%Y-%m-%d}";
      interval = 1;
    };
    cpu = {
      format = "{usage}% ";
      tooltip = false;
    };
    memory = {
      format = "{}% ";
    };
    temperature = {
      # thermal-zone = 2;
      # hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
      critical-threshold = 80;
      # format-critical = "{temperatureC}°C {icon}";
      format = "{temperatureC}°C {icon}";
      format-icons = ["" "" ""];
    };
    backlight = {
      # device = "acpi_video1";
      format = "{percent}% {icon}";
      format-icons = [""];
    };
    battery = {
      states = {
        # good = 95;
        warning = 30;
        critical = 15;
      };
      format = "{capacity}% {icon}";
      format-charging = "{capacity}% ";
      format-plugged = "{capacity}% ";
      format-alt = "{time} {icon}";
      # format-good = "", # An empty format will hide the module
      # format-full = "";
      format-icons = ["" "" "" "" ""];
    };
    "battery#bat2" = {
      bat = "BAT2";
    };
    network = {
      format-wifi = "{essid} ({signalStrength}%) ";
      format-ethernet = "{ipaddr}/{cidr} ";
      tooltip-format = "{ifname} via {gwaddr} ";
      format-linked = "{ifname} (No IP) ";
      format-disconnected = "Disconnected ⚠";
      format-alt = "{ifname}: {ipaddr}/{cidr}";
    };
    pulseaudio = {
      format = "{volume}% {icon} {format_source}";
      format-bluetooth = "{volume}% {icon} {format_source}";
      format-bluetooth-muted = " {icon} {format_source}";
      format-muted = " {format_source}";
      format-source = "{volume}% ";
      format-source-muted = "";
      format-icons = {
        headphone = "";
        hands-free = "";
        headset = "";
        phone = "";
        portable = "";
        car = "";
        default = ["" "" ""];
      };
      on-click = "pavucontrol";
    };
  };
}
