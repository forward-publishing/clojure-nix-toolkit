{ stdenvNoCC }:
let
  system = stdenvNoCC.hostPlatform.system;
  tarballs = {
    "x86_64-linux" = {
      url = "https://github.com/kepler16/kmono/releases/download/v4.10.3/kmono-linux-amd64.tar.gz";
      sha256 = "0g5yksvl5ylv2ch5n6i34cmx7chsqhsch86a267990831vjg76x8";
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
      sha256 = "0j5adycfvgs3bnip2b113yvxi037kqv6pqdwb1cjjz11n2s78k0f";
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
  '';
}
