#!/usr/bin/env python3
"""Builds CertificationsTracker/Resources/Localizable.xcstrings from scripts/strings.json.

strings.json maps each key to its English and Spanish text. Positional arguments
(%1$@) are filled by the L() helper in App/L10n.swift. Run it after editing strings.json:

    python3 scripts/build_xcstrings.py
"""
import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
source = json.loads((here / "strings.json").read_text(encoding="utf-8"))
out = here.parent / "CertificationsTracker" / "Resources" / "Localizable.xcstrings"

strings = {
    key: {
        "extractionState": "manual",
        "localizations": {
            lang: {"stringUnit": {"state": "translated", "value": value[lang]}}
            for lang in ("en", "es")
        },
    }
    for key, value in sorted(source.items())
}
catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
out.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(f"wrote {len(strings)} strings to {out}")
