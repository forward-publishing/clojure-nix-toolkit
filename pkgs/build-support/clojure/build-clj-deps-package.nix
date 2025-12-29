# buildClojureDepsPackage - Build Clojure projects as Nix packages
#
# This function creates a Nix derivation for Clojure projects by setting up
# the build environment with preftched clojure dependencies. The dependencies are
# fetched and set up in a sub-derivatton

# The dependency fetching is content-addressed (via cljDepsHash), enabling Nix to cache
# dependencies across builds and share them between rebuilds.
#
# Parameters:
#   pname         - Package name
#   version       - Package version
#   src           - Source directory of your Clojure project
#   cljDepsHash   - SHA256 hash of fetched dependencies (empty string "" for initial build to discover hash)
#   prep          - (optional) Preparation specification for dependency fetching, can be:
#                   * A string: interpreted as a shell command to execute
#                   * An attribute set with { srcRoot, aliases }: cd to srcRoot and run clojure -P with aliases
#                   * A list of attribute sets: run preparation for each set sequentially
#                   Default: { srcRoot = "."; } (runs "clojure -P" in root directory)
#   clojure       - (optional) Clojure package to use. Default: pkgs.clojure
#   cljDeps       - (optional) Pre-fetched dependencies derivation. You can use this instead of
#                    prep/cljDepsHash and produce a compatible derivation. The derivation
#                    needs to contain a .m2/repostory and .gitlibs directories
#   buildPhase    - Your build commands (e.g., compile, create uberjar)
#   installPhase  - Your install commands (e.g., copy artifacts to $out)
#   ...           - All other standard mkDerivation arguments
#
# Usage example:
#   buildClojureDepsPackage {
#     pname = "my-clojure-app";
#     version = "1.0.0";
#     src = ./.;
#     cljDepsHash = "sha256-h3t6UYFk8OaQ/58xraiY9uE3ATEPfQByeOmUvwvbrO0=";
#
#     buildPhase = ''
#       runHook preBuild
#       clojure -M -e '(println "Building...")'
#       runHook postBuild
#     '';
#
#     installPhase = ''
#       runHook preInstall
#       mkdir -p $out/bin
#       cp -r src $out/share/my-app/
#       # Create launcher script
#       runHook postInstall
#     '';
#   }
#
# To get the initial cljDepsHash:
# 1. Set cljDepsHash = "";
# 2. Run nix-build (it will fail with hash mismatch)
# 3. Copy the "got: sha256-..." hash from the error message
# 4. Update cljDepsHash with the correct hash
#
{
  callPackage,
  lib,
  stdenvNoCC,
  clojure,
}@pargs:
let
  fetchCljDeps = callPackage ./fetch-clj-deps.nix { };
in
{
  pname,
  version,

  src,
  prep ? {
    srcRoot = ".";
  },

  cljDepsHash,
  clojure ? pargs.clojure,
  cljDeps ? (
    fetchCljDeps {
      name = "${pname}-clj-deps";
      inherit src prep clojure;
      hash = cljDepsHash;
    }
  ),

  ...
}@args:
stdenvNoCC.mkDerivation (
  args
  // {
    inherit cljDeps;

    nativeBuildInputs = args.nativeBuildInputs or [ ] ++ [
      cljDeps
      clojure
    ];

    preBuild = ''
      export HOME="$TMPDIR"
      export CLJ_CONFIG="$HOME/.clojure"
      mkdir -p $CLJ_CONFIG

      # All we require from cljDeps is to have a .m2/repository and .gitlibs
      # containing the prefetched dependencies
      echo "{:mvn/local-repo \"${cljDeps}/.m2/repository\"}" > $CLJ_CONFIG/deps.edn
      export GITLIBS="${cljDeps}/.gitlibs"

      ${args.preBuild or ""}
    '';

  }
)
