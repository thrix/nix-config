{pkgs, ...}: {
  fedoraHost = pkgs.stdenv.mkDerivation {
    name = "fedoraHost";
    src = null;

    buildInputs = [];

    phases = ["installPhase"];

    installPhase = ''
            mkdir -p $out/bin

            cat <<EOF > $out/bin/buildah
      #!/bin/bash
      /usr/bin/flatpak-spawn --host buildah "\$@"
      EOF

            cat <<EOF > $out/bin/bootc
      #!/bin/bash
      /usr/bin/flatpak-spawn --host pkexec bootc "\$@"
      EOF

            cat <<EOF > $out/bin/firefox
      #!/bin/bash
      /usr/bin/flatpak-spawn --env=DISPLAY=:0 --host firefox "\$@"
      EOF

            cat <<EOF > $out/bin/flatpak
      #!/bin/bash
      /usr/bin/flatpak-spawn --host flatpak "\$@"
      EOF

            cat <<EOF > $out/bin/podman
      #!/bin/bash
      /usr/bin/flatpak-spawn --host podman "\$@"
      EOF

            cat <<EOF > $out/bin/rpm-ostree
      #!/bin/bash
      /usr/bin/flatpak-spawn --host rpm-ostree "\$@"
      EOF

            cat <<EOF > $out/bin/swaymsg
      #!/bin/bash
      /usr/bin/flatpak-spawn --host swaymsg "\$@"
      EOF

            cat <<EOF > $out/bin/xdg-open
      #!/bin/bash
      /usr/bin/flatpak-spawn --env=DISPLAY=:0 --host xdg-open "\$@"
      EOF

            cat <<EOF > $out/bin/testing-farm-public
      #!/bin/bash
      TESTING_FARM_API_TOKEN=\$(sg onepassword-cli -c "op read op://testing-farm/ccyqkqhkeqalbxnuhgft4lli2y/notesPlain") testing-farm "\$@"
      EOF

            cat <<EOF > $out/bin/testing-farm-admin-public
      #!/bin/bash
      TESTING_FARM_API_TOKEN=\$(sg onepassword-cli -c "op read op://testing-farm/7coocnzmv53riasn3dh3pk3yue/notesPlain") testing-farm "\$@"
      EOF

            cat <<EOF > $out/bin/testing-farm-redhat
      #!/bin/bash
      TESTING_FARM_API_TOKEN=\$(sg onepassword-cli -c "op read op://testing-farm/b2n7fihogcxd75sy6qdva7bw7e/notesPlain") testing-farm "\$@"
      EOF

            cat <<EOF > $out/bin/testing-farm-admin-redhat
      #!/bin/bash
      TESTING_FARM_API_TOKEN=\$(sg onepassword-cli -c "op read op://testing-farm/m2572j34froftf4sespnsuippi/notesPlain") testing-farm "\$@"
      EOF

            cat <<EOF > $out/bin/testing-farm-staging-public
      #!/bin/bash
      TESTING_FARM_API_URL=http://api.staging.testing-farm.io/v0.1 \
      TESTING_FARM_API_TOKEN=\$(sg onepassword-cli -c "op read op://testing-farm/ccyqkqhkeqalbxnuhgft4lli2y/notesPlain") \
      testing-farm "\$@"
      EOF

            cat <<EOF > $out/bin/rh-jira
      #!/bin/bash
      JIRA_API_TOKEN=\$(sg onepassword-cli -c "op read op://redhat/2hc7nqkhez4bjab6vsh737at3m/notesPlain") \
      jira "\$@"
      EOF

            cat <<EOF > $out/bin/ujust
      #!/bin/bash
      /usr/bin/flatpak-spawn --host ujust "\$@"
      EOF

            cat <<EOF > $out/bin/bluebuild
      #!/bin/bash
      /run/host/bin/bluebuild "\$@"
      EOF

            chmod +x $out/bin/*
    '';
  };
}
