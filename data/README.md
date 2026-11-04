Stat berbasis data. buildings.json sudah dipakai (lewat autoload DataDB).
Nanti: units.json, waves.json.

CATATAN EXPORT: tambahkan "*.json" pada Export > Resources > Filters to export
non-resource files, kalau tidak buildings.json tidak ikut ke build rilis.


Barracks: unlocked by Military Drill. Provides four local soldier garrison slots and reuses the existing Outpost guard leash/combat behavior. Barracks assignments are stored as additive v17 guard_garrison links; older Outpost guard_outpost records remain valid.
