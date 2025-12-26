{
  lib,
  patchCatppuccinPort,
  nix-update-script,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "whiskers";
  version = "2.9.0";

  src = patchCatppuccinPort {
    port = "whiskers";
    tag = "v${finalAttrs.version}";
    hash = "sha256-KU2cHBtz9rdfhulINRaQm+YZ7n8OBULrSHSSxmoitnk=";
  };

  patches = [
    ./patches/0001-cargo-toml-override.patch
    ./patches/0002-cli-rs-override.patch
    ./patches/0003-models-rs-override.patch
  ];

  cargoPatches = [
    ./patches/0001-cargo-lock-override.patch
  ];

  cargoHash = "sha256-40IPDdxKTWYxsCfsECsXDGwfxXiTEIelxIGAFv3xlU4=";

  __structuredAttrs = true;
  doCheck = false;

  passthru = {
    updateScript = nix-update-script {};
  };

  meta = {
    description = "Soothing port creation tool for the high-spirited!";
    homepage = "https://catppuccin.com";
    license = lib.licenses.mit;
    mainProgram = "whiskers";
    maintainers = with lib.maintainers; [
      getchoo
      isabelroses
    ];
  };
})
