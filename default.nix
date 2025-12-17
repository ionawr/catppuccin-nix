{
  pkgs ? import <nixpkgs> {
    inherit system;
    config = { };
    overlays = [ ];
  },
  lib ? pkgs.lib,
  system ? builtins.currentSystem,
  palette,
}:

let
  catppuccinPackages =
    let
      generated = lib.foldlAttrs (
        acc: port:
        {
          rev,
          hash,
          lastModified,
        }:
        lib.recursiveUpdate acc {
          # Save our sources for each port
          sources.${port} = catppuccinPackages.patchCatppuccinPort { inherit port rev hash palette; };

          # And create a default package for them
          "${port}" = catppuccinPackages.buildCatppuccinPort { inherit port lastModified; };
        }
      ) { } (lib.importJSON ./pkgs/sources.json);

      paletteNpm = palette.packages.${pkgs.stdenv.hostPlatform.system}.npm;

      collected = lib.packagesFromDirectoryRecursive {
        callPackage = lib.callPackageWith (pkgs // catppuccinPackages // { inherit paletteNpm; });
        directory = ./pkgs;
      };
    in
    generated
    // collected
    // {
      sources = generated.sources // {
        palette = pkgs.runCommand "catppuccin-palette-source" { } ''
          mkdir -p $out
          cp ${palette.packages.${pkgs.stdenv.hostPlatform.system}.json} $out/palette.json
        '';
      };
    };
in

{
  # Filter out derivations not available on/meant for the current system
  packages = lib.filterAttrs (lib.const (
    deriv:
    let
      # Only export packages available on the current system, *unless* they are being cross compiled
      availableOnHost = lib.meta.availableOn pkgs.stdenv.hostPlatform deriv;
      # `nix flake check` doesn't like broken packages
      broken = deriv.meta.broken or false;
      isCross = deriv.stdenv.buildPlatform != deriv.stdenv.targetPlatform;
      # Make sure we don't remove our functions
      isFunction = lib.isFunction deriv;
      isDerivation = lib.isDerivation deriv;
    in
    isFunction || (isDerivation && (!broken) && (availableOnHost || isCross))
  )) catppuccinPackages;

  shell = import ./shell.nix { inherit pkgs; };
}
