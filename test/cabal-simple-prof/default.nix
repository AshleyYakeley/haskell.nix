# Test a package set
{ stdenv, lib, util, cabalProject', haskellLib, recurseIntoAttrs, testSrc, compiler-nix-name, evalPackages }:

with lib;

let
  modules = [
    {
      # Package has no exposed modules which causes
      #   haddock: No input file(s)
      packages.cabal-simple.doHaddock = false;
      packages.cabal-simple.enableProfiling = true;
      enableLibraryProfiling = true;
      # executableProfiling = false;
    }
  ];

  project = cabalProject' {
    inherit compiler-nix-name evalPackages;
    src = testSrc "cabal-simple-prof";
    inherit modules;
    cabalProjectLocal = lib.optionalString (__elem compiler-nix-name ["ghc9820230704"]) ''
      source-repository-package
        type: git
        location: https://github.com/glguy/th-abstraction.git
        tag: 24b9ea9b498b182e44abeb3a755e2b4e35c48788
        --sha256: sha256-nWWZVEek0fNVRI+P5oXkuJyrPJWts5tCphymFoYWIPg=
    '';
  };

in recurseIntoAttrs {
  # This test seeems to be broken on 8.6 and 8.8 and ghcjs
  meta.disabled = compiler-nix-name == "ghc865" || compiler-nix-name == "ghc884" || stdenv.hostPlatform.isGhcjs;
  ifdInputs = {
    inherit (project) plan-nix;
  };
  run = stdenv.mkDerivation {
    name = "cabal-simple-prof-test";

    buildCommand = ''
      exe="${(project.getComponent "cabal-simple:exe:cabal-simple").exePath}"

      size=$(command stat --format '%s' "$exe")
      printf "size of executable $exe is $size. \n" >& 2

      # fixme: run on target platform when cross-compiled
      printf "checking whether executable runs with profiling... " >& 2
      # Curiosity: cross compilers prodcing profiling with `+RTS -p -h` lead to the following cryptic message:
      #   cabal-simple: invalid heap profile option: -h*
      # Hence we pass `-hc`.
      ${toString (project.getComponent "cabal-simple:exe:cabal-simple").config.testWrapper} $exe +RTS -p -hc

      touch $out
    '';

    meta = {
      platforms = platforms.all;
    };

    passthru = {
      # Used for debugging with nix repl
      inherit project;
    };
  };
}
