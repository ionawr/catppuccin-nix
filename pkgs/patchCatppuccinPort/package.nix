{
  lib,
  pkgs,
  fetchCatppuccinPort,
  paletteNpm,
}: {
  port,
  rev,
  hash,
  ...
} @ args: let
  removeArgs = ["port"];
  pristine = fetchCatppuccinPort {inherit port rev hash;} // lib.removeAttrs args removeArgs;

  patchScript = ./patch.py;
  skipPatch = [];
in
  if builtins.elem port skipPatch
  then pristine
  else
    (
      pkgs.runCommandLocal "catppuccin-${port}-patched" {
        src = pristine;
        nativeBuildInputs = [pkgs.python3];
        passthru = {inherit rev paletteNpm;};
      } ''
        cp -r --no-preserve=mode --dereference "$src/." "$out"

        python3 ${patchScript} "$out" --palette ${paletteNpm}
      ''
    )
