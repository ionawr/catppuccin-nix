#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import sys
from dataclasses import dataclass
from fnmatch import fnmatch
from pathlib import Path
from typing import Callable, Iterable, Sequence

Replacement = tuple[str, str]


# colour replacement tables (from_hex, to_hex)
MOCHA_REPLACEMENTS: tuple[Replacement, ...] = (
    ("cdd6f4", "f4f4f4"),  # text
    ("bac2de", "e0e0e0"),  # subtext1
    ("a6adc8", "c6c6c6"),  # subtext0
    ("9399b2", "a8a8a8"),  # overlay2
    ("7f849c", "8d8d8d"),  # overlay1
    ("6c7086", "6f6f6f"),  # overlay0
    ("585b70", "525252"),  # surface2
    ("45475a", "393939"),  # surface1
    ("313244", "262626"),  # surface0
    ("1e1e2e", "161616"),  # base
    ("181825", "0b0b0b"),  # mantle
    ("11111b", "000000"),  # crust
)

LATTE_REPLACEMENTS: tuple[Replacement, ...] = (
    ("4c4f69", "0b0b0b"),  # text
    ("5c5f77", "161616"),  # subtext1
    ("6c6f85", "262626"),  # subtext0
    ("7c7f93", "393939"),  # overlay2
    ("8c8fa1", "525252"),  # overlay1
    ("9ca0b0", "6f6f6f"),  # overlay0
    ("acb0be", "8d8d8d"),  # surface2
    ("bcc0cc", "a8a8a8"),  # surface1
    ("ccd0da", "c6c6c6"),  # surface0
    ("eff1f5", "e8e8e8"),  # base
    ("e6e9ef", "e0e0e0"),  # mantle
    ("dce0e8", "d8d8d8"),  # crust
)


@dataclass(frozen=True)
class Flavor:
    """Per-flavor configuration for variant generation and renaming."""
    name: str
    target: str
    rosewater_hex: str
    monochrome_hex: str

    @property
    def name_cap(self) -> str:
        return self.name.capitalize()

    @property
    def target_cap(self) -> str:
        return self.target.capitalize()


FLAVORS: tuple[Flavor, ...] = (
    Flavor(name="mocha", target="dark", rosewater_hex="f5e0dc", monochrome_hex="f4f4f4"),
    Flavor(name="latte", target="light", rosewater_hex="dc8a78", monochrome_hex="0b0b0b"),
)


def iter_files(root: Path) -> Iterable[Path]:
    for path in root.rglob("*"):
        if path.is_file():
            yield path


def _read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None


def _write_text(path: Path, content: str) -> None:
    try:
        path.write_text(content, encoding="utf-8")
    except OSError:
        return


def _case_preserving_replace(match: re.Match, mapping: dict[str, str]) -> str:
    matched = match.group(0)
    replacement = mapping[matched.lower()]

    if matched.isupper():
        return replacement.upper()
    if matched[:1].isupper():
        return replacement[:1].upper() + replacement[1:]
    return replacement


def _should_skip_file(file_path: Path) -> bool:
    """Skip files that shouldn't be patched (lock files, package manifests, etc.)."""
    name = file_path.name.lower()
    return "package" in name or "lock" in name


def replace_in_files(root: Path, replacements: Sequence[Replacement]) -> None:
    if not replacements:
        return

    pattern = re.compile("|".join(re.escape(src) for src, _ in replacements), re.IGNORECASE)
    mapping = {src.lower(): dst for src, dst in replacements}

    for file_path in iter_files(root):
        if _should_skip_file(file_path):
            continue

        content = _read_text(file_path)
        if content is None or not pattern.search(content):
            continue

        new_content = pattern.sub(lambda m: _case_preserving_replace(m, mapping), content)
        _write_text(file_path, new_content)


def _rename_matching(
    root: Path,
    *,
    predicate: Callable[[Path], bool],
    from_str: str,
    to_str: str,
) -> None:
    pattern = re.compile(re.escape(from_str), re.IGNORECASE)

    candidates: list[Path] = [
        p for p in root.rglob("*")
        if predicate(p) and pattern.search(p.name)
    ]

    # avoid renaming parent before its children
    candidates.sort(key=lambda p: len(p.parts), reverse=True)

    for path in candidates:
        new_path = path.with_name(pattern.sub(to_str, path.name))
        if new_path.exists():
            continue
        try:
            path.rename(new_path)
        except OSError:
            continue


def rename_dirs(root: Path, *, from_str: str, to_str: str) -> None:
    _rename_matching(root, predicate=Path.is_dir, from_str=from_str, to_str=to_str)


def rename_files(root: Path, *, from_str: str, to_str: str) -> None:
    _rename_matching(root, predicate=Path.is_file, from_str=from_str, to_str=to_str)


def remove_items(root: Path, patterns: Sequence[str]) -> None:
    if not patterns:
        return

    normalized = [p.lower() for p in patterns]
    candidates: list[Path] = []

    for path in root.rglob("*"):
        name = path.name.lower()
        if any(fnmatch(name, pat) for pat in normalized):
            candidates.append(path)

    # remove children before parents
    candidates.sort(key=lambda p: len(p.parts), reverse=True)

    for path in candidates:
        try:
            if path.is_dir():
                shutil.rmtree(path, ignore_errors=True)
            else:
                path.unlink(missing_ok=True)
        except OSError:
            continue


