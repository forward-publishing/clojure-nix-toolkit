{
  stdenvNoCC,
  lib,
  fetchzip,
  jre,
  python3,
  replaceVars,
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
        stripRoot = false;
        inherit sha256;
      };

      buildInputs = [ python3 ];

      patches = [
        (replaceVars ./rama-dir.patch {
          ramaDir = if ramaDir != null then ramaDir else "${placeholder "out"}/share/rama";
        })
      ];

      installPhase = ''
        runHook preInstall

        # Install jars in share directory
        mkdir -p $out/share/rama
        cp -R ./*  $out/share/rama/

        # Install the rama Python script
        mkdir -p $out/bin
        cp rama $out/bin/rama
        rm $out/share/rama/rama
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
    sha256 = "sha256-W85f97QZ33ykADesGV1vN3wHZOD2kuYMQ+d2zReZKJI=";
  };
}
