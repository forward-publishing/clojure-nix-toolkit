{
  buildClojureDepsPackage,
  clojure,
  runCommand,
}:

{
  # Test 1: Basic build with empty hash (to get the hash)
  test-basic-build = buildClojureDepsPackage {
    pname = "test-clj-app";
    version = "0.1.0";

    src = ./test-clj-project;

    # Hash obtained from first build
    cljDepsHash = "sha256-h3t6UYFk8OaQ/58xraiY9uE3ATEPfQByeOmUvwvbrO0=";

    buildPhase = ''
      runHook preBuild

      # Verify clojure command is available and configured
      echo "Testing clojure command..."
      clojure -M -e '(println "Clojure version:" (clojure-version))'

      # Test that we can load and run the namespace
      echo "Testing namespace loading..."
      clojure -M -m hello

      runHook postBuild
    '';

    installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            mkdir -p $out/share/clj-app

            # Copy the source files
            cp -r src $out/share/clj-app/
            cp deps.edn $out/share/clj-app/

            # Create a simple launcher script
            cat > $out/bin/test-clj-app <<EOF
      #!/bin/sh
      cd $out/share/clj-app
      exec ${clojure}/bin/clojure -M -m hello "\$@"
      EOF
            chmod +x $out/bin/test-clj-app

            runHook postInstall
    '';

    meta = {
      description = "Test package for buildClojureDepsPackage";
      maintainers = [ ];
    };
  };

  # Test 2: Build with correct hash (once we have it)
  # test-build-with-hash = buildClojureDepsPackage {
  #   pname = "test-clj-app";
  #   version = "0.1.0";
  #   src = ./test-clj-project;
  #   cljDepsHash = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
  #   # ... rest of the build configuration
  # };
}
