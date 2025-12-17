{ catppuccinLib }:
{ config, lib, ... }:

let
  inherit (config.catppuccin) sources;

  cfg = config.catppuccin.newsboat;
in

{
  options.catppuccin.newsboat = catppuccinLib.mkCatppuccinOption { name = "newsboat"; };

  config = lib.mkIf (config.catppuccin.enable && cfg.enable) {
    programs.newsboat = {
      extraConfig = lib.fileContents "${sources.newsboat}/${cfg.flavor}";
    };
  };
}
