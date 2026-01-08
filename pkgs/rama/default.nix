{
  stdenvNoCC,
  lib,
  fetchzip,
  fetchurl,
  jdk,
  python3,
  replaceVars,
}:

/*
  Rama package builder for different versions.

  Each rama version (rama10, rama11, rama12) can be customized by overriding the following attributes:

  - ramaDir: Path where Rama will store its configuration and data
    Default: ${placeholder "out"}/share/rama (inside the Nix store)
    Override example:
      rama10.override { ramaDir = "/var/lib/rama"; }

  - jdk: The Java Development Kit to use
    Default: jdk (from nixpkgs)
    Override example:
      rama10.override { jdk = jdk17; }

  - backupProviders: List of additional JAR files to include in lib/
    Default: [] (empty list)
    Override example:
      rama10.override {
        backupProviders = [
          ./custom-provider-1.jar
          ./custom-provider-2.jar
        ];
      }

  Multiple attributes can be overridden simultaneously:
    rama12.override {
      ramaDir = "/opt/rama";
      jdk = jdk21;
      backupProviders = [ ./my-backup-provider.jar ];
    }
*/

let
  defaultJdk = jdk;

  availableBackupProviders = {
    s3 = fetchurl {
      url = "https://github.com/redplanetlabs/rama-s3-backup-provider/releases/download/1.1.0/rama-s3-backup-provider-1.1.0.jar";
      sha256 = "sha256-/VX493rE/zPJD2j1avGDL8lPRU7/22WgKvkQIb9Rrwc=";
    };
  };

  mkRama =
    {
      version,
      sha256,
      ramaDir ? null,
      jdk ? defaultJdk,
      backupProviders ? [ ],
    }:
    stdenvNoCC.mkDerivation {
      pname = "rama";
      inherit version;

      src = fetchzip {
        url = "https://redplanetlabs.s3.us-west-2.amazonaws.com/rama/rama-${version}.zip";
        stripRoot = false;
        inherit sha256;
      };

      nativeBuildInputs = [ ] ++ backupProviders;

      buildInputs = [
        python3
        jdk
      ];

      patches = [
        (replaceVars ./rama-dir.patch {
          ramaDir = if ramaDir != null then ramaDir else "${placeholder "out"}/share/rama";
        })
      ];

      installPhase = ''
        runHook preInstall

        # Install the whole package in share/rama
        mkdir -p $out/share/rama
        cp -R ./*  $out/share/rama/

        # move the binary i
        mkdir -p $out/bin
        mv  $out/share/rama/rama $out/bin/rama
        chmod +x $out/bin/rama

        # Install backup providers
        mkdir -p $out/share/rama/lib
        ${lib.concatMapStringsSep "\n" (provider: ''
          cp ${provider} $out/share/rama/lib/
        '') backupProviders}

        runHook postInstall
      '';

      passthru = {
        inherit availableBackupProviders;
      };

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
    sha256 = "sha256-f4X9UqLuBqBbrYBtMiHCmoibct69qSBBhNWIXcjVXRc=";
  };

  rama11 = mkRama {
    version = "1.1.0";
    sha256 = "sha256-Cd1hmb3XQg4FZvU5ZpEEHSYwtABGS8XFw1rET+R1f60=";
  };

  rama12 = mkRama {
    version = "1.2.0";
    sha256 = "sha256-W85f97QZ33ykADesGV1vN3wHZOD2kuYMQ+d2zReZKJI=";
  };

  rama13 = mkRama {
    version = "1.3.0";
    sha256 = "sha256-PEG5Bg3bg55sU9KDyXGoUvJF4U2a41Xv8bYQXaENk8Y=";
  };

  rama14 = mkRama {
    version = "1.4.0";
    sha256 = "sha256-f/whpKTemCAeX7kbl40fKXF6Rz0JLg4ODLEOz23Gt58=";
  };
}
