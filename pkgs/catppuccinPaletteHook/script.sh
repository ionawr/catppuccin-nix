catppuccinPaletteHook() {
    echo "Executing catppuccinPaletteHook"

    if [[ ! -d ".catppuccin-palette" ]]; then
        return
    fi

    # Find and replace @catppuccin/palette in node_modules
    for palette_dir in node_modules/.pnpm/@catppuccin+palette@*/node_modules/@catppuccin/palette \
                       node_modules/@catppuccin/palette; do
        if [[ -d "$palette_dir" ]]; then
            echo "Overriding palette at $palette_dir"
            rm -rf "$palette_dir"/*
            cp -r .catppuccin-palette/* "$palette_dir/"
        fi
    done
}

postConfigureHooks+=(catppuccinPaletteHook)
