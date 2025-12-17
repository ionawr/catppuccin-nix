{ catppuccinLib }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.catppuccin.gtk;
in

{
  options.catppuccin.gtk = {
    icon = catppuccinLib.mkCatppuccinOption {
      name = "GTK modified Papirus icon theme";

      accentSupport = true;
    };
  };

  config = lib.mkIf (config.catppuccin.enable && cfg.icon.enable) {
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
