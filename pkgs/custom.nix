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

            cat <<EOF > $out/bin/google-chrome
      #!/bin/bash
      /usr/bin/flatpak-spawn --env=DISPLAY=:0 --host google-chrome "\$@"
      EOF

            cat <<EOF > $out/bin/flatpak
      #!/bin/bash
      /usr/bin/flatpak-spawn --host flatpak "\$@"
      EOF

            cat <<EOF > $out/bin/podman
      #!/bin/bash
      /usr/bin/flatpak-spawn --host podman "\$@"
      EOF

            cat <<'EOF' > $out/bin/run-op
      #!/bin/bash
      cmd=(op "$@")
      printf -v quoted_cmd ' %q' "''${cmd[@]}"
      exec sg onepassword-cli -c "exec$quoted_cmd"
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
      export CLAUDE_CODE_USE_SANDBOX=1
      export CLAUDE_CODE_USE_VERTEX=1
      export CLOUD_ML_REGION=global
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
      poetry -C "\$HOME/git/gitlab.cee/baseos-qe/ansible-baseos-ci/cli" run tft-admin "\$@"
      EOF

            cat <<'EOF' > $out/bin/vault-setup-github
      #!/bin/bash
      set -euo pipefail

      VAULT_ADDR="''${VAULT_ADDR:-http://127.0.0.1:8200}"
      export VAULT_ADDR

      PLUGIN_NAME="vault-plugin-secrets-github"
      PLUGIN_PATH="$HOME/.vault-server/plugins/$PLUGIN_NAME"

      echo "=== Vault GitHub App Secrets Engine Setup ==="
      echo ""

      if ! vault status -format=json 2>/dev/null | jq -e '.sealed == false' >/dev/null 2>&1; then
        echo "ERROR: Vault is not running or is sealed."
        exit 1
      fi

      if [ ! -f "$PLUGIN_PATH" ]; then
        echo "ERROR: Plugin not found at $PLUGIN_PATH"
        echo "Run 'make switch' to install the plugin binary."
        exit 1
      fi

      echo "Registering plugin..."
      SHA=$(sha256sum "$PLUGIN_PATH" | cut -d' ' -f1)
      vault plugin register -sha256="$SHA" secret "$PLUGIN_NAME"

      echo "Enabling secrets engine at github/..."
      vault secrets enable -path=github "$PLUGIN_NAME" 2>/dev/null || echo "(already enabled)"

      echo ""
      read -rp "GitHub App ID: " app_id
      read -rp "Installation ID (for token requests): " install_id
      read -rp "Path to private key (.pem): " pem_path

      if [ ! -f "$pem_path" ]; then
        echo "ERROR: File not found: $pem_path"
        exit 1
      fi

      # Config takes only app_id + prv_key. installation_id is a token-request
      # parameter, not config.
      echo "Configuring GitHub App..."
      vault write github/config \
        app_id="$app_id" \
        prv_key=@"$pem_path"

      echo ""
      echo "Verifying — requesting a token..."
      if vault read -field=token github/token installation_id="$install_id" 2>/dev/null; then
        echo ""
        echo "Success! GitHub App secrets engine is configured."
      else
        echo ""
        echo "WARNING: Could not generate a token."
        echo "Check that the GitHub App is installed on your account/org."
      fi

      echo ""
      echo "Usage:"
      echo "  vault read -field=token github/token installation_id=$install_id"
      echo "  export GITHUB_TOKEN=\$(ght)"
      echo ""
      echo "Set 'ght' alias installation ID in home.nix:"
      echo "  ght = \"vault read -field=token github/token installation_id=$install_id\";"
      EOF

            cat <<'EOF' > $out/bin/vault-setup-gitlab
      #!/bin/bash
      set -euo pipefail

      VAULT_ADDR="''${VAULT_ADDR:-http://127.0.0.1:8200}"
      export VAULT_ADDR

      PLUGIN_NAME="vault-plugin-secrets-gitlab"
      PLUGIN_PATH="$HOME/.vault-server/plugins/$PLUGIN_NAME"

      echo "=== Vault GitLab Access Token Secrets Engine Setup ==="
      echo ""

      if ! vault status -format=json 2>/dev/null | jq -e '.sealed == false' >/dev/null 2>&1; then
        echo "ERROR: Vault is not running or is sealed."
        exit 1
      fi

      if [ ! -f "$PLUGIN_PATH" ]; then
        echo "ERROR: Plugin not found at $PLUGIN_PATH"
        echo "Run 'make switch' to install the plugin binary."
        exit 1
      fi

      echo "Registering plugin..."
      SHA=$(sha256sum "$PLUGIN_PATH" | cut -d' ' -f1)
      vault plugin register -sha256="$SHA" secret "$PLUGIN_NAME"

      echo "Enabling secrets engine at gitlab/..."
      vault secrets enable -path=gitlab "$PLUGIN_NAME" 2>/dev/null || echo "(already enabled)"

      echo ""
      echo "Configure one GitLab instance + role per run."
      echo "Use name 'com' for gitlab.com and 'cee' for gitlab.cee.redhat.com"
      echo "to match the 'glt'/'glt-cee' aliases and refresh timers in home.nix."
      echo ""
      read -rp "Config/role name [com]: " name
      name="''${name:-com}"

      default_url="https://gitlab.com"
      default_type="gitlab-com"
      if [ "$name" = "cee" ]; then
        default_url="https://gitlab.cee.redhat.com"
        default_type="self-managed"
      fi

      read -rp "GitLab base URL [$default_url]: " base_url
      base_url="''${base_url:-$default_url}"
      read -rp "Instance type (gitlab-com/self-managed/dedicated) [$default_type]: " gl_type
      gl_type="''${gl_type:-$default_type}"
      # Token read from stdin (never via argv) so it does not land in the
      # process list. Needs api scope + Owner on the group below.
      read -rsp "GitLab token (api scope, Owner on the group): " gl_token
      echo ""
      read -rp "Group full path (e.g. mygroup or mygroup/subgroup): " group_path
      read -rp "Token scopes (comma separated) [api]: " scopes
      scopes="''${scopes:-api}"
      read -rp "Access level (guest/reporter/developer/maintainer/owner) [maintainer]: " access_level
      access_level="''${access_level:-maintainer}"
      # GitLab expires tokens at date granularity, but with gitlab_revokes_token
      # left at its default Vault revokes the token at lease end, so a sub-day
      # ttl is genuinely short-lived (mirrors the 1h GitHub tokens).
      read -rp "Token TTL [1h]: " ttl
      ttl="''${ttl:-1h}"

      echo ""
      echo "Writing config gitlab/config/$name..."
      printf '%s' "$gl_token" | vault write "gitlab/config/$name" \
        base_url="$base_url" \
        type="$gl_type" \
        token=-

      echo "Writing role gitlab/roles/$name..."
      vault write "gitlab/roles/$name" \
        path="$group_path" \
        name="vault-{{ .role_name }}-{{ randHexString 4 }}" \
        scopes="$scopes" \
        access_level="$access_level" \
        token_type=group \
        ttl="$ttl" \
        config_name="$name"

      echo ""
      echo "Verifying — requesting a token..."
      if vault read -field=token "gitlab/token/$name" >/dev/null 2>&1; then
        echo "Success! GitLab access tokens engine configured for '$name'."
      else
        echo "WARNING: Could not generate a token."
        echo "Check the configured token's scope/role and the group path."
      fi

      echo ""
      echo "Usage:"
      echo "  vault read -field=token gitlab/token/$name"
      echo "  export GITLAB_TOKEN=\$(glt)        # name=com"
      echo "  export GITLAB_TOKEN=\$(glt-cee)    # name=cee"
      echo ""
      echo "Run again with name 'cee' to configure gitlab.cee.redhat.com."
      EOF

            chmod +x $out/bin/*
    '';
  };
}
