# JOSEPH — THE MAN HE HATED
## Full 3D Browser Game Prototype

This package is a playable third-person 3D narrative game built around the supplied Joseph storyline.

### Story basis
The game follows the supplied structure from the Prologue through the Final Act: Joseph is laid off by OOO Corporation, enters politics, rises to the presidency, compromises his ideals, uses a shadow network, becomes tied to organized crime, and finally realizes that he became the system he hated.

Source: Joseph_The_Man_He_Hated.txt

### Features
- Real-time 3D city rendered with Three.js
- Third-person Joseph character
- Large procedural city with roads, buildings, trees and landmarks
- OOO Corporation, People's Movement HQ, Parliament, Presidential Palace and warehouse
- 9 narrative chapters
- Dialogue system
- Moral/strategic choice system
- Money/progression
- Minimap
- Keyboard + touch controls
- Dynamic lighting, fog and shadows
- Final ending screen
- No backend required

### Controls
Desktop:
- WASD — move
- Shift — sprint
- Mouse drag — camera
- E — interact / advance dialogue
- M — map

Mobile:
- Left stick — move
- RUN — sprint
- E — interact
- MAP — map

### Run
Open `index.html` in a modern browser. Because ES modules/CDN loading can be restricted by some browsers when opening local files, the most reliable method is a local server:

Python:
`python -m http.server 8000`

Then open:
`http://localhost:8000`

The game loads Three.js from jsDelivr, so an internet connection is needed unless you replace the CDN imports with a local Three.js build.

### Expansion path
This is a complete playable vertical-slice/prototype, not a AAA production. To turn it into a large commercial-quality game, replace procedural geometry with authored GLB/GLTF characters, vehicles, interiors, animation sets, voice acting, music, VFX, missions, save/load, combat/stealth systems and optimized streaming/chunking.


## Automatic GitHub workflow
A ready-to-use GitHub Actions workflow is included at `.github/workflows/deploy.yml`.
Every push to `main` validates and packages the game, then deploys it automatically to GitHub Pages.

See `GITHUB_WORKFLOW.md` for the one-time Pages setup.

## Art pipeline
See `assets/GLB_ASSET_MANIFEST.md`. The game can automatically load supplied GLBs while retaining procedural fallbacks, so we can replace the placeholder art incrementally instead of rebuilding the whole game each time.
