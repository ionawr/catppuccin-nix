#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import sys
from dataclasses import dataclass
from fnmatch import fnmatch
from pathlib import Path
from typing import Callable, Iterator, Mapping, Sequence

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
class Flavour:
    name: str
    target: str
    rosewater_hex: str
    monochrome_hex: str


FLAVOURS: tuple[Flavour, ...] = (
    Flavour(name="mocha", target="dark", rosewater_hex="f5e0dc", monochrome_hex="f4f4f4"),
    Flavour(name="latte", target="light", rosewater_hex="dc8a78", monochrome_hex="0b0b0b"),
)


@dataclass(frozen=True)
class CaseReplacer:
    pattern: re.Pattern
    mapping: Mapping[str, str]

    @classmethod
    def compile(cls, replacements: Sequence[Replacement]) -> "CaseReplacer":
        pattern = re.compile("|".join(re.escape(s) for s, _ in replacements), re.IGNORECASE)
        return cls(pattern, {s.lower(): d for s, d in replacements})

    def sub(self, text: str) -> str:
        return self.pattern.sub(self._repl, text)

    def search(self, text: str) -> bool:
        return self.pattern.search(text) is not None

    def _repl(self, m: re.Match) -> str:
        matched = m.group(0)
        dst = self.mapping[matched.lower()]

        if matched.isupper():
            return dst.upper()
        if matched[:1].isupper():
            return dst[:1].upper() + dst[1:]
        return dst


_SKIP_FILES: frozenset[str] = frozenset({
    "cargo.toml",
    "cargo.lock",
    "package.json",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
})


def iter_files(root: Path) -> Iterator[Path]:
    for path in root.rglob("*"):
        if path.is_file():
            yield path


def _read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None


def _write_text(path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


def _should_skip_file(file_path: Path) -> bool:
    return file_path.name.lower() in _SKIP_FILES


def replace_in_files(root: Path, replacements: Sequence[Replacement]) -> None:
    if not replacements:
        return
    _patch_tree_text(root, CaseReplacer.compile(replacements))


def _rename_matching(
    root: Path,
    *,
    predicate: Callable[[Path], bool],
    replacer: CaseReplacer,
) -> None:
    candidates: list[Path] = [
        p for p in root.rglob("*")
        if predicate(p) and replacer.search(p.name)
    ]

    # avoid renaming parent before its children
    candidates.sort(key=lambda p: len(p.parts), reverse=True)

    for path in candidates:
        new_path = path.with_name(replacer.sub(path.name))
        if new_path.exists():
            continue
        path.rename(new_path)


def rename_dirs(root: Path, *, replacer: CaseReplacer) -> None:
    _rename_matching(root, predicate=Path.is_dir, replacer=replacer)


def rename_files(root: Path, *, replacer: CaseReplacer) -> None:
    _rename_matching(root, predicate=Path.is_file, replacer=replacer)


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
        if path.is_dir():
            shutil.rmtree(path, ignore_errors=True)
        else:
            path.unlink(missing_ok=True)


def _patch_tree_text(root: Path, replacer: CaseReplacer) -> None:
    for file_path in iter_files(root):
        if _should_skip_file(file_path):
            continue
        content = _read_text(file_path)
        if content is None or not replacer.search(content):
            continue
        _write_text(file_path, replacer.sub(content))


def _rosewater_replacer(flavour: Flavour) -> CaseReplacer:
    return CaseReplacer.compile([
        (flavour.rosewater_hex, flavour.monochrome_hex),
        ("rosewater", "monochrome"),
    ])


def create_monochrome_variants(root: Path) -> None:
    for flavour in FLAVOURS:
        _create_variants_for(root, flavour)


def _create_variants_for(root: Path, flavour: Flavour) -> None:
    replacer = _rosewater_replacer(flavour)
    name = re.escape(flavour.name)

    suffix_dir_re = re.compile(rf"-{name}-rosewater$", re.IGNORECASE)
    suffix_file_re = re.compile(rf"^(.*-{name})-rosewater(\..+)$", re.IGNORECASE)

    variant_dirs: list[Path] = []
    variant_files: list[tuple[Path, re.Match]] = []
    inner_files: list[Path] = []

    for path in root.rglob("*"):
        if path.is_dir():
            if suffix_dir_re.search(path.name):
                variant_dirs.append(path)
        elif (m := suffix_file_re.match(path.name)):
            variant_files.append((path, m))
        elif (
            path.name.lower().startswith("rosewater.")
            and path.parent.name.lower() == flavour.name
        ):
            inner_files.append(path)

    # ...-{flavour}-rosewater -> ...-{flavour}-monochrome
    for src in variant_dirs:
        dst = src.with_name(suffix_dir_re.sub(f"-{flavour.name}-monochrome", src.name))
        if dst.exists():
            continue
        shutil.copytree(src, dst)
        for inner in list(dst.rglob("*rosewater*")):
            if inner.is_file():
                inner.rename(inner.with_name(inner.name.replace("rosewater", "monochrome")))
        _patch_tree_text(dst, replacer)

    # *-{flavour}-rosewater.* -> *-{flavour}-monochrome.*
    for src, m in variant_files:
        dst = src.with_name(f"{m.group(1)}-monochrome{m.group(2)}")
        if not dst.exists():
            _copy_and_patch(src, dst, replacer)

    # {flavour}/rosewater.* -> {flavour}/monochrome.*
    for src in inner_files:
        dst = src.with_name(src.name.replace("rosewater", "monochrome"))
        if not dst.exists():
            _copy_and_patch(src, dst, replacer)


def _copy_and_patch(src: Path, dst: Path, replacer: CaseReplacer) -> None:
    shutil.copy2(src, dst)
    content = _read_text(dst)
    if content is not None:
        _write_text(dst, replacer.sub(content))


def rename_flavours(root: Path) -> None:
    for flavour in FLAVOURS:
        replacer = CaseReplacer.compile([(flavour.name, flavour.target)])
        rename_dirs(root, replacer=replacer)
        rename_files(root, replacer=replacer)
        _patch_tree_text(root, replacer)


def inject_palette_to_js_ports(root: Path, palette_path: Path) -> None:
    def _has_palette_dependency(root: Path) -> bool:
        for lock_file in ["pnpm-lock.yaml", "yarn.lock", "package-lock.json"]:
            lock_path = root / lock_file
            if lock_path.exists():
                content = _read_text(lock_path)
                if content and "@catppuccin/palette" in content:
                    return True
        return False

    if not _has_palette_dependency(root):
        return

    # copy palette to source (will be used by catppuccinPatchHook after npm install)
    dst = root / ".catppuccin-palette"
    shutil.copytree(palette_path, dst)


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Patch Catppuccin port themes"
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

    remove_items(out_dir, ["*frappe*", "*macchiato*"])
    replace_in_files(out_dir, MOCHA_REPLACEMENTS + LATTE_REPLACEMENTS)
    create_monochrome_variants(out_dir)
    rename_flavours(out_dir)

    if args.palette:
        inject_palette_to_js_ports(out_dir, args.palette)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
