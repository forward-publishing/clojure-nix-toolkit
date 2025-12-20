{
  pkgs ? import <nixpkgs> { },
}:

let
  fetchCljDeps = pkgs.callPackage ../deps/fetch-clj-deps.nix { };

  # Test project sources
  testProjectSrc = ./test-clj-project;

  # Create a more complex test project with multiple dependencies
  complexProjectSrc = pkgs.writeTextDir "deps.edn" ''
    {:deps {org.clojure/clojure {:mvn/version "1.11.1"}
            org.clojure/data.json {:mvn/version "2.4.0"}
            cheshire/cheshire {:mvn/version "5.11.0"}}
     :aliases {:test {:extra-deps {lambdaisland/kaocha {:mvn/version "1.87.1366"}}}}}
  '';

  # Test project with git dependencies
  gitDepsProjectSrc = pkgs.writeTextDir "deps.edn" ''
    {:deps {org.clojure/clojure {:mvn/version "1.11.1"}
            io.github.clojure/tools.build {:git/tag "v0.9.6" :git/sha "8e78bcc"}}}
  '';

in
{
  # Test 1: Basic dependency fetching with simple project (default prep)
  test-basic-fetch = fetchCljDeps {
    name = "test-basic-deps";
    src = testProjectSrc;
    clojure = pkgs.clojure;
    hash = "sha256-h3t6UYFk8OaQ/58xraiY9uE3ATEPfQByeOmUvwvbrO0=";
  };

  # Test 2: Fetching with specific hash (prevents network access in build)
  # Note: You need to run test-basic-fetch first to get the actual hash
  # test-basic-fetch-with-hash = fetchCljDeps {
  #   name = "test-basic-clj-deps-hashed";
  #   src = testProjectSrc;
  #   clojure = pkgs.clojure;
  #   hash = "sha256-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX=";
  # };

  # Test 3: Complex project with multiple dependencies
  test-complex-deps = fetchCljDeps {
    name = "test-complex-clj-deps";
    src = complexProjectSrc;
    clojure = pkgs.clojure;
    hash = "";
  };

  # Test 4: Fetching with aliases using prep attribute set
  test-with-aliases = fetchCljDeps {
    name = "test-clj-deps-with-aliases";
    src = complexProjectSrc;
    clojure = pkgs.clojure;
    prep = {
      srcRoot = ".";
      aliases = [ ":test" ];
    };
    hash = "";
  };

  # Test 5: Git dependencies
  test-git-deps = fetchCljDeps {
    name = "test-git-clj-deps";
    src = gitDepsProjectSrc;
    clojure = pkgs.clojure;
    hash = "";
  };

  # Test 6: Custom prep command (string format)
  test-custom-prep = fetchCljDeps {
    name = "test-custom-prep";
    src = testProjectSrc;
    clojure = pkgs.clojure;
    prep = "clojure -P -M:dev 2>&1 || true"; # Allow failure for non-existent alias
    hash = "";
  };

  # Test 7: Subdirectory source root using prep attribute set
  test-srcroot =
    let
      nestedSrc = pkgs.runCommand "nested-project" { } ''
        mkdir -p $out/subdir
        cat > $out/subdir/deps.edn <<EOF
        {:deps {org.clojure/clojure {:mvn/version "1.11.1"}}}
        EOF
      '';
    in
    fetchCljDeps {
      name = "test-srcroot-clj-deps";
      src = nestedSrc;
      clojure = pkgs.clojure;
      prep = {
        srcRoot = "subdir";
        aliases = [ ];
      };
      hash = "";
    };

  # Test 8: Multiple preparations using prep list
  test-multi-prep =
    let
      multiProjectSrc = pkgs.runCommand "multi-project" { } ''
        mkdir -p $out/project-a
        mkdir -p $out/project-b
        cat > $out/project-a/deps.edn <<EOF
        {:deps {org.clojure/clojure {:mvn/version "1.11.1"}}
         :aliases {:dev {:extra-deps {org.clojure/data.json {:mvn/version "2.4.0"}}}}}
        EOF
        cat > $out/project-b/deps.edn <<EOF
        {:deps {org.clojure/clojure {:mvn/version "1.11.1"}}
         :aliases {:test {:extra-deps {cheshire/cheshire {:mvn/version "5.11.0"}}}}}
        EOF
      '';
    in
    fetchCljDeps {
      name = "test-multi-prep";
      src = multiProjectSrc;
      clojure = pkgs.clojure;
      prep = [
        {
          srcRoot = "project-a";
          aliases = [ ":dev" ];
        }
        {
          srcRoot = "project-b";
          aliases = [ ":test" ];
        }
      ];
      hash = "";
    };

  # Test 9: Prep with multiple aliases
  test-multiple-aliases = fetchCljDeps {
    name = "test-multiple-aliases";
    src = complexProjectSrc;
    clojure = pkgs.clojure;
    prep = {
      aliases = [
        ":test"
        ":dev"
      ];
    };
    hash = "";
  };

  # Test 10: Verification test - check output structure
  test-output-structure =
    pkgs.runCommand "test-fetch-clj-deps-structure"
      {
        nativeBuildInputs = [ pkgs.findutils ];
      }
      ''
        # First fetch the dependencies
        export HOME=$(mktemp -d)

        # Create a test deps.edn
        mkdir -p $HOME/test-project
        cat > $HOME/test-project/deps.edn <<EOF
        {:deps {org.clojure/clojure {:mvn/version "1.11.1"}}}
        EOF

        cd $HOME/test-project
        ${pkgs.clojure}/bin/clojure -P

        # Verify expected directories exist
        if [ ! -d "$HOME/.m2" ]; then
          echo "ERROR: .m2 directory not created"
          exit 1
        fi

        # Check for Clojure JAR
        jar_count=$(find $HOME/.m2 -name "clojure-*.jar" | wc -l)
        if [ "$jar_count" -eq 0 ]; then
          echo "ERROR: No Clojure JAR found in .m2"
          exit 1
        fi

        # Verify ephemeral files can be cleaned
        find $HOME -type f \( \
          -name "*.lastUpdated" \
          -o -name "resolver-status.properties" \
          -o -name "_remote.repositories" \
        \) > $out

        echo "Test passed: Output structure is correct"
        echo "Found $(cat $out | wc -l) ephemeral files to clean"
      '';

  # Test 11: Integration test - use fetched deps
  test-integration =
    let
      deps = fetchCljDeps {
        name = "integration-test-deps";
        src = testProjectSrc;
        clojure = pkgs.clojure;
        hash = "";
      };
    in
    pkgs.runCommand "test-integration"
      {
        nativeBuildInputs = [ pkgs.clojure ];
      }
      ''
        # Use the fetched dependencies
        export HOME=${deps}

        # Create a simple test file
        mkdir -p test-project
        cat > test-project/deps.edn <<EOF
        {:deps {org.clojure/clojure {:mvn/version "1.11.1"}}}
        EOF

        cd test-project

        # This should work without network access since deps are cached
        ${pkgs.clojure}/bin/clojure -e "(println (+ 1 2 3))" > $out

        # Verify output
        if grep -q "6" $out; then
          echo "Integration test passed"
        else
          echo "Integration test failed"
          exit 1
        fi
      '';
}
