{ catppuccinLib }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    mkRemovedOptionModule
    toList
    ;

  cfg = config.catppuccin.gtk;

  # Relative to `catppuccin.gtk`
  removedOptions = [
    "enable"
    "flavor"
    "accent"

    "gnomeShellTheme"
    "size"
    "tweaks"
  ];

  removedOptionModules = map (
    optionPath:

    let
      attrPath = [
        "catppuccin"
        "gtk"
      ]
      ++ toList optionPath;
      moduleName = concatStringsSep "." attrPath;
    in

    mkRemovedOptionModule attrPath ''
      `${moduleName}` was removed from catppuccin/nix, as the upstream port has been archived and began experiencing breakages.

      Please see https://github.com/catppuccin/gtk/issues/262
    ''
  ) removedOptions;
in

{
  imports = removedOptionModules;

  options.catppuccin.gtk = {
    icon = catppuccinLib.mkCatppuccinOption {
      name = "GTK modified Papirus icon theme";

      accentSupport = true;
    };
  };

  config = lib.mkIf cfg.icon.enable {
    warnings = lib.optional (cfg.icon.accent == "monochrome") ''
      catppuccin.gtk.icon: papirus-folders does not support the "monochrome" accent, falling back to "blue"
    '';

    gtk.iconTheme =
      let
        polarity = if cfg.icon.flavor == "light" then "Light" else "Dark";
        accent = if cfg.icon.accent == "monochrome" then "blue" else cfg.icon.accent;
        originalFlavor = if cfg.icon.flavor == "light" then "latte" else "mocha";
      in
      {
        name = "Papirus-${polarity}";
        package = pkgs.catppuccin-papirus-folders.override { inherit accent; flavor = originalFlavor; };
      };
  };
}