def _rosewater_to_monochrome_pattern(flavor: Flavor) -> re.Pattern:
    return re.compile(
        rf"{re.escape(flavor.rosewater_hex)}|rosewater|Rosewater",
        re.IGNORECASE,
    )


def _rosewater_to_monochrome_replacer(flavor: Flavor) -> Callable[[re.Match], str]:
    def repl(match: re.Match) -> str:
        token = match.group(0)
        if token.lower() == flavor.rosewater_hex.lower():
            return flavor.monochrome_hex
        if token == "Rosewater":
            return "Monochrome"
        if token.lower() == "rosewater":
            return "monochrome"
        return token  # should be unreachable

    return repl


def _patch_tree_text(root: Path, pattern: re.Pattern, repl: Callable[[re.Match], str]) -> None:
    for file_path in iter_files(root):
        if _should_skip_file(file_path):
            continue
        content = _read_text(file_path)
        if content is None or not pattern.search(content):
            continue
        _write_text(file_path, pattern.sub(repl, content))


def create_monochrome_variants(root: Path) -> None:
    for flavor in FLAVORS:
        content_pattern = _rosewater_to_monochrome_pattern(flavor)
        content_replacer = _rosewater_to_monochrome_replacer(flavor)

        # dir: ...-{flavor}-rosewater -> ...-{flavor}-monochrome
        dir_suffix = re.compile(rf"-{re.escape(flavor.name)}-rosewater$", re.IGNORECASE)
        for src_dir in list(root.rglob(f"*-{flavor.name}-rosewater")):
            if not src_dir.is_dir():
                continue

            dest_dir = src_dir.with_name(
                dir_suffix.sub(f"-{flavor.name}-monochrome", src_dir.name)
            )
            if dest_dir.exists():
                continue

            shutil.copytree(src_dir, dest_dir)

            # file name: rosewater -> monochrome
            for file_path in list(dest_dir.rglob("*rosewater*")):
                if file_path.is_file():
                    file_path.rename(
                        file_path.with_name(file_path.name.replace("rosewater", "monochrome"))
                    )

            _patch_tree_text(dest_dir, content_pattern, content_replacer)

        # file content: *-{flavor}-rosewater.* -> *-{flavor}-monochrome.*
        file_name_re = re.compile(
            rf"^(.*-{re.escape(flavor.name)})-rosewater(\..+)$", re.IGNORECASE
        )
        for src_file in list(root.rglob(f"*-{flavor.name}-rosewater.*")):
            if not src_file.is_file():
                continue

            m = file_name_re.match(src_file.name)
            if not m:
                continue

            dest_file = src_file.with_name(f"{m.group(1)}-monochrome{m.group(2)}")
            if dest_file.exists():
                continue

            shutil.copy2(src_file, dest_file)

            content = _read_text(dest_file)
            if content is None:
                continue
            _write_text(dest_file, content_pattern.sub(content_replacer, content))


def rename_flavors(root: Path) -> None:
    for flavor in FLAVORS:
        rename_dirs(root, from_str=flavor.name, to_str=flavor.target)
        rename_files(root, from_str=flavor.name, to_str=flavor.target)

        pattern = re.compile(re.escape(flavor.name), re.IGNORECASE)

        def repl(match: re.Match) -> str:
            token = match.group(0)

            # preserve casing
            if token == flavor.name_cap:
                return flavor.target_cap
            if token == flavor.name:
                return flavor.target
            if token.lower() == flavor.name:
                return flavor.target.upper() if token.isupper() else flavor.target
            return token

        _patch_tree_text(root, pattern, repl)

def _has_palette_dependency(root: Path) -> bool:
    """Check if any lock file references @catppuccin/palette."""
    for lock_file in ["pnpm-lock.yaml", "yarn.lock", "package-lock.json"]:
        lock_path = root / lock_file
        if lock_path.exists():
            content = _read_text(lock_path)
            if content and "@catppuccin/palette" in content:
                return True
    return False


def inject_palette(root: Path, palette_path: Path) -> None:
    """Copy custom palette to source for JS-based ports."""
    if not _has_palette_dependency(root):
        return

    # Copy palette to source (will be used by catppuccinPaletteHook after npm install)
    dest = root / ".catppuccin-palette"
    shutil.copytree(palette_path, dest)


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Patch Catppuccin port themes for dark/light naming"
    )
    parser.add_argument("out_dir", type=Path, help="Output directory to patch")
    parser.add_argument("--palette", type=Path, help="Path to custom palette npm package")

    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    out_dir: Path = args.out_dir.resolve()

    if not out_dir.exists():
        print(f"Error: Output directory does not exist: {out_dir}", file=sys.stderr)
        return 1

    replacements: list[Replacement] = list(MOCHA_REPLACEMENTS) + list(LATTE_REPLACEMENTS)

    replace_in_files(out_dir, replacements)
    create_monochrome_variants(out_dir)
    rename_flavors(out_dir)
    remove_items(out_dir, ["*frappe*", "*macchiato*"])

    if args.palette:
        inject_palette(out_dir, args.palette)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
