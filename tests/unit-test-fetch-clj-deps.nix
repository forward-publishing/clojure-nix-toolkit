{ fetchCljDeps, pkgs }:

{
  # Test that basic fetch produces a derivation
  testBasicFetchIsDerivation = {
    expr = pkgs.lib.isDerivation (fetchCljDeps {
      name = "test-basic-deps";
      src = ./test-clj-project;
      clojure = pkgs.clojure;
      hash = "sha256-h3t6UYFk8OaQ/58xraiY9uE3ATEPfQByeOmUvwvbrO0=";
    });
    expected = true;
  };

  # Test that fetch with aliases produces a derivation
  testFetchWithAliasesIsDerivation = {
    expr = pkgs.lib.isDerivation (fetchCljDeps {
      name = "test-with-aliases";
      src = pkgs.writeTextDir "deps.edn" ''
        {:deps {org.clojure/clojure {:mvn/version "1.11.1"}
                org.clojure/data.json {:mvn/version "2.4.0"}}
         :aliases {:test {:extra-deps {lambdaisland/kaocha {:mvn/version "1.87.1366"}}}}}
      '';
      clojure = pkgs.clojure;
      prep = {
        srcRoot = ".";
        aliases = [ ":test" ];
      };
      hash = "";
    });
    expected = true;
  };

  # Test that fetch with git deps produces a derivation
  testGitDepsIsDerivation = {
    expr = pkgs.lib.isDerivation (fetchCljDeps {
      name = "test-git-deps";
      src = pkgs.writeTextDir "deps.edn" ''
        {:deps {org.clojure/clojure {:mvn/version "1.11.1"}
                io.github.clojure/tools.build {:git/tag "v0.9.6" :git/sha "8e78bcc"}}}
      '';
      clojure = pkgs.clojure;
      hash = "";
    });
    expected = true;
  };

  # Test that custom prep string works
  testCustomPrepIsDerivation = {
    expr = pkgs.lib.isDerivation (fetchCljDeps {
      name = "test-custom-prep";
      src = ./test-clj-project;
      clojure = pkgs.clojure;
      prep = "clojure -P -M:dev 2>&1 || true";
      hash = "";
    });
    expected = true;
  };

  # Test that srcRoot attribute works
  testSrcRootIsDerivation = {
    expr =
      let
        nestedSrc = pkgs.runCommand "nested-project" { } ''
          mkdir -p $out/subdir
          cat > $out/subdir/deps.edn <<EOF
          {:deps {org.clojure/clojure {:mvn/version "1.11.1"}}}
          EOF
        '';
      in
      pkgs.lib.isDerivation (fetchCljDeps {
        name = "test-srcroot";
        src = nestedSrc;
        clojure = pkgs.clojure;
        prep = {
          srcRoot = "subdir";
          aliases = [ ];
        };
        hash = "";
      });
    expected = true;
  };

  # Test that multi-prep list works
  testMultiPrepIsDerivation = {
    expr =
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
      pkgs.lib.isDerivation (fetchCljDeps {
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
      });
    expected = true;
  };

  # Test that multiple aliases work
  testMultipleAliasesIsDerivation = {
    expr = pkgs.lib.isDerivation (fetchCljDeps {
      name = "test-multiple-aliases";
      src = pkgs.writeTextDir "deps.edn" ''
        {:deps {org.clojure/clojure {:mvn/version "1.11.1"}}
         :aliases {:test {:extra-deps {lambdaisland/kaocha {:mvn/version "1.87.1366"}}}
                   :dev {:extra-deps {org.clojure/data.json {:mvn/version "2.4.0"}}}}}
      '';
      clojure = pkgs.clojure;
      prep = {
        aliases = [
          ":test"
          ":dev"
        ];
      };
      hash = "";
    });
    expected = true;
  };
}
