{
  description = "Forward Publishing's Clojure/Nix Toolkit";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";
    nix-unit.url = "github:nix-community/nix-unit";
    nix-unit.inputs.nixpkgs.follows = "nixpkgs";
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

      withPkgsFromArgs = p: { pkgs, ... }@args: pkgs.callPackage p { } (args.removeAttrs [ "pkgs" ]);

    in
    {
      lib = {
        buildClojureDepsPackage = withPkgsFromArgs ./build-clojure-deps-package.nix;
        fetchCljDeps = withPkgsFromArgs ./pkgs/build-support/clojure/fetch-clj-deps.nix;
      };

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
            rama13
            rama14
            ;
        }
      );

      overlays.default =
        final: prev:
        let
          # By default we're on Java 25
          jdk = final.zulu25;

          ramaPackages = final.callPackage ./pkgs/rama { };
          fetchCljDeps = final.callPackage ./pkgs/build-support/clojure/fetch-clj-deps.nix { };
          buildClojureDepsPackage =
            final.callPackage ./pkgs/build-support/clojure/build-clj-deps-package.nix
              { };
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
            rama13
            rama14
            ;

          inherit jdk fetchCljDeps buildClojureDepsPackage;
        };

      # NixOS modules
      nixosModules.rama = import ./modules/nixos/rama;

      # Development environments output by this flake

      # To activate the default environment:
      # nix develop
      # Or if you use direnv:
      # direnv allow
      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          # Run `nix develop` to activate this environment or `direnv allow` if you have direnv installed
          default = pkgs.mkShell {
            # The Nix packages provided in the environment
            packages = [
              # Add the flake's formatter to your project's environment
              self.formatter.${system}

              # Add nix-unit for running tests
              inputs.nix-unit.packages.${system}.default

              # Tools for running update scripts
              pkgs.nushell
              pkgs.gh

              (pkgs.writeShellApplication {
                name = "update-flake";
                runtimeInputs = with pkgs; [
                  nushell
                  gh
                ];
                text = ''
                  echo "> Updating flake inputs..."
                  nix flake update

                  echo "> Updating kmono..."
                  (cd pkgs/kmono && nu ./update.nu)

                  echo "> All updates complete"
                '';
              })
            ];
          };
        }
      );

      # Unit tests using nix-unit
      #
      # Run tests with: nix-unit --flake '.#tests.<system>.<test-name>'
      tests = forEachSupportedSystem (
        { pkgs, ... }:
        {
          fetchCljDeps = pkgs.callPackage ./tests/unit-test-fetch-clj-deps.nix {
            fetchCljDeps = pkgs.fetchCljDeps;
          };
          buildClojureDepsPackage = pkgs.callPackage ./tests/unit-test-build-clj-deps.nix {
            buildClojureDepsPackage = pkgs.buildClojureDepsPackage;
          };
        }
      );

      # Checks output for CI/testing
      #
      # Run all checks with: nix flake check
      # Run specific check with: nix build .#checks.<system>.<check-name>
      checks = forEachSupportedSystem (
        { pkgs, system }:
        {
          # Run nix-unit tests as checks
          unitTests =
            pkgs.runCommand "unit-tests"
              {
                nativeBuildInputs = [ inputs.nix-unit.packages.${system}.default ];
              }
              ''
                export HOME="$(realpath .)"
                # The nix derivation must be able to find all used inputs in the nix-store because it cannot download it during buildTime.
                nix-unit --eval-store "$HOME" \
                --extra-experimental-features flakes \
                --override-input nixpkgs ${nixpkgs} \
                --flake ${self}#tests
                touch $out
              '';
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
