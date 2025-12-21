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
        {
          inherit (pkgs)
            kmono
            rama10
            rama11
            rama12
            ramaBackupProviders
            buildClojureDepsPackage
            fetchCljDeps
            ;
        }
      );

      overlays.default =
        final: prev:
        let
          # By default we're on Java 25
          jdk = final.zulu25;

          ramaPackages = final.callPackage ./pkgs/rama { };
          fetchCljDeps = final.callPackage ./deps/fetch-clj-deps.nix { };
          buildClojureDepsPackage = final.callPackage ./deps/build-clj-deps-package.nix { };
        in
        {

          # Set default Javs
          jdk_headless = jdk;
          jre = jdk;
          jre_headless = jdk;

          # Clojure monorepo management tool
          kmono = final.callPackage ./pkgs/kmono { };
          # rama pacakages
          inherit (ramaPackages)
            rama10
            rama11
            rama12
            ramaBackupProviders
            ;

          inherit jdk fetchCljDeps buildClojureDepsPackage;
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

      # Checks output for CI/testing
      #
      # Run all checks with: nix flake check
      # Run specific check with: nix build .#checks.<system>.<check-name>
      checks = forEachSupportedSystem (
        { pkgs, ... }:
        let
          inherit (pkgs) buildClojureDepsPackage fetchCljDeps;

          # Import test suites with callPackage to provide dependencies
          buildTests = pkgs.callPackage ./tests/test-build-clj-deps.nix {
            inherit buildClojureDepsPackage;
          };
          fetchTests = pkgs.callPackage ./tests/test-fetch-clj-deps.nix {
            inherit fetchCljDeps;
          };

          # Filter out non-derivation attributes like 'override' and 'overrideDerivation'
          filterDerivations = attrs: pkgs.lib.filterAttrs (name: value: pkgs.lib.isDerivation value) attrs;
        in
        # Merge both test suites into checks, filtering out non-derivations
        (filterDerivations buildTests) // (filterDerivations fetchTests)
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
