# Test a package set
{ stdenv, lib, util, cabalProject', haskellLib, recurseIntoAttrs, testSrc, compiler-nix-name, evalPackages }:

with lib;

let
  modules = [
    {
      # Package has no exposed modules which causes
      #   haddock: No input file(s)
      packages.cabal-sublib.doHaddock = false;
    }
  ];

  # The ./pkgs.nix works for linux & darwin, but not for windows
  project = cabalProject' {
    inherit compiler-nix-name evalPackages;
    src = testSrc "cabal-sublib";
    inherit modules;
    cabalProjectLocal = lib.optionalString (__elem compiler-nix-name ["ghc9820230704"]) ''
      source-repository-package
        type: git
        location: https://github.com/glguy/th-abstraction.git
        tag: 24b9ea9b498b182e44abeb3a755e2b4e35c48788
        --sha256: sha256-nWWZVEek0fNVRI+P5oXkuJyrPJWts5tCphymFoYWIPg=
    '';
  };

  packages = project.hsPkgs;

in recurseIntoAttrs {
  ifdInputs = {
    inherit (project) plan-nix;
  };
  run = stdenv.mkDerivation {
    name = "cabal-sublib-test";

    buildCommand = ''
      exe="${packages.cabal-sublib.components.exes.cabal-sublib.exePath}"

      size=$(command stat --format '%s' "$exe")
      printf "size of executable $exe is $size. \n" >& 2

      # fixme: run on target platform when cross-compiled
      printf "checking whether executable runs... " >& 2
      cat ${haskellLib.check packages.cabal-sublib.components.exes.cabal-sublib}/test-stdout

    '' +
    # Musl and Aarch are statically linked..
    optionalString (!stdenv.hostPlatform.isAarch32 && !stdenv.hostPlatform.isAarch64 && !stdenv.hostPlatform.isMusl) (''
      printf "checking that executable is dynamically linked to system libraries... " >& 2
    '' + optionalString (stdenv.isLinux && !stdenv.hostPlatform.isMusl) ''
      ${haskellLib.lddForTests} $exe | grep 'libc[.]so'
    '' + optionalString stdenv.isDarwin ''
      otool -L $exe |grep .dylib
    '') + ''

      touch $out
    '';

    meta = rec {
      platforms = lib.platforms.all;
      broken = stdenv.hostPlatform.isGhcjs && __elem compiler-nix-name ["ghc961" "ghc962" "ghc9820230704"];
      disabled = broken;
    };

    passthru = {
      # Used for debugging with nix repl
      inherit packages project;
    };
  };
}
