{ catppuccinLib }:
{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.catppuccin.anki;
in

{
  options.catppuccin.anki = catppuccinLib.mkCatppuccinOption { name = "anki"; };

  config = lib.mkIf cfg.enable {
    programs.anki = {
      addons = with pkgs.ankiAddons; [
        (recolor.withConfig {
          config =
            let
              polarity = config.catppuccin.flavor;
              flavor = if config.catppuccin.flavor == "light" then "Latte" else "Mocha";
              version = builtins.splitVersion recolor.version;

              originalTheme = builtins.readFile "${recolor}/share/anki/addons/recolor/themes/(${polarity}) Catppuccin ${flavor}.json";
              patchedTheme = catppuccinLib.patchColors originalTheme;
            in
            (builtins.fromJSON patchedTheme)
            // {
              version = {
                major = lib.toInt (builtins.elemAt version 0);
                minor = lib.toInt (builtins.elemAt version 1);
              };
            };
        })
      ];
    };
  };
}
