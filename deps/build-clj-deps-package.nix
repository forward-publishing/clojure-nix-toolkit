{
  callPackage,
  lib,
  stdenvNoCC,
  jre-generate-cacerts,
  makeWrapper,
  clojure,
}@pargs:
let
  fetchCljDeps = callPackage ./fetch-clj-deps.nix { };
in
{
  pname,
  version,

  src,
  srcRoot ? ".",
  aliases ? [ ],
  cljDepsHash,
  cljDeps ? (
    fetchCljDeps {
      name = "${pname}-clj-deps";
      inherit src srcRoot aliases;
      hash = cljDepsHash;
    }
  ),
  clojure ? clojure ? pargs.clojure,
  prepPhase ? "clojure -P",
  ...
}@args:
let
in
stdenvNoCC.mkDerivation (
  args
  // {

    nativeBuildInputs = args.nativeBuildInputs or [ ] ++ [
      cljDeps
    ];

  }
)
