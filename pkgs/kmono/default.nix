{
  stdenvNoCC,
  lib,
  fetchurl,
  nushell,
  writeShellScript,
}:
let
  coords = import ./coords.nix;
  system = stdenvNoCC.hostPlatform.system;
  tarball = coords.platforms.${system};
in
stdenvNoCC.mkDerivation {
  pname = "kmono";
  inherit (coords) version;

  src = fetchurl tarball;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 kmono $out/bin
    runHook postInstall
  '';

  passthru.updateScript = writeShellScript "update-kmono" ''
    set -euo pipefail
    cd pkgs/kmono
    ${lib.getExe nushell} ./update.nu
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
