# JS package override (postConfigure)
catppuccinPaletteHook() {
  echo "Executing catppuccinPaletteHook"

  if [[ ! -d ".catppuccin-palette" ]]; then
    return
  fi

  for palette_dir in node_modules/.pnpm/@catppuccin+palette@*/node_modules/@catppuccin/palette \
    node_modules/@catppuccin/palette; do
    if [[ -d "$palette_dir" ]]; then
      echo "Overriding palette at $palette_dir"
      rm -rf "$palette_dir"/*
      cp -r .catppuccin-palette/* "$palette_dir/"
    fi
  done
}

# Rust crate override (postPatch)
catppuccinRustHook() {
  echo "Executing catppuccinRustHook"

  if [[ -z "${cargoDepsCopy:-}" ]] || [[ ! -d "${cargoDepsCopy:-}" ]]; then
    return
  fi

  for crate_dir in "$cargoDepsCopy"/catppuccin-*; do
    if [[ -d "$crate_dir" ]]; then
      echo "Replacing vendored catppuccin crate at $crate_dir"
      rm -rf "$crate_dir"
      cp -r @catppuccinRustSrc@ "$crate_dir"
      chmod -R +w "$crate_dir"
    fi
  done

  echo '{"files": {}, "package": null}' >"$crate_dir/.cargo-checksum.json"
}

postConfigureHooks+=(catppuccinPaletteHook)
postPatchHooks+=(catppuccinRustHook)
