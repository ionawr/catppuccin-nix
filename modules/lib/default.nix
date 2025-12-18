{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    flip
    importJSON
    mkEnableOption
    mkOption
    mkSinkUndeclaredOptions
    optional
    optionalAttrs
    types
    versionAtLeast
    toSentenceCase
    ;

  inherit (lib.modules) importApply;

  inherit (pkgs)
    runCommand
    ;
in

lib.makeExtensible (ctp: {
  types = {
    flavor = types.enum [
      "dark"
      "light"
    ];

    accent = types.enum [
      "blue"
      "flamingo"
      "green"
      "lavender"
      "maroon"
      "mauve"
      "monochrome"
      "peach"
      "pink"
      "red"
      "rosewater"
      "sapphire"
      "sky"
      "teal"
      "yellow"
    ];
  };

  /**
    Map user-facing flavor names to internal Catppuccin flavor names.

    # Example

    ```nix
    toInternalFlavor "dark"
    => "mocha"
    ```

    # Type

    ```
    toInternalFlavor :: String -> String
    ```

    # Arguments

    - [flavor] User-facing flavor name ("dark" or "light")
  */
  toInternalFlavor = flavor: if flavor == "dark" then "mocha" else "latte";

  /**
    Capitalize the first letter in a string, and change the final "e" into "é" if the
    original string is "frappe"

    # Example

    ```nix
    mkFlavorName "frappe"
    => "Frappé"
    ```

    # Type

    ```
    mkFlavorName :: String -> String
    ```

    # Arguments

    - [str] String to capitalize
  */
  mkFlavorName = str: if str == "frappe" then "Frappé" else toSentenceCase str;

  /**
    Reads a YAML file

    # Example

    ```nix
    importYAML ./file.yaml
    ```

    # Type

    ```
    importYAML :: Path -> Any
    ```

    # Arguments

    - [path] Path to YAML file
  */
  importYAML =
    path:
    importJSON (
      runCommand "converted.json" { nativeBuildInputs = [ pkgs.yj ]; } ''
        yj < ${path} > $out
      ''
    );

  /**
    Reads an INI file

    # Example

    ```nix
    importINI ./file.ini
    ```

    # Type

    ```
    importINI :: Path -> Any
    ```

    # Arguments

    - [path] Path to INI file
  */
  importINI =
    path:
    importJSON (
      runCommand "converted.json" { nativeBuildInputs = [ pkgs.jc ]; } ''
        jc --ini < ${path} > $out
      ''
    );

  /**
    Reads a raw INI file

    # Example

    ```nix
    importINIRaw ./file.ini
    ```

    # Type

    ```
    importINIRaw :: Path -> Any
    ```

    # Arguments

    - [path] Path to INI file
  */
  importINIRaw =
    path:
    importJSON (
      runCommand "converted.json" { nativeBuildInputs = [ pkgs.jc ]; } ''
        jc --ini -r < ${path} > $out
      ''
    );

  /**
    Creates an attribute set of standard Catppuccin module options

    # Example

    ```
    mkCatppuccinOption { name = "myProgram"; }
    ```

    # Type

    ```
    mkCatppuccinOption :: AttrSet -> AttrSet
    ```

    # Arguments

    - [name] Name of the module
    - [useGlobalEnable] Whether to enable the module by default when `catppuccin.enable` is set (recommended, defaults to `true`)
    - [default] Default `enable` option value (defaults to `if useGlobalEnable then config.catppuccin.enable else false`)
    - [defaultText] Default `enable` option text (automatic if `null`, defaults to `if useGlobalEnable then "config.catppuccin.enable" else null`)
    - [accentSupport] Add an `accent` option (defaults to `false`)
  */
  mkCatppuccinOption =
    {
      name,
      useGlobalEnable ? true,
      default ? if useGlobalEnable then config.catppuccin.enable else false,
      defaultText ? if useGlobalEnable then "catppuccin.enable" else null,
      accentSupport ? false,
    }:

    {
      enable =
        mkEnableOption "Catppuccin theme for ${name}"
        // (
          {
            inherit default;
          }
          // optionalAttrs (defaultText != null) { inherit defaultText; }
        );

      flavor = mkOption {
        type = ctp.types.flavor;
        default = config.catppuccin.flavor;
        defaultText = "catppuccin.flavor";
        description = "Catppuccin flavor for ${name}";
      };
    }
    // optionalAttrs accentSupport {
      accent = mkOption {
        type = ctp.types.accent;
        default = config.catppuccin.accent;
        defaultText = "catppuccin.accent";
        description = "Catppuccin accent for ${name}";
      };
    };

  /**
    Returns the current release version of nixos or home-manager.
    Throws an evaluation error if neither are found

    # Example

    ```nix
    getModuleRelease
    => "24.11"
    ```

    # Type

    ```
    getModuleRelease :: String
    ```
  */
  getModuleRelease =
    config.home.version.release or config.system.nixos.release
      or (throw "Couldn't determine release version!");

  /**
    Create options only if the current module release is more than a given version

    # Example

    ```nix
    mkVersionedOpts "24.11" { myOption = lib.mkOption { ... }; }
    => { myOption = { ... }; }
    ```

    # Type

    ```
    mkVersionedOpts :: String -> AttrSet -> AttrSet
    ```

    # Arguments

    - [minVersion] Minimum module release to create options for
    - [options] Conditional options
  */
  mkVersionedOpts =
    minVersion: options:
    if versionAtLeast ctp.getModuleRelease minVersion then options else mkSinkUndeclaredOptions { };

  /**
    Imports the given modules with the current library

    # Example

    ```nix
    applyToModules [ ./module.nix ]
    => [ { ... } ]
    ```

    # Type

    ```
    applyToModules :: [ Module ] -> [ Module ]
    ```

    # Arguments

    - [modules] Modules to import
    ```
  */
  applyToModules = map (flip importApply { catppuccinLib = ctp; });

  /**
    Patch the given string to use custom colour codes

    # Example

    ```nix
    patchColors "#1e1e2e" => "#161616"
    ```

    # Type

    ```
    patchColors :: String -> String
    ```

    # Arguments

    - str: String to patch
    ```
  */
  patchColors =
    str:
      builtins.replaceStrings [
        "CDD6F4" "cdd6f4" # Mocha text
        "BAC2DE" "bac2de" # Mocha subtext1
        "A6ADC8" "a6adc8" # Mocha subtext0
        "9399B2" "9399b2" # Mocha overlay2
        "7F849C" "7f849c" # Mocha overlay1
        "6C7086" "6c7086" # Mocha overlay0
        "585B70" "585b70" # Mocha surface2
        "45475A" "45475a" # Mocha surface1
        "313244" "313244" # Mocha surface0
        "1E1E2E" "1e1e2e" # Mocha base
        "181825" "181825" # Mocha mantle
        "11111B" "11111b" # Mocha crust
        "4C4F69" "4c4f69" # Latte text
        "5C5F77" "5c5f77" # Latte subtext1
        "6C6F85" "6c6f85" # Latte subtext0
        "7C7F93" "7c7f93" # Latte overlay2
        "8C8FA1" "8c8fa1" # Latte overlay1
        "9CA0B0" "9ca0b0" # Latte overlay0
        "ACB0BE" "acb0be" # Latte surface2
        "BCC0CC" "bcc0cc" # Latte surface1
        "CCD0DA" "ccd0da" # Latte surface0
        "EFF1F5" "eff1f5" # Latte base
        "E6E9EF" "e6e9ef" # Latte mantle
        "DCE0E8" "dce0e8" # Latte crust
      ] [
        "F4F4F4" "f4f4f4"
        "E0E0E0" "e0e0e0"
        "C6C6C6" "c6c6c6"
        "A8A8A8" "a8a8a8"
        "8D8D8D" "8d8d8d"
        "6F6F6F" "6f6f6f"
        "525252" "525252"
        "393939" "393939"
        "262626" "262626"
        "161616" "161616"
        "0B0B0B" "0b0b0b"
        "000000" "000000"
        "0B0B0B" "0b0b0b"
        "161616" "161616"
        "262626" "262626"
        "393939" "393939"
        "525252" "525252"
        "6F6F6F" "6f6f6f"
        "8D8D8D" "8d8d8d"
        "A8A8A8" "a8a8a8"
        "C6C6C6" "c6c6c6"
        "E8E8E8" "e8e8e8"
        "E0E0E0" "e0e0e0"
        "D8D8D8" "d8d8d8"
      ] str;
})
