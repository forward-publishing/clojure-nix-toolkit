# Clojure Nix Toolkit

A Nix flake providing tools and utilities for building and deploying Clojure applications with Nix.

## Features

### buildClojureDepsPackage

The flake provides `buildClojureDepsPackage`, a Nix function for building Clojure projects with proper dependency management. It's inspired by `maven.buildMavenPackage` and handles:

- Fetching and caching Clojure dependencies (Maven `.m2` and `.gitlibs`)
- Running any clojure build command with the dependencies prefetched

The package builder works in layered manner (similar with multi-layer Dockerfiles) 

### Packages

- **kmono**: Clojure monorepo management tool (v4.10.2)
- **rama10, rama11, rama12**: Rama distributed computing platform packages
- **ramaBackupProviders**: Backup provider plugins for Rama

### NixOS Modules

- **services.rama**: NixOS service module for declaratively running Rama conductor and supervisor services under nixos

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

  outputs = { self, nixpkgs, clojure-nix-toolkit }: {
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ clojure-nix-toolkit.overlays.default ];
    };
    
    # Now you can use packages from the overlay
    environment.systemPackages = [
      pkgs.kmono
      pkgs.rama12
      pkgs.ramaBackupProviders
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

The `buildClojureDepsPackage` function is available through the overlay and allows you to build Clojure projects with proper dependency caching.

```nix
pkgs.clojure.buildClojureDepsPackage {
  pname = "my-clojure-app";
  version = "1.0.0";
  src = ./.;
  
  # Use empty string for initial build to get hash
  cljDepsHash = "";

  # Optional: customize the phase used to fetch dependencies
  # Default is "clojure -P" which prepares all dependencies
  prepPhase = ''
    # prep build deps 
    clojure -P -A:build 
    # e.g. prep a sub-project using kmono
    kmono exec -F 'io.forward-publishing.janus/chm-backend' clojure -P -A:dev:test
  ''

  buildPhase = ''
    clojure -T:build uber
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp target/my-app.jar $out/bin/
  '';
}
```

The build process works in two stages:

1. **Dependency Fetching**: Creates a fixed-output derivation containing all Maven and git dependencies using the `prepPhase` 
2. **Project Build**: Provides wrapped `clojure`/`clj` commands that use the cached dependencies

To get the correct `cljDepsHash`:
1. Set it to an empty string initially
2. Run the build and it will fail with the expected hash
3. Update `cljDepsHash` with the provided hash

The `prepPhase` parameter allows you to customize the shell commands used to fetch dependencies. This is useful when you need dependencies from specific aliases like `:dev`, `:test`, or build tool aliases. The `prepPhase` runs in the buildPhase context where both `clojure` and `clj` commands are available with proper dependency caching configured. 



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
        {
          services.rama = {
            conductor.enable = true;
            
            package = pkgs.rama12;
            dataDir = "/var/lib/rama";
            logDir = "/var/log/rama";
            
            settings = {
              "conductor.host" = "localhost";
            };
            
            backup = {
              s3.targetBucket = "my-backup-bucket";
            };
          };
        }
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
