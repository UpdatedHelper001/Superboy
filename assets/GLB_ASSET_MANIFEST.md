# GLB ART ASSET MANIFEST

Drop GLB/GLTF files into `assets/glb/` using these exact names. The game will try to load them automatically and keep procedural placeholders when an asset is absent.

## Priority 1 — Character
1. `joseph.glb` — main playable character, rigged humanoid, idle/walk/run animations.
2. `civilian.glb` — generic civilian NPC.
3. `politician.glb` — politician/adviser NPC.
4. `mafia_boss.glb` — mafia/fixer NPC.
5. `police.glb` — police/security NPC.

## Priority 2 — Vehicles
6. `sedan.glb`
7. `suv.glb`
8. `police_car.glb`

## Priority 3 — Major locations
9. `city_building.glb` — modular high/medium-rise building.
10. `office_interior.glb` — OOO office / government office interior.
11. `presidential_palace.glb`
12. `parliament.glb`
13. `warehouse.glb`

## Priority 4 — Street environment
14. `street_props.glb` — lamps, benches, bins, signs, barriers, traffic lights.
15. Road/sidewalk modular pieces.
16. Trees/vegetation.
17. Props: desks, phones, files, campaign posters, cameras, microphones.

## Priority 5 — Animation/VFX/audio (later)
- Joseph movement set
- NPC crowd loops
- Handshake / conversation animations
- Vehicle wheel/door animations
- Rain/fog/smoke/impact VFX
- UI icons
- Footsteps, traffic, crowd, office and city ambience

### Important
Prefer game-ready GLBs with sensible origins, real-world scale, embedded or relative textures, and low/medium/high LODs. For characters, include a consistent humanoid skeleton and animation clips.
