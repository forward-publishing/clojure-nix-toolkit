{ buildClojureDepsPackage, pkgs }:

{
  # Test that basic build produces a derivation
  testBasicBuildIsDerivation = {
    expr = pkgs.lib.isDerivation (buildClojureDepsPackage {
      pname = "test-clj-app";
      version = "0.1.0";
      src = ./test-clj-project;
      cljDepsHash = "sha256-h3t6UYFk8OaQ/58xraiY9uE3ATEPfQByeOmUvwvbrO0=";

      buildPhase = ''
        runHook preBuild
        echo "Testing clojure command..."
        clojure -M -e '(println "Clojure version:" (clojure-version))'
        echo "Testing namespace loading..."
        clojure -M -m hello
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        mkdir -p $out/share/clj-app
        cp -r src $out/share/clj-app/
        cp deps.edn $out/share/clj-app/
        cat > $out/bin/test-clj-app <<EOF
        #!/bin/sh
        cd $out/share/clj-app
        exec ${pkgs.clojure}/bin/clojure -M -m hello "\$@"
        EOF
        chmod +x $out/bin/test-clj-app
        runHook postInstall
      '';

      meta = {
        description = "Test package for buildClojureDepsPackage";
        maintainers = [ ];
      };
    });
    expected = true;
  };

  # Test that package has correct name
  testBuildPackageName = {
    expr =
      (buildClojureDepsPackage {
        pname = "test-clj-app";
        version = "0.1.0";
        src = ./test-clj-project;
        cljDepsHash = "sha256-h3t6UYFk8OaQ/58xraiY9uE3ATEPfQByeOmUvwvbrO0=";
      }).pname;
    expected = "test-clj-app";
  };

  # Test that package has correct version
  testBuildPackageVersion = {
    expr =
      (buildClojureDepsPackage {
        pname = "test-clj-app";
        version = "0.1.0";
        src = ./test-clj-project;
        cljDepsHash = "sha256-h3t6UYFk8OaQ/58xraiY9uE3ATEPfQByeOmUvwvbrO0=";
      }).version;
    expected = "0.1.0";
  };
}
