{pkgs, ...}:
pkgs.stdenv.mkDerivation rec {
  pname = "vault-plugin-secrets-github";
  version = "2.3.2";

  src = pkgs.fetchurl {
    url = "https://github.com/martinbaillie/${pname}/releases/download/v${version}/${pname}-linux-amd64";
    sha256 = "11xbxkfiw50wjakammrwp6xyfzrps1ly89dpzw9byapfflkizjvj";
  };

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/${pname}
    chmod +x $out/bin/${pname}
  '';
}
