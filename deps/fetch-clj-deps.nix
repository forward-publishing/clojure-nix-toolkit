# fetchCljDeps - Fetch Clojure dependencies as a fixed-output derivation
#
# This function creates a derivation that downloads Clojure dependencies
# (Maven artifacts and git dependencies) by running a preparation command.
# The resulting derivation can be used as a dependency cache for subsequent
# Clojure builds, with dependencies stored in .m2 and .gitlibs directories.
#
# The function returns a fixed-output derivation (FOD) with a content-addressable
# hash, making it reproducible and cacheable.
#
# This implementation is based on the fetchedCljDeps pattern from build-clj-deps-package.nix
#
# Parameters:
#   src          - Source directory containing deps.edn
#   clojure      - Clojure package to use for dependency resolution
#   makeWrapper  - makeWrapper utility for creating wrapper scripts
#   pname        - Package name for the derivation
#   version      - Version string
#   hash         - Expected output hash (empty string for initial build to discover hash)
#   prepPhase    - Command to run for dependency preparation (default: "clojure -P")
#
# Usage example:
#   fetchCljDeps {
#     inherit src clojure makeWrapper;
#     pname = "my-app";
#     version = "0.1.0";
#     hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
#   }
#
# The output derivation structure:
#   $out/.m2/       - Maven local repository with downloaded JARs
#   $out/.gitlibs/  - Git dependencies cache
#
{
  lib,
  stdenvNoCC,
}:

{
  src,
  clojure,
  makeWrapper,
  pname,
  version,
  hash ? "",
  prepPhase ? "clojure -P",
  ...
}@args:
let
  # Determine hash configuration based on whether hash is provided
  hashAttrs =
    if hash != "" then
      {
        outputHash = hash;
        outputHashAlgo = null; # inferred from hash format
      }
    else
      {
        outputHash = "";
        outputHashAlgo = "sha256";
      };
in
stdenvNoCC.mkDerivation (
  (builtins.removeAttrs args [
    "clojure"
    "makeWrapper"
    "hash"
    "prepPhase"
  ])
  // {
    pname = "clj-deps-${pname}";
    inherit src version;

    nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [
      clojure
      makeWrapper
    ];

    buildPhase = ''
      runHook preBuild

      # Set HOME so Clojure can create .clojure directory
      export HOME=$out

      # Set GITLIBS environment variable for git dependencies
      export GITLIBS=$out/.gitlibs

      # Use -Sdeps to set :mvn/local-repo without modifying deps.edn
      # We need to properly quote and escape for the shell
      clojure -Sdeps "{:mvn/local-repo \"$out/.m2\"}" -P
      # ${prepPhase}

      runHook postBuild
    '';

    # keep only *.{pom,jar,sha1,nbm} and delete all ephemeral files with lastModified timestamps inside
    installPhase = ''
      runHook preInstall

      find $out -type f \( \
        -name "*.lastUpdated" \
        -o -name "resolver-status.properties" \
        -o -name "_remote.repositories" \
      \) -delete

      runHook postInstall
    '';

    # don't do any fixup
    dontFixup = true;
    outputHashMode = "recursive";
  }
  // hashAttrs
)
