{
  lib,
  stdenvNoCC,
  jre-generate-cacerts,
  makeWrapper,
  clojure,
}@pargs:

{
  # the sources of the project
  src,
  clojure ? pargs.clojure,
  cljDepsHash ? "",
  prepPhase ? "clojure -P",
  pname,
  version,
  ...
}@args:
let
  fetchedCljDeps = stdenvNoCC.mkDerivation {
    pname = "clj-deps-${pname}";
    inherit
      src
      version
      ;

    nativeBuildInputs = [
      clojure
      makeWrapper
    ]
    ++ args.nativeBuildInputs or [ ];

    buildPhase = ''
      runHook preBuild

      CLJ_EXTRA_ARGS=""

      # handle cacert by populating a trust store on the fly
      if [[ -n "''${NIX_SSL_CERT_FILE-}" ]] && [[ "''${NIX_SSL_CERT_FILE-}" != "/no-cert-file.crt" ]]; then
        echo "using ''${NIX_SSL_CERT_FILE-} as trust store"
        ${jre-generate-cacerts} ${lib.getBin clojure.jdk}/bin/keytool "$NIX_SSL_CERT_FILE"
        CLJ_EXTRA_ARGS="$CLJ_EXTRA_ARGS -J-Djavax.net.ssl.trustStore=cacerts -J-Djavax.net.ssl.trustStorePassword=changeit"
      fi

      # Create a temporary wrapper script for clojure with environment setup
      mkdir -p $TMPDIR/bin
      makeWrapper ${lib.getBin clojure}/bin/clojure $TMPDIR/bin/clojure \
        --add-flags "-J-Dmaven.repo.local=$out/.m2 -J-Dclojure.gitlibs.dir=$out/.gitlibs $CLJ_EXTRA_ARGS"

      makeWrapper ${lib.getBin clojure}/bin/clj $TMPDIR/bin/clj \
        --add-flags "-J-Dmaven.repo.local=$out/.m2 -J-Dclojure.gitlibs.dir=$out/.gitlibs $CLJ_EXTRA_ARGS"

      export PATH=$TMPDIR/bin:$PATH

      ${prepPhase}
    '';

    # keep only *.{pom,jar,sha1,nbm} and delete all ephemeral files with lastModified timestamps inside
    installPhase = ''
      runHook preInstall

      find $out -type f \( \
        -name \*.lastUpdated \
        -o -name resolver-status.properties \
        -o -name _remote.repositories \) \
        -delete

      runHook postInstall
    '';

    # don't do any fixup
    dontFixup = true;
    outputHashAlgo = if cljDepsHash != "" then null else "sha256";
    outputHashMode = "recursive";
    outputHash = cljDepsHash;
  };

  clojureWithDeps = stdenvNoCC.mkDerivation {
    name = "clojure-with-deps-${pname}";
    inherit version;

    dontUnpack = true;

    nativeBuildInputs = [
      clojure
      makeWrapper
    ];

    buildPhase = ''
      runHook preBuild

      mkdir -p $out/bin
      makeWrapper ${lib.getBin clojure}/bin/clojure $out/bin/clojure \
        --add-flags "-J-Dmaven.repo.local=${fetchedCljDeps}/.m2 -J-Dclojure.gitlibs.dir=${fetchedCljDeps}/.gitlibs"

      makeWrapper ${lib.getBin clojure}/bin/clj $out/bin/clj \
        --add-flags "-J-Dmaven.repo.local=${fetchedCljDeps}/.m2 -J-Dclojure.gitlibs.dir=${fetchedCljDeps}/.gitlibs"

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      # Output already in $out/bin
      runHook postInstall
    '';
  };
in
stdenvNoCC.mkDerivation args
// {
  inherit fetchedCljDeps;

  nativeBuildInputs = args.nativeBuildInputs or [ ] ++ [
    clojureWithDeps
  ];

  # INSTALL
  # - copy over all dependencies into $out/share/pname/[m2|gitlibs]
  # - copy over the jarfile or target/classes into $out/sh
  # - copy over the

}
