{pkgs, ...}: {
  sway = pkgs.stdenv.mkDerivation {
    name = "swayFedora";
    src = null;

    buildInputs = [];

    phases = ["installPhase"];

    installPhase = ''
            mkdir -p $out/bin

            # swaymsg
            cat <<EOF > $out/bin/swaymsg
      #!/bin/bash
      /usr/bin/flatpak-spawn --host swaymsg "\$@"
      EOF

            chmod +x $out/bin/swaymsg
    '';
  };
}
