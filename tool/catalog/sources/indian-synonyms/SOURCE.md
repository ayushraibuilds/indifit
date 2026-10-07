# Hinglish and regional synonyms

| | |
|---|---|
| **File** | `backend/data/indian_synonyms.json` (80 terms mapped onto 35 canonical terms) |
| **URL** | In this repository (no external source) |
| **Licence** | Proprietary (IndiFit's own word list) |
| **Date** | Last changed 2026-09-24; read by `build.py` on every build |

The search proxy used these as query rewrites ("arhar" → "toor"). Packs
carry them as food aliases instead (`overlays/0006_aliases.yaml` says how),
so local search can use them without a server. The file stays where it is
while the backend still reads it.
