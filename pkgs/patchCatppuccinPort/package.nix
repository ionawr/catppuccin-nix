{
  lib,
  pkgs,
  fetchCatppuccinPort,
  paletteNpm,
}: {
  port,
  rev ? null,
  tag ? null,
  lastModified ? null,
  hash,
  ...
} @ args:
assert lib.assertMsg (rev != null || tag != null)
  "patchCatppuccinPort: port `${port}` must specify at least one of `rev` or `tag`";
let
  removeArgs = ["port"];
  pristine = fetchCatppuccinPort {inherit port rev tag hash;} // lib.removeAttrs args removeArgs;

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
        passthru = {inherit rev tag paletteNpm;}
        // lib.optionalAttrs (lastModified != null) {inherit lastModified;};
      } ''
        cp -r --no-preserve=mode --dereference "$src/." "$out"

        python3 ${patchScript} "$out" --palette ${paletteNpm}
      ''
    )
