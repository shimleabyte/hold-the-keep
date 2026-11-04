Stat berbasis data. buildings.json sudah dipakai (lewat autoload DataDB).
Nanti: units.json, waves.json.

CATATAN EXPORT: tambahkan "*.json" pada Export > Resources > Filters to export
non-resource files, kalau tidak buildings.json tidak ikut ke build rilis.


Barracks: unlocked by Military Drill. Provides four local soldier garrison slots and reuses the existing Outpost guard leash/combat behavior. Barracks assignments are stored as additive v17 guard_garrison links; older Outpost guard_outpost records remain valid.


Archery Range: unlocked by Fletching. Provides two archer training workplaces. Archer is a persisted military specialization of the soldier role, so quotas, equipment, expeditions and garrison contracts remain soldier-compatible. Archers use ranged arrow attacks; losing the training workplace returns them to regular soldiers.
