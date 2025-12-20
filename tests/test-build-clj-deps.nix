{ pkgs }:

# Test package for buildClojureDepsPackage
pkgs.clojure.buildClojureDepsPackage {
  pname = "test-clj-app";
  version = "0.1.0";

  src = ./test-clj-project;

  # Leave empty for first build to get hash
  cljDepsHash = "";

  # Use default prepPhase which runs "clojure -P" to prepare dependencies

  buildPhase = ''
    runHook preBuild

    # Verify clojure command is available and configured
    echo "Testing clojure command..."
    echo "PATH: $PATH"
    clojure -e '(println "Clojure version:" (clojure-version))'

    # Compile the namespace
    clojure -M -e "(compile 'hello)"

    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall

        mkdir -p $out/bin
        mkdir -p $out/share/java

        # Create a simple launcher script
        cat > $out/bin/test-clj-app <<EOF
    #!/bin/sh
    exec ${pkgs.clojure}/bin/clojure -M -m hello "\$@"
    EOF
        chmod +x $out/bin/test-clj-app

        runHook postInstall
  '';

  meta = {
    description = "Test package for buildClojureDepsPackage";
    maintainers = [ ];
  };
}
