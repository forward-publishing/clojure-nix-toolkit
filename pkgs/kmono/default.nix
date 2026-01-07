{ stdenvNoCC, lib }:
let
  system = stdenvNoCC.hostPlatform.system;
  tarballs = {
    "x86_64-linux" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.3/kmono-linux-amd64.tar.gz";
      sha256 = "09jlx1j5wp7iy680zsrvik8d92v4lmg8f4vsmkcnhwg8pf5andca";
    };
    "aarch64-linux" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.3/kmono-linux-arm64.tar.gz";
      sha256 = "05jfyjh75lvkpv6x61m4vwasyh9karnqp6mj6z0xc1zmyiih3xq9";
    };
    "x86_64-darwin" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.3/kmono-macos-amd64.tar.gz";
      sha256 = "0a4a51f4knqi9q6ls047c2jmc269vgr7dci7vv1w01l94r67nl1y";
    };
    "aarch64-darwin" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.3/kmono-macos-arm64.tar.gz";
      sha256 = "11vrp5k5wzz4z9xs4pvb3iw8dipssvy1ngfszn04dxjyb94dg795";
    };
  };
  tarball = tarballs.${system};

in
stdenvNoCC.mkDerivation {
  pname = "kmono";
  version = "4.10.3";

  src = fetchTarball tarball;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m755 kmono $out/bin

    runHook postInstall
  '';

  meta = with lib; {
    description = "A monorepo/workspace tool for Clojure tools.deps projects";
    homepage = "https://github.com/kepler16/kmono";
    license = licenses.mit;
    maintainers = [ maintainers.oivanovs ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "kmono";
  };
}
