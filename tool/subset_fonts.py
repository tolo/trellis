#!/usr/bin/env python3
"""Regenerate the vendored WOFF2 subsets for the lattice, folio and meadow themes.

Every shipped face is produced from a pinned google/fonts blob by two deterministic
steps: `fontTools.varLib.instancer` pins the axes no theme renders, then
`fontTools.subset` cuts the glyph set and writes WOFF2. Byte-for-byte reproducible
given the same fontTools/brotli versions (see TOOLING below).

    python3 -m venv .venv && .venv/bin/pip install 'fonttools==4.63.0' 'brotli==1.2.0'
    .venv/bin/python tool/subset_fonts.py --write     # regenerate in place
    .venv/bin/python tool/subset_fonts.py --verify    # fail if bytes or coverage drift

`--verify` is the gate, and it checks two independent things:

* SHA-256 of a fresh build against the committed files, so a hand-edited font cannot pass.
* the built cmap of every face against `tool/font_coverage.txt`. The byte compare alone only
  proves a file matches the recipe that produced it, so narrowing LATIN/ARROWS/MARKS and
  re-running `--write` would *redefine* what "correct" means and still report `11 ok`. The
  pinned coverage is the other side of that contract: this script never writes it, so a
  narrowed request fails naming the face and the codepoints it lost. Changing coverage on
  purpose means editing that file by hand - `--write` prints the block to paste.

Scope comes from the tree, not from the list: `themes/*/static/fonts/` is globbed, so a
vendored face missing from OUTPUTS is reported rather than silently left unverified.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

from fontTools.ttLib import TTFont

TOOLING = "fonttools 4.63.0, brotli 1.2.0, python 3.14"

# google/fonts commit the upstream blobs are pinned to.
PIN = "ade3d1533e06b2b1462ffcde8e08b129627ca360"
RAW = f"https://raw.githubusercontent.com/google/fonts/{PIN}/ofl"

# family -> (upstream path under ofl/, upstream SHA-256, instancer axis limits)
FAMILIES = {
    "fraunces": (
        "fraunces/Fraunces%5BSOFT,WONK,opsz,wght%5D.ttf",
        "177ff6c0f14e5550a3c624247cd1189611d4eb65d000b14944c63d967958abbb",
        ["SOFT=0", "WONK=1"],
    ),
    # Italic is vendored for one instance only: the approved A3 mockup loads
    # `Fraunces:ital,opsz,wght@1,9..144,500` for the hero's emphasised word. `wght` is
    # pinned to 500, `opsz` is kept because the headline drives it.
    "fraunces-italic": (
        "fraunces/Fraunces-Italic%5BSOFT,WONK,opsz,wght%5D.ttf",
        "b24448c43702fac4ee856781d461a0dfba8d8e594b6e8e190234b75fed2c0e01",
        ["SOFT=0", "WONK=1", "wght=500"],
    ),
    "instrument-sans": (
        "instrumentsans/InstrumentSans%5Bwdth,wght%5D.ttf",
        "b24f1812584816958afcf22e22d08e44318c5e51651e25d2438efdde389b33b1",
        ["wdth=100"],
    ),
    "spline-sans-mono": (
        "splinesansmono/SplineSansMono%5Bwght%5D.ttf",
        "e20c1df32aa2f886e828cfcc81ca5c405d3f3b160990f6b892923e2e449bf525",
        [],
    ),
    "eb-garamond": (
        "ebgaramond/EBGaramond%5Bwght%5D.ttf",
        "ef9512f92f6d579e5dc75af59a5a4b1b8b47d2eda89e00b954d44520e5369027",
        [],
    ),
    "bricolage-grotesque": (
        "bricolagegrotesque/BricolageGrotesque%5Bopsz,wdth,wght%5D.ttf",
        "413e7357809ddd12fd80a96a8a396de0e401638d4acd3cb3e37532f0472ac682",
        ["wdth=100"],
    ),
    "schibsted-grotesk": (
        "schibstedgrotesk/SchibstedGrotesk%5Bwght%5D.ttf",
        "6ceeadf6be8e1fd7687011c7fa38ed0edd1abe967a0b73d97caec183552e823d",
        [],
    ),
    "jetbrains-mono": (
        "jetbrainsmono/JetBrainsMono%5Bwght%5D.ttf",
        "48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda",
        ["wght=400:800"],
    ),
}

# Coverage *requested*. What each face ends up carrying is pinned independently in
# tool/font_coverage.txt and asserted by --verify, so editing anything below narrows a font
# and fails the gate instead of moving the goalposts.
# LATIN/LATIN_EXT are the Google Fonts subset definitions; LATIN is widened with
# the combining marks, the four arrows the themes render and U+0102, all of which Google's
# `latin` omits. Both are a request shared by all eight families: a codepoint the family
# does not draw upstream is simply not emitted, so what a face ends up carrying is a subset
# of what was asked for. Lattice's `unicode-range` descriptors are therefore written from
# the built cmaps, not from these constants (see themes/lattice/VENDORED.md).
LATIN = (
    "U+0000-00FF,U+0102,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,"
    "U+0300-0304,U+0308-0309,U+0323,U+0329,U+2000-206F,U+20AC,U+2122,"
    "U+2190-2193,U+2212,U+2215,U+FEFF,U+FFFD"
)
LATIN_EXT = (
    "U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+0304,U+0308,"
    "U+0329,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,"
    "U+2113,U+2C60-2C7F,U+A720-A7FF"
)
# Symbols beyond the two subset definitions that a theme's own layouts, data files, example
# content or SASS `content:` properties emit, split by who draws them so a face is never
# asked for a glyph its designer did not draw. Schibsted Grotesk draws the arrow block and
# none of the geometric marks; asking it for the marks emitted nothing while reading as
# coverage. U+2016/U+2024 were also requested here and are already inside LATIN's
# U+2000-206F, so they never added anything.
ARROWS = "U+2194-2199"                          # Meadow's example feature icons set U+2197.
MARKS = "U+21E7,U+25C7,U+25CE-25CF,U+26A0-26A1"  # Mono-only; see themes/meadow/VENDORED.md.

# theme, output stem, family, requested unicodes
OUTPUTS = [
    ("lattice", "fraunces-latin", "fraunces", LATIN),
    ("lattice", "fraunces-latin-ext", "fraunces", LATIN_EXT),
    ("lattice", "fraunces-italic-latin", "fraunces-italic", LATIN),
    ("lattice", "instrument-sans-latin", "instrument-sans", LATIN),
    ("lattice", "instrument-sans-latin-ext", "instrument-sans", LATIN_EXT),
    ("lattice", "spline-sans-mono-latin", "spline-sans-mono", LATIN),
    ("lattice", "spline-sans-mono-latin-ext", "spline-sans-mono", LATIN_EXT),
    ("folio", "eb-garamond-latin", "eb-garamond", LATIN),
    ("meadow", "bricolage-grotesque-latin", "bricolage-grotesque", LATIN),
    ("meadow", "schibsted-grotesk-latin", "schibsted-grotesk", f"{LATIN},{ARROWS}"),
    ("meadow", "jetbrains-mono-latin", "jetbrains-mono", f"{LATIN},{ARROWS},{MARKS}"),
]

SUBSET_FLAGS = [
    "--flavor=woff2",
    "--no-hinting",
    "--name-IDs=*",            # keeps the OFL notice (13/14) and the fvar instance names
    "--layout-features+=pnum,tnum",
    "--no-recalc-timestamp",   # without this every run produces different bytes
]

REPO = Path(__file__).resolve().parent.parent
COVERAGE = Path(__file__).resolve().parent / "font_coverage.txt"
FONTS_GLOB = "themes/*/static/fonts/*.woff2"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def key_of(path: Path) -> str:
    """`themes/meadow/static/fonts/x.woff2` -> `meadow/x`, the key OUTPUTS and the pin use."""
    return f"{path.parents[2].name}/{path.stem}"


def cmap(path: Path) -> set[int]:
    """Codepoints the built face actually draws, read back out of the file."""
    with TTFont(path) as font:
        return set(font.getBestCmap())


def format_range(codepoints: set[int]) -> str:
    """`U+XXXX`/`U+XXXX-YYYY` tokens, the notation the pin and CSS `unicode-range` share."""
    ordered = sorted(codepoints)
    tokens = []
    index = 0
    while index < len(ordered):
        end = index
        while end + 1 < len(ordered) and ordered[end + 1] == ordered[end] + 1:
            end += 1
        start, stop = ordered[index], ordered[end]
        tokens.append(f"U+{start:04X}" if start == stop else f"U+{start:04X}-{stop:04X}")
        index = end + 1
    return ", ".join(tokens)


def format_block(key: str, codepoints: set[int]) -> str:
    """One face as it is written in the pin, so a deliberate change is paste-and-review."""
    tokens = format_range(codepoints).split(", ")
    lines = [", ".join(tokens[i:i + 6]) for i in range(0, len(tokens), 6)]
    return "\n".join([f"{key}:", *(f"  {line}" for line in lines)])


def load_coverage() -> dict[str, set[int]]:
    """The pinned per-face coverage. Hand-maintained: nothing here ever writes this file."""
    pinned: dict[str, set[int]] = {}
    current: set[int] | None = None
    for number, raw in enumerate(COVERAGE.read_text().splitlines(), start=1):
        line = raw.split("#")[0].rstrip()
        if not line.strip():
            continue
        if not line[0].isspace():
            if not line.endswith(":"):
                raise SystemExit(f"{COVERAGE.name}:{number}: expected '<theme>/<stem>:'")
            current = pinned.setdefault(line[:-1], set())
            continue
        if current is None:
            raise SystemExit(f"{COVERAGE.name}:{number}: codepoints before any face")
        for token in line.split(","):
            token = token.strip()
            bounds = [part.strip() for part in token.split("-")]
            try:
                start = int(bounds[0].removeprefix("U+"), 16)
                stop = int(bounds[-1].removeprefix("U+"), 16)
            except ValueError:
                raise SystemExit(f"{COVERAGE.name}:{number}: bad token {token!r}") from None
            current.update(range(start, stop + 1))
    return pinned


def unlisted() -> list[Path]:
    """Vendored faces on disk that OUTPUTS does not name, and so nothing above verifies."""
    listed = {f"{theme}/{stem}" for theme, stem, _, _ in OUTPUTS}
    return sorted(path for path in REPO.glob(FONTS_GLOB) if key_of(path) not in listed)


def fetch(cache: Path, family: str) -> Path:
    rel, digest, _ = FAMILIES[family]
    dest = cache / f"{family}.ttf"
    # The gate runs on every push (.github/workflows/ci.yml, job `fonts`), so a single
    # dropped connection would turn a green branch red for a reason unrelated to the commit.
    for attempt in range(3):
        if dest.exists():
            break
        try:
            urllib.request.urlretrieve(f"{RAW}/{rel}", dest)
        except OSError:
            dest.unlink(missing_ok=True)
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)
    got = sha256(dest)
    if got != digest:
        raise SystemExit(f"{family}: upstream SHA-256 {got} != recorded {digest}")
    return dest


def build(out_dir: Path, cache: Path) -> dict[str, Path]:
    built: dict[str, Path] = {}
    instanced: dict[str, Path] = {}
    for theme, stem, family, unicodes in OUTPUTS:
        if family not in instanced:
            src = fetch(cache, family)
            inst = cache / f"{family}-instanced.ttf"
            subprocess.run(
                [sys.executable, "-m", "fontTools.varLib.instancer",
                 "-o", str(inst), "--no-recalc-timestamp", str(src), *FAMILIES[family][2]],
                check=True, capture_output=True,
            )
            instanced[family] = inst
        dest = out_dir / theme / stem
        dest.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [sys.executable, "-m", "fontTools.subset", str(instanced[family]),
             f"--output-file={dest}.woff2", f"--unicodes={unicodes}", *SUBSET_FLAGS],
            check=True, capture_output=True,
        )
        built[f"{theme}/{stem}"] = Path(f"{dest}.woff2")
    return built


def shipped(key: str) -> Path:
    theme, stem = key.split("/")
    return REPO / "themes" / theme / "static" / "fonts" / f"{stem}.woff2"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--write", action="store_true", help="overwrite the vendored files")
    ap.add_argument("--verify", action="store_true", help="compare against the vendored files")
    args = ap.parse_args()
    if args.write == args.verify:
        ap.error("pass exactly one of --write / --verify")

    # Cheap and offline, so it runs before the downloads: a face on disk that OUTPUTS does
    # not name is neither built nor compared, and would otherwise never be mentioned at all.
    failures = 0
    for stray in unlisted():
        failures += 1
        print(f"UNLISTED {stray.relative_to(REPO)} is vendored but not in OUTPUTS")

    pinned = load_coverage()

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        cache = tmp_path / "upstream"
        cache.mkdir()
        built = build(tmp_path / "out", cache)

        totals: dict[str, int] = {}
        for key, path in built.items():
            target = shipped(key)
            digest = sha256(path)
            totals[key.split("/")[0]] = totals.get(key.split("/")[0], 0) + path.stat().st_size
            if args.write:
                shutil.copyfile(path, target)
                print(f"wrote  {key:<40} {path.stat().st_size:>7} B  {digest}")
            else:
                ok = target.exists() and sha256(target) == digest
                failures += not ok
                print(f"{'ok    ' if ok else 'DRIFT '} {key:<40} {path.stat().st_size:>7} B  {digest}")

        # The bytes above are only ever compared against the recipe that made them. This is
        # the independent half: what the face actually draws, against a pin nothing here
        # writes. --write reports rather than fails, so a deliberate widening can be built
        # first and pasted second; --verify is where the pin has to already agree.
        drifted = 0
        for key in sorted(set(pinned) | set(built)):
            actual = cmap(built[key]) if key in built else set()
            expected = pinned.get(key, set())
            if actual == expected:
                continue
            drifted += 1
            if key not in built:
                print(f"COVER  {key:<40} pinned in {COVERAGE.name} but nothing builds it")
                continue
            lost, gained = expected - actual, actual - expected
            what = "not pinned" if not expected else f"lost {format_range(lost) or '-'}"
            print(f"COVER  {key:<40} {what}; gained {format_range(gained) or '-'}")
            print(f"       pin it in {COVERAGE.name} as:\n{format_block(key, actual)}")
        failures += 0 if args.write else drifted

        for theme, total in sorted(totals.items()):
            print(f"total  {theme:<40} {total:>7} B")
        return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
