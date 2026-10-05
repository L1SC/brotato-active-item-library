"""Build the installable Active Item Library ZIP."""

from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import json


ROOT = Path(__file__).resolve().parents[1]
MOD_ID = "L1SC-ActiveItemLibrary"
SOURCE = ROOT / "mods-unpacked" / MOD_ID
OUTPUT = ROOT / "dist" / f"{MOD_ID}.zip"


def main() -> None:
    manifest = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
    if manifest["namespace"] + "-" + manifest["name"] != MOD_ID:
        raise SystemExit("manifest ID and source folder differ")
    files = sorted(p for p in SOURCE.rglob("*") if p.is_file())
    if not files or not (SOURCE / "mod_main.gd").is_file():
        raise SystemExit("incomplete mod source")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(OUTPUT, "w", ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, path.relative_to(ROOT).as_posix())
    print(OUTPUT)


if __name__ == "__main__":
    main()
