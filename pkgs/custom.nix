{
  pkgs,
  username,
  ...
}: {
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
      TESTING_FARM_API_URL=https://api.staging.testing-farm.io/v0.1 \
      TESTING_FARM_API_TOKEN=\$(sg onepassword-cli -c "op read op://testing-farm/ccyqkqhkeqalbxnuhgft4lli2y/notesPlain") \
      testing-farm "\$@"
      EOF

            cat <<EOF > $out/bin/testing-farm-local
      #!/bin/bash
      TESTING_FARM_API_URL=http://localhost:8001/v0.1 \
      TESTING_FARM_API_TOKEN=developer testing-farm "\$@"
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

            cat <<EOF > $out/bin/claude-redhat
      #!/bin/bash
      export CLAUDE_CODE_USE_VERTEX=1
      export CLOUD_ML_REGION=us-east5
      export ANTHROPIC_VERTEX_PROJECT_ID=itpc-gcp-core-pe-eng-claude
      claude "\$@"
      EOF

            cat <<EOF > $out/bin/artemis-redhat-production
      #!/bin/bash
      poetry -C \$HOME/git/gitlab.com/testing-farm/artemis/cli run artemis-cli --config \$HOME/.config/artemis-redhat-production "\$@"
      EOF

            cat <<EOF > $out/bin/artemis-redhat-staging
      #!/bin/bash
      poetry -C \$HOME/git/gitlab.com/testing-farm/artemis/cli run artemis-cli --config \$HOME/.config/artemis-redhat-staging "\$@"
      EOF

            cat <<EOF > $out/bin/artemis-redhat-devel
      #!/bin/bash
      poetry -C \$HOME/git/gitlab.com/testing-farm/artemis/cli run artemis-cli --config \$HOME/.config/artemis-redhat-devel "\$@"
      EOF

            cat <<EOF > $out/bin/artemis-public-production
      #!/bin/bash
      poetry -C \$HOME/git/gitlab.com/testing-farm/artemis/cli run artemis-cli --config \$HOME/.config/artemis-public-production "\$@"
      EOF

            cat <<EOF > $out/bin/artemis-public-${username}
      #!/bin/bash
      poetry -C \$HOME/git/gitlab.com/testing-farm/artemis/cli run artemis-cli --config \$HOME/.config/artemis-public-${username} "\$@"
      EOF

            cat <<EOF > $out/bin/tft-admin
      #!/bin/bash
      poetry -C \$HOME/git/gitlab.cee/baseos-qe/ansible-baseos-ci/cli run tft-admin "\$@"
      EOF

            chmod +x $out/bin/*
    '';
  };
}
