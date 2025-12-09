{
  description = "Forward Publishing's Clojure/Nix Toolkit";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
  };

  # Flake outputs
  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      # The systems supported for this flake's outputs
      supportedSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper for providing system-specific attributes
      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            # Provides a system-specific, configured Nixpkgs
            pkgs = import inputs.nixpkgs {
              inherit system;
              # Enable using unfree packages
              config.allowUnfree = true;
              overlays = [ self.overlays.default ];
            };
          }
        );
    in
    {
      # goals:
      # - means to build a clojure app (compiled or no) that can be
      # run with the clojure command
      # - means to build a nixos service from such app
      # - means to package
      packages = forEachSupportedSystem (
        { pkgs, ... }:
        let
          ramaPackages = pkgs.callPackage ./pkgs/rama { };
        in
        {
          kmono = pkgs.callPackage ./pkgs/kmono { };
          inherit (ramaPackages)
            rama10
            rama11
            rama12
            ramaBackupProviders
            ;
        }
      );

      # Nixpkgs overlay
      #
      # Extends the clojure package with a buildClojureDepsPackage function
      # accessible via pkgs.clojure.buildClojureDepsPackage
      #
      # Usage in other flakes:
      #   inputs.clojure-nix-toolkit.overlays.default
      #
      # Usage in nixpkgs import:
      #   pkgs = import nixpkgs {
      #     overlays = [ inputs.clojure-nix-toolkit.overlays.default ];
      #   };
      overlays.default =
        final: prev:
        let
          ramaPackages = final.callPackage ./pkgs/rama { };
        in
        {
          clojure = prev.clojure.overrideAttrs (oldAttrs: {
            passthru = (oldAttrs.passthru or { }) // {
              # Build function for Clojure projects with dependency management.
              # Inspired by maven.buildMavenPackage
              #
              # This function creates a Nix derivation for Clojure projects by:
              # 1. Fetching and caching all Clojure dependencies (Maven .m2 and gitlibs) in a separate fixed-output derivation
              # 2. Creating wrapped clojure/clj commands that use the cached dependencies
              # 3. Providing the wrapped commands to your build phase via nativeBuildInputs
              #
              # The dependency fetching is content-addressed (via cljDepsHash), enabling Nix to cache
              # dependencies across builds and share them between projects.
              #
              # Required arguments:
              #   src         - Source directory of your Clojure project
              #   cljDepsHash   - SHA256 hash of fetched dependencies (empty string for initial build)
              #
              # Along with normal arguments you would pass to mkDerivation (e.g. buildPhase)
              #
              # Example usage:
              #   pkgs.clojure.buildClojureDepsPackage {
              #     pname = "my-clojure-app";
              #     version = "1.0.0";
              #     src = ./.;
              #     cljDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
              #
              #     buildPhase = ''
              #       clojure -T:build uber
              #     '';
              #
              #     installPhase = ''
              #       mkdir -p $out/bin
              #       cp target/my-app.jar $out/bin/
              #     '';
              #   }
              buildClojureDepsPackage = final.callPackage ./deps/build-clj-deps-package.nix { };
            };
          });

          # Clojure monorepo management tool
          kmono = final.callPackage ./pkgs/kmono { };
          # rama pacakages
          inherit (ramaPackages)
            rama10
            rama11
            rama12
            ramaBackupProviders
            ;

        };

      # Development environments output by this flake

      # To activate the default environment:
      # nix develop
      # Or if you use direnv:
      # direnv allow
      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          # Run `nix develop` to activate this environment or `direnv allow` if you have direnv installed
          default = pkgs.mkShellNoCC {
            # The Nix packages provided in the environment
            packages = with pkgs; [
              # Add the flake's formatter to your project's environment
              self.formatter.${system}

              # Other packages
              ponysay
            ];

            # Set any environment variables for your development environment
            env = { };

            # Add any shell logic you want executed when the environment is activated
            shellHook = "";
          };
        }
      );

      # Nix formatter

      # This applies the formatter that follows RFC 166, which defines a standard format:
      # https://github.com/NixOS/rfcs/pull/166

      # To format all Nix files:
      # git ls-files -z '*.nix' | xargs -0 -r nix fmt
      # To check formatting:
      # git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check
      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt-rfc-style);
    };
}
