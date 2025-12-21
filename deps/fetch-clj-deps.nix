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
#   hash         - Expected output hash (empty string for initial build to discover hash)
#   prep         - Preparation specification, can be:
#                  * A string: interpreted as a shell command to execute
#                  * An attribute set with { srcRoot, aliases }: cd to srcRoot and run clojure -P with aliases
#                  * A list of attribute sets: run preparation for each set sequentially
#
# Usage examples:
#   # Simple command
#   fetchCljDeps {
#     inherit src clojure;
#     name = "my-app-deps";
#     prep = "clojure -P";
#     hash = "sha256-...";
#   }
#
#   # Single preparation with srcRoot and aliases
#   fetchCljDeps {
#     inherit src clojure;
#     name = "my-app-deps";
#     prep = {
#       srcRoot = "subproject";
#       aliases = [ ":dev" ":test" ];
#     };
#     hash = "sha256-...";
#   }
#
#   # Multiple preparations
#   fetchCljDeps {
#     inherit src clojure;
#     name = "my-app-deps";
#     prep = [
#       { srcRoot = "project-a"; aliases = [ ":dev" ]; }
#       { srcRoot = "project-b"; aliases = [ ":test" ]; }
#     ];
#     hash = "sha256-...";
#   }
#
# The output derivation structure:
#   $out/.m2/       - Maven local repository with downloaded JARs
#   $out/.gitlibs/  - Git dependencies cache
#
{
  lib,
  stdenvNoCC,
  clojure,
}@pargs:

{
  src,
  clojure ? pargs.clojure,
  name,
  hash ? "",
  prep ? {
    srcRoot = ".";
  },
  ...
}@args:
let
  # Determine hash configuration based on whether hash is provided
  hashAttrs =
    if hash != "" then
      {
        outputHash = hash;
        outputHashAlgo = null; # inferred from hash format
        outputHashMode = "recursive";
      }
    else
      {
        outputHash = "";
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
      };

  # Convert a single prep spec to a shell command
  prepSpecToCommand =
    spec:
    let
      srcRoot = spec.srcRoot or ".";
      aliases = spec.aliases or [ ];
      aliasesStr = if (aliases == [ ]) then "" else " -A${lib.concatStrings aliases}";
    in
    ''
      (cd ${srcRoot} && clojure -P${aliasesStr})
    '';

  # Generate the preparation command based on prep type
  prepCommand =
    if lib.isString prep then
      # Case 1: prep is a string - use it directly as a command
      prep
    else if lib.isList prep then
      # Case 3: prep is a list - run each spec sequentially
      lib.concatMapStrings prepSpecToCommand prep
    else
      # Case 2: prep is an attribute set - convert to command
      prepSpecToCommand prep;
in
stdenvNoCC.mkDerivation (
  (builtins.removeAttrs args [
    "clojure"
    "hash"
    "prep"
  ])
  // {
    inherit src name;

    nativeBuildInputs = (args.nativeBuildInputs or [ ]) ++ [
      clojure
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      # Force clojure cli to use $out/.m2/repository and $out/.gitlibs
      # as local repositories
      export HOME=$out
      export GITLIBS=$out/.gitlibs
      export CLJ_CONFIG=$out/.clojure
      mkdir -p $CLJ_CONFIG
      echo "{:mvn/local-repo \"$out/.m2/repository\"}" > $CLJ_CONFIG/deps.edn

      ${prepCommand}

      # nix complains if fixed-output derivations have links to other derivations
      rm $CLJ_CONFIG/deps.edn

      # cleanup after maven
      find $out -type f \( \
        -name "*.lastUpdated" \
        -o -name "resolver-status.properties" \
        -o -name "_remote.repositories" \
      \) -delete

      runHook postBuild
    '';

    dontInstall = true;
    dontFixup = true;
  }
  // hashAttrs
)
