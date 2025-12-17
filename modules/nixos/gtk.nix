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

  config =
    lib.mkIf
      (
        cfg.icon.enable
        && (config.services.desktopManager.gnome.enable || config.services.displayManager.gdm.enable)
      )
      (
        let
          accent = if cfg.icon.accent == "monochrome" then "blue" else cfg.icon.accent;
        in
        {
          warnings = lib.optional (cfg.icon.accent == "monochrome") ''
            catppuccin.gtk.icon: papirus-folders does not support the "monochrome" accent, falling back to "blue"
          '';

          services.displayManager.environment.XDG_DATA_DIRS = (
            (lib.makeSearchPath "share" [
              (pkgs.catppuccin-papirus-folders.override { inherit accent; inherit (cfg.icon) flavor; })
            ])
            + ":"
          );

          programs.dconf.profiles.gdm.databases = [
            {
              lockAll = true;
              settings."org/gnome/desktop/interface" =
                let
                  polarity = if cfg.icon.flavor == "light" then "Light" else "Dark";
                in
                {
                  icon-theme = "Papirus-${polarity}";
                };
            }
          ];
        }
      );
}
