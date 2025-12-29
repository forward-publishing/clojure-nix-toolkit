# Clojure Nix Toolkit

A Nix flake providing tools and utilities for building and deploying Clojure applications with Nix.

## Features

### buildClojureDepsPackage

The flake provides `buildClojureDepsPackage`, a Nix function for building Clojure projects with proper dependency management. It's inspired by `maven.buildMavenPackage` and handles:

- Fetching and caching Clojure dependencies (Maven `.m2` and `.gitlibs`)
- Running any clojure build command with the dependencies prefetched

The package builder works in layered manner (similar with multi-layer Dockerfiles) 

### Packages

- **kmono**: Clojure monorepo management tool (v4.10.3)
- **rama10, rama11, rama12**: Rama distributed computing platform packages (can be customized with backup providers via `.override`)

### NixOS Modules

- **services.rama**: NixOS service module for declaratively running Rama conductor and supervisor services under nixos

## Flake Outputs

This flake provides the following outputs:

- **`packages.<system>`**: Pre-built packages (kmono, rama10, rama11, rama12)
- **`overlays.default`**: Overlay that adds packages and build functions to nixpkgs
- **`lib.buildClojureDepsPackage`**: Function to build Clojure projects with dependency caching
- **`lib.fetchCljDeps`**: Function to fetch Clojure dependencies as a fixed-output derivation
- **`nixosModules.rama`**: NixOS service module for Rama

## Usage

### Using Packages

This flake provides packages that can be used either via the overlay or directly from the `packages.<system>` output.

#### Via Overlay

Apply the overlay to get access to packages through `pkgs`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    clojure-nix-toolkit.url = "github:forward-distribution/clojure-nix-toolkit";
  };

  outputs = { self, nixpkgs, clojure-nix-toolkit }: 
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = [ clojure-nix-toolkit.overlays.default ];
      };
    in {
      # Now you can use packages from the overlay
      environment.systemPackages = [
        pkgs.kmono
        pkgs.rama12
        # Build functions are also available:
        # pkgs.buildClojureDepsPackage
        # pkgs.fetchCljDeps
      ];
    };
}
```

#### Via packages.<system> Output

Alternatively, reference packages directly from the flake output:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    clojure-nix-toolkit.url = "github:forward-distribution/clojure-nix-toolkit";
  };
  
  outputs = { self, nixpkgs, flake-utils, clojure-nix-toolkit }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          # ... your derivation ...
          buildInputs = [
            clojure-nix-toolkit.packages.${system}.kmono
            clojure-nix-toolkit.packages.${system}.rama12
          ];
        };
      }
    );
}
```

### Building Clojure Packages

The `buildClojureDepsPackage` function is available both through the overlay (`pkgs.buildClojureDepsPackage`) and as a lib function (`clojure-nix-toolkit.lib.buildClojureDepsPackage`) and allows you to build Clojure projects with proper dependency caching.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    clojure-nix-toolkit.url = "github:forward-distribution/clojure-nix-toolkit";
  };
  
  outputs = { self, nixpkgs, flake-utils, clojure-nix-toolkit }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ clojure-nix-toolkit.overlays.default ];
        };
      in
      {
        packages.default = pkgs.buildClojureDepsPackage {
          pname = "my-clojure-app";
          version = "1.0.0";
          src = ./.;
          
          # Use empty string for initial build to get hash
          cljDepsHash = "";

          # Optional: customize dependency fetching
          # Can be a string (shell command), an attribute set, or a list of attribute sets
          # Default is { srcRoot = "."; } which runs "clojure -P" in the root directory
          prep = {
            srcRoot = ".";
            aliases = [":dev" ":test" ":build"];
          };
          
          # Alternatively, use string form for custom commands:
          # prep = ''
          #   clojure -P -A:build 
          #   kmono exec -F 'io.forward-publishing.janus/chm-backend' clojure -P -A:dev:test
          # '';
          # Or multiple preparations:
          # prep = [
          #   { srcRoot = "project-a"; aliases = [":dev"]; }
          #   { srcRoot = "project-b"; aliases = [":test"]; }
          # ];

          buildPhase = ''
            clojure -T:build uber
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp target/my-app.jar $out/bin/
          '';
        };
      }
    );
}
```

The build process works in two stages:

1. **Dependency Fetching**: Creates a fixed-output derivation containing all Maven and git dependencies using the `prep` parameter
2. **Project Build**: Provides `clojure`/`clj` commands that use the cached dependencies

To get the correct `cljDepsHash`:
1. Set it to an empty string initially
2. Run the build and it will fail with the expected hash
3. Update `cljDepsHash` with the provided hash

The `prep` parameter allows you to customize how dependencies are fetched:
- **String**: Shell commands to execute (e.g., `"clojure -P -A:dev:test"`)
- **Attribute set**: `{ srcRoot = "."; aliases = [":dev" ":test"]; }` - changes to srcRoot and runs `clojure -P` with the specified aliases
- **List of attribute sets**: Runs multiple preparation steps sequentially

The preparation runs with `clojure` and `clj` commands configured to cache dependencies in the output derivation.

### Fetching Dependencies Separately

You can also use `fetchCljDeps` (available as `pkgs.fetchCljDeps` or `clojure-nix-toolkit.lib.fetchCljDeps`) to fetch dependencies separately and reuse them across multiple builds:

```nix
let
  myDeps = pkgs.fetchCljDeps {
    name = "my-app-deps";
    src = ./.;
    prep = { srcRoot = "."; aliases = [":dev" ":test"]; };
    hash = "sha256-...";
  };
in
pkgs.buildClojureDepsPackage {
  pname = "my-clojure-app";
  version = "1.0.0";
  src = ./.;
  
  # Use the pre-fetched dependencies
  cljDeps = myDeps;
  
  buildPhase = ''
    clojure -T:build uber
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp target/my-app.jar $out/bin/
  '';
}
```

This is useful when you want to:
- Share the same dependencies across multiple derivations
- Have more control over the dependency fetching process
- Separate dependency management from the build process

### Configuring Rama Services in NixOS

The flake provides a NixOS module for declaratively running Rama conductor and supervisor services.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    clojure-nix-toolkit.url = "github:forward-distribution/clojure-nix-toolkit";
  };

  outputs = { self, nixpkgs, clojure-nix-toolkit }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        clojure-nix-toolkit.nixosModules.rama
        ({ pkgs, ... }: {
          services.rama = {
            conductor.enable = true;
            
            package = pkgs.rama12;  # Available after applying overlay or directly reference clojure-nix-toolkit.packages.${system}.rama12
            dataDir = "/var/lib/rama";
            logDir = "/var/log/rama";
            
            # Settings use dot-separated keys (not nested attributes)
            settings = {
              "conductor.host" = "localhost";
            };
            
            # Optional backup configuration
            backup = {
              s3.targetBucket = "my-backup-bucket";
            };
          };
        })
      ];
    };
  };
}
```

## Supported Systems

- `x86_64-linux` - 64-bit Intel/AMD Linux
- `aarch64-linux` - 64-bit ARM Linux
- `x86_64-darwin` - 64-bit Intel macOS
- `aarch64-darwin` - 64-bit ARM macOS (Apple Silicon)

## Development

Enter the development shell:

```bash
nix develop
```

Format Nix files:

```bash
git ls-files -z '*.nix' | xargs -0 -r nix fmt
```

Check formatting:

```bash
git ls-files -z '*.nix' | xargs -0 -r nix develop --command nixfmt --check
```

## License

Forward Publishing's Clojure/Nix Toolkit
