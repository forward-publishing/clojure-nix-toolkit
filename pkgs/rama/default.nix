{
  stdenvNoCC,
  lib,
  fetchzip,
  jre,
  python3,
}:

let
  mkRama =
    {
      version,
      sha256,
      ramaDir ? null,
    }:
    stdenvNoCC.mkDerivation {
      pname = "rama";
      inherit version;

      src = fetchzip {
        url = "https://redplanetlabs.s3.us-west-2.amazonaws.com/rama/rama-${version}.zip";
        inherit sha256;
      };

      patches = [ ./rama-dir.patch ];

      postPatch = ''
        # Substitute the RAMA_DIR placeholder with the actual path
        substituteInPlace rama \
          --replace-fail "@ramaDir@" "${if ramaDir != null then ramaDir else "$out/share/rama-${version}"}"
      '';

      installPhase = ''
        runHook preInstall

        # Install jars in share directory
        mkdir -p $out/share/rama
        cp rama.jar $out/share/rama/
        mkdir -p $out/share/rama/lib
        cp -r lib/* $out/share/rama/lib/

        # Install configuration files
        mkdir -p $out/etc/rama
        cp *.yaml *.properties $out/etc/rama/ 2>/dev/null || true

        # Install documentation
        mkdir -p $out/share/doc/rama
        cp LICENSE.txt README.md $out/share/doc/rama/

        # Install the rama Python script
        mkdir -p $out/bin
        cp rama $out/bin/rama
        chmod +x $out/bin/rama

        runHook postInstall
      '';

      meta = {
        description = "Rama - End-to-end data processing framework";
        homepage = "https://redplanetlabs.com";
        license = lib.licenses.unfree;
        platforms = lib.platforms.all;
      };
    };
in
{
  rama10 = mkRama {
    version = "1.0.0";
    sha256 = "sha256-K2hKrbbTyl3E/PsbB0LfhTKwLdAqyA9cHmLC1LhGyvw=";
  };

  rama11 = mkRama {
    version = "1.1.0";
    sha256 = "sha256-9hAMrqHJE8bPj1musaQO1q1FhceumI7y4kCYcJb1Hl4=";
  };

  rama12 = mkRama {
    version = "1.2.0";
    sha256 = "sha256-WneEv36QTfeUq2t245Z8RhGQhmbJDXIlv6iKiAJkMoM=";
  };
}
