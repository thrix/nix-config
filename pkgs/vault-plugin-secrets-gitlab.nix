{pkgs, ...}:
pkgs.stdenv.mkDerivation rec {
  pname = "vault-plugin-secrets-gitlab";
  version = "0.12.1";

  src = pkgs.fetchurl {
    url = "https://github.com/ilijamt/${pname}/releases/download/v${version}/${pname}_linux_x86_64.tar.gz";
    hash = "sha256-Vy1aX2GyW35i6bWaOb1jkpjiuAflpi4ntrDFcY1b1ug=";
  };

  dontUnpack = true;

  # The release tarball ships the binary versioned (…_v0.12.1). Vault registers
  # a plugin by its command (binary) name, so rename it to the bare pname to
  # match how `vault-setup-gitlab` registers it.
  installPhase = ''
    mkdir -p $out/bin
    tar -xzf $src ${pname}_v${version}
    cp ${pname}_v${version} $out/bin/${pname}
    chmod +x $out/bin/${pname}
  '';
}
