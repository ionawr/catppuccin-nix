{
  lib,
  patchCatppuccinPort,
  nix-update-script,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "whiskers";
  version = "2.9.0";

  src = patchCatppuccinPort {
    port = "whiskers";
    rev = "refs/tags/v${version}";
    hash = "sha256-KU2cHBtz9rdfhulINRaQm+YZ7n8OBULrSHSSxmoitnk=";
  };

  patches = [
    ./patches/cargo-toml-override.patch
    ./patches/cli-rs-override.patch
    ./patches/models-rs-override.patch
  ];

  cargoPatches = [
    ./patches/cargo-lock-override.patch
  ];

  cargoHash = "sha256-40IPDdxKTWYxsCfsECsXDGwfxXiTEIelxIGAFv3xlU4=";

  doCheck = false;

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Soothing port creation tool for the high-spirited!";
    homepage = "https://catppuccin.com";
    license = lib.licenses.mit;
  };
}
