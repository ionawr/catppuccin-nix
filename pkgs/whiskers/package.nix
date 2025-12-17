{
  lib,
  patchCatppuccinPort,
  nix-update-script,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "whiskers";
  version = "2.5.1";

  src = patchCatppuccinPort {
    port = "whiskers";
    rev = "09a379aaa387b35aa51342d9f278fa4030c48e86";
    hash = "sha256-9EWq1f9tJfVtuOPEibgYmS52qSIWLP30E1QUj3jfo2A=";
  };

  patches = [
    ./patches/cargo-toml-override.patch
    ./patches/cli-rs-override.patch
    ./patches/models-rs-override.patch
  ];

  cargoPatches = [
    ./patches/cargo-lock-override.patch
  ];

  cargoHash = "sha256-XPlHnppCg90InoVUXmDwBSC9ZDZgNSJAFOc6UzpLmjc=";

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
