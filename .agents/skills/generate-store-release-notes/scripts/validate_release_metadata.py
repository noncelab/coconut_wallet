#!/usr/bin/env python3
"""Print or validate coconut_wallet store release-note output paths."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


APP_STORE_LOCALES = ("ko", "en-US", "ja", "es-ES", "de-DE")
PLAY_STORE_LOCALES = ("ko-KR", "en-US", "ja-JP", "es-ES", "de-DE")
MAX_CHARACTERS = 500


def repository_root() -> Path:
    return Path(__file__).resolve().parents[4]


def next_android_version_code(root: Path, flavor: str) -> int:
    pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
    pattern = rf"^\s*aos_{re.escape(flavor)}:\s*\d+\.\d+\.\d+\+(\d+)\s*$"
    match = re.search(pattern, pubspec, flags=re.MULTILINE)
    if not match:
        raise ValueError(f"app_versions.aos_{flavor} was not found in pubspec.yaml")
    return int(match.group(1)) + 1


def source_path(root: Path, flavor: str) -> Path:
    return root / "fastlane" / "store_metadata" / "source" / flavor / "release_notes.ko.md"


def output_paths(root: Path, flavor: str, version_code: int) -> list[Path]:
    generated = root / "fastlane" / "store_metadata" / "generated"
    ios = [generated / "ios" / flavor / locale / "release_notes.txt" for locale in APP_STORE_LOCALES]
    android = [
        generated / "android" / flavor / locale / "changelogs" / f"{version_code}.txt"
        for locale in PLAY_STORE_LOCALES
    ]
    return ios + android


def meaningful_source(text: str) -> str:
    return re.sub(r"<!--.*?-->", "", text, flags=re.DOTALL).strip()


def validate_source(path: Path) -> list[str]:
    if not path.is_file():
        return [f"missing Korean source: {path}"]
    if not meaningful_source(path.read_text(encoding="utf-8")):
        return [f"empty Korean source: {path}"]
    return []


def validate_outputs(paths: list[Path]) -> list[str]:
    errors: list[str] = []
    for path in paths:
        if not path.is_file():
            errors.append(f"missing output: {path}")
            continue
        text = path.read_text(encoding="utf-8")
        content = text.strip()
        if not content:
            errors.append(f"empty output: {path}")
        if len(content) > MAX_CHARACTERS:
            errors.append(f"too long ({len(content)} > {MAX_CHARACTERS}): {path}")
        if not text.endswith("\n"):
            errors.append(f"missing trailing newline: {path}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--flavor", choices=("mainnet", "regtest"), required=True)
    parser.add_argument("--print-plan", action="store_true")
    args = parser.parse_args()

    root = repository_root()
    try:
        version_code = next_android_version_code(root, args.flavor)
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1

    source = source_path(root, args.flavor)
    outputs = output_paths(root, args.flavor, version_code)

    print(f"flavor={args.flavor}")
    print(f"android_version_code={version_code}")
    print(f"source={source.relative_to(root)}")
    for path in outputs:
        print(f"output={path.relative_to(root)}")

    if args.print_plan:
        return 0

    errors = validate_source(source) + validate_outputs(outputs)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    print("validation=ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
