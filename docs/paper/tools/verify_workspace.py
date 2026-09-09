#!/usr/bin/env python3
"""Verify curated writing artifacts and local source references without EDA/GPU tools."""

import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parents[3]
MANIFESTS = (
    "TSS_ICCAD/manifest.json",
    "docs/paper/review_history/iccad/manifest.json",
    "docs/paper/assets/manifest.json",
    "docs/paper/evidence/manifest.json",
    "hardware_sim/reference/tss_delivery_20260909/manifest.json",
    "hardware_sim/reference/layout_20260909/manifest.json",
    "hardware_sim/reference/rebuttal_gpu_20260909/manifest.json",
)
EDITORIAL_FILES = (
    "README.md",
    "docs/README.md",
    "TSS_ICCAD/README.md",
    "hardware_sim/docs/README.md",
    "hardware_sim/reference/README.md",
    "hardware_sim/docs/reference/tss_delivery_audit.md",
    "hardware_sim/reference/tss_delivery_20260909/README.md",
    "hardware_sim/reference/layout_20260909/README.md",
    "hardware_sim/reference/rebuttal_gpu_20260909/README.md",
    "docs/paper/review_history/iccad/README.md",
    "docs/paper/assets/README.md",
    "docs/paper/evidence/README.md",
)


def fingerprint(path, compressed=False):
    digest = hashlib.sha256()
    size = 0
    opener = gzip.open if compressed else open
    with opener(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            size += len(chunk)
            digest.update(chunk)
    return size, digest.hexdigest()


def verify_manifests(check_sources, errors):
    count = stored_bytes = 0
    seen = set()
    for name in MANIFESTS:
        manifest = json.loads((ROOT / name).read_text())
        entries = manifest.get("entries", manifest.get("files", []))
        if not entries:
            errors.append(f"{name}: empty manifest")
        for entry in entries:
            if entry.get("disposition") == "excluded":
                continue
            destination = entry["destination_path"]
            path = ROOT / destination
            if path.resolve() == ROOT or ROOT not in path.resolve().parents:
                errors.append(f"{name}: destination escapes repository: {destination}")
                continue
            if destination in seen:
                errors.append(f"Duplicate manifest destination: {destination}")
            seen.add(destination)
            encoding = entry.get("encoding", "identity")
            if encoding not in ("identity", "gzip"):
                errors.append(f"{destination}: unknown encoding {encoding}")
                continue
            expected = (entry["size_bytes"], entry["sha256"])
            stored = (entry.get("stored_size_bytes", expected[0]),
                      entry.get("stored_sha256", expected[1]))
            try:
                actual = fingerprint(path)
                if actual != stored:
                    errors.append(f"Stored checksum/size mismatch: {destination}")
                decoded = fingerprint(path, compressed=True) if encoding == "gzip" else actual
                if decoded != expected:
                    errors.append(f"Original payload checksum/size mismatch: {destination}")
                if check_sources:
                    source_root = entry.get("source_root", manifest.get("source_root"))
                    if source_root is None:
                        errors.append(f"{destination}: missing source root")
                    elif fingerprint(ROOT / source_root / entry["source_path"]) != expected:
                        errors.append(f"Source checksum/size mismatch: {destination}")
                count += 1
                stored_bytes += actual[0]
            except (OSError, EOFError) as exc:
                errors.append(f"{destination}: {exc}")
    return count, stored_bytes


def verify_manuscript(errors):
    manuscript = ROOT / "TSS_ICCAD"
    tex = (manuscript / "sample-sigconf.tex").read_text()
    # A source-level check for this manuscript's simple command forms; not a TeX parser.
    tex = re.sub(r"(?<!\\)%[^\n]*", "", tex)
    graphics = re.findall(r"\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}", tex)
    for graphic in graphics:
        if not (manuscript / graphic).is_file():
            errors.append(f"Missing manuscript graphic: {graphic}")
    labels = re.findall(r"\\label\{([^}]+)\}", tex)
    refs = set(re.findall(r"\\(?:ref|eqref|autoref)\{([^}]+)\}", tex))
    for label in sorted(refs - set(labels)):
        errors.append(f"Undefined manuscript reference: {label}")
    for label in sorted({label for label in labels if labels.count(label) > 1}):
        errors.append(f"Duplicate manuscript label: {label}")
    keys = set()
    for stem in re.findall(r"\\bibliography\{([^}]+)\}", tex):
        for bibliography in stem.split(","):
            path = manuscript / (bibliography.strip() + ".bib")
            if not path.is_file():
                errors.append(f"Missing bibliography: {path}")
                continue
            keys.update(re.findall(r"@\w+\s*\{\s*([^,]+),", path.read_text()))
    cites = {key.strip() for block in re.findall(
        r"\\cite\w*(?:\[[^\]]*\])*\{([^}]+)\}", tex) for key in block.split(",")}
    for key in sorted(cites - keys):
        errors.append(f"Missing bibliography key: {key}")
    return len(graphics), len(cites)


def verify_editorial_links(errors):
    # Historical snapshots retain original paths; check only maintained editorial files.
    files = {ROOT / name for name in EDITORIAL_FILES}
    files.update((ROOT / "docs/paper").glob("*.md"))
    count = 0
    for path in sorted(files):
        if not path.is_file():
            errors.append(f"Missing editorial file: {path.relative_to(ROOT)}")
            continue
        for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", path.read_text()):
            if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
                continue
            target = unquote(target.split("#", 1)[0].strip("<>"))
            if target and not (path.parent / target).exists():
                errors.append(f"Broken link in {path.relative_to(ROOT)}: {target}")
            count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-sources", action="store_true",
                        help="Also compare payloads with the original sibling source files.")
    args = parser.parse_args()
    errors = []
    try:
        count, size = verify_manifests(args.check_sources, errors)
        graphics, cites = verify_manuscript(errors)
        links = verify_editorial_links(errors)
    except (OSError, KeyError, ValueError) as exc:
        errors.append(str(exc))
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print(f"PASS: {len(MANIFESTS)} manifests; {count} payloads; {size:,} stored bytes.")
    print(f"PASS: {graphics} manuscript graphics; {cites} cited keys; {links} editorial links.")
    if args.check_sources:
        print("PASS: all preserved payloads match their source files.")
    print("LaTeX compilation and model/hardware execution are outside this check.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
