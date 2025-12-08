{ stdenvNoCC }:
let
  system = stdenvNoCC.hostPlatform.system;
  tarballs = {
    "x86_64-linux" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.2/kmono-linux-amd64.tar.gz";
      sha256 = "0k10skmlmcfds37g1828sh19cx04c68r9qf9k2s7izczw0fk8ypl";
    };
    "aarch64-linux" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.2/kmono-linux-arm64.tar.gz";
      sha256 = "1n5b344ms9vj085p8f5k7ws6lkgcjx08r236l21sfh64hq74f44f";
    };
    "x86_64-darwin" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.2/kmono-macos-amd64.tar.gz";
      sha256 = "0gqh54xs94pl5ahxg6vzj18ac0ilvj1q31zcy98ny1cg6da4miqb";
    };
    "aarch64-darwin" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.2/kmono-macos-arm64.tar.gz";
      sha256 = "1ci5mhikw218l56z8dy1mflnh4s47nzbps29yflnyxz3n57hbx8a";
    };
  };
  tarball = tarballs.${system};

in
stdenvNoCC.mkDerivation {
  pname = "kmono";
  version = "4.10.2";

  src = fetchTarball tarball;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 kmono $out/bin 
  '';
}
