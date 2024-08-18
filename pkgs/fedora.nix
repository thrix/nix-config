{pkgs, ...}: {
  sway = pkgs.stdenv.mkDerivation {
    name = "swayFedora";
    src = null;

    buildInputs = [];

    phases = ["installPhase"];

    installPhase = ''
            mkdir -p $out/bin
            cat <<EOF > $out/bin/swaymsg
      #!/bin/bash
      flatpak-spawn --host swaymsg "\$@"
      EOF
            chmod +x $out/bin/swaymsg
    '';
  };
}
