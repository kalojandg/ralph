# rwclab board 8 research: a parametric character on the build plate (presets, races, face/body sliders)

Research notes, 22.11.2026 (web + the lab tree, read-only). NOT a board yet: board 8 gets its own recon of the lab
code once board 7 (the backend cut) is merged. Goal stated by the user: "give me a basic human", then customize like a
game character screen ("brows closer, more furrowed, cheekbones more prominent"), races beyond human (elf, dwarf, orc,
goblin...), hobby project (no licence constraint, nothing deployed, nothing to SprintRay's AWS).

## 1. Decision candidates (ranked)

1. **Reuse the Actors runtime (MIT) on MakeHuman/MPFB2 data (CC0).** https://github.com/ArndRosemeier/Actors
   - Monorepo, TypeScript 5.6, npm workspaces, packages `@actors/core` (renderer-free runtime: pack format, morph blending
     `base + Σ weight · target` on the CPU ~20 ms per update, normals, Catmull-Clark subdivision, skeleton + garment fitting,
     Web Worker evaluation), `@actors/human` (MakeHuman-style macro sliders, expressions, RACES), `@actors/three` (three.js
     adapter, `peerDependencies: three >= 0.180`, devDependency three 0.186.1 / @types/three 0.186.0), `@actors/generator`
     (`Character` class, editor UI, glTF export), `tools/import-makehuman` (`npm run import` = `tsx src/import.ts`, inputs =
     an MPFB2 checkout; produces the pack). All packages are `"private": true` (version 0.37.4) and NOT on npm -> consume as a
     git dependency / vendored copy of `packages/core`, `human`, `three` (MIT), or build the pack with their importer and
     write a small consumer of our own.
   - Pack format (docs/architecture.md): `manifest.json` (meshes, proxies, skeleton, skin, target index, species data),
     `base.bin` (base positions, render meshes split at UV seams with a map back to shape vertices, skin weights, garment
     bindings), `targets/*.bin` (one file per morph target, int16-quantized, sparse or dense, loaded on demand: the first
     load is a few MB instead of ~38 MB), `clips/`, `garments/*.bin`, `textures/`.
   - Races (`packages/human/src/races.ts`, `raceshape.ts`): `RaceId` = human, elf, dwarf, orc, halfling, goblin, sylvan,
     drakeborn, umbral, giantkin; a `RaceStyle` = random-generation weights (height, weight, muscle, skin, hair...) +
     fixed shaping: `targets: Record<string, number>` (bare MakeHuman target names, `%` = both sides, e.g. elf
     `{ "head-oval": 0.5, "%-cheek-bones-incr": 0.4, ... }`), `bones` (per bone group `{len, girth}`), `headScale`
     (capped `MAX_HEAD_SCALE = 1.1`), `earTip` 0..1.5 + `earSideways`, `face`/`body` feature maps -1..1; any two races mix
     (`RaceSettings {race, race2, mix, size, youth?}`); add-ons: horns, orc tusks, tails, beards. Export: glTF/GLB only
     (no STL - we add the STL bake; `STLExporter` already exists in the lab).
   - Licences: code MIT; assets mostly CC0 (hm08 base mesh, ~1000 morph targets, rig, skins, 34 face units, eyes,
     eyebrows, teeth, ~100 garments); 31 hairstyles + ~40 garments CC-BY (credit line in the editor); CMU mocap free.
     NOTICE-ASSETS.md: "No MakeHuman/MPFB code is used; the runtime is an independent implementation" (MakeHuman code is
     AGPL/GPL, never copied).
   - Why first: it IS the Hero-Forge-style customizer the user described, including the races and the face units, and it
     runs in the browser on top of three.js. Cost: three.js upgrade 0.125 -> >= 0.180 in the lab first; the Actors
     SkinnedMesh/dual-quaternion path and WebGPU bits are optional.
2. **Own thin engine on MPFB2 data** (the "index-preserving target engine" pattern of snowfall-character-creator,
   Apache-2.0): parse `base.obj` yourself (keep the original vertex order; three's OBJLoader re-indexes), parse `.target`
   lines `index x y z` into sparse deltas, `position = base + Σ w·delta` on the CPU, `computeVertexNormals()`; races =
   JSON recipes of target weights. Simpler, no rig/garments, but every race feature beyond MakeHuman targets (tusks,
   horns, ear tips) is ours to model. Fallback if Actors turns out too heavy to integrate.
3. **Pre-baked GLB with shape keys from Blender/MPFB2** (`GLTFLoader` + `morphTargetInfluences`): fastest demo, but the
   target set is frozen at export time and a few hundred morph targets in one GLB is heavy on the GPU path.

Not chosen: FLAME / SMPL-X (research-only licences, PCA parameters without human names, no fantasy), ICT-FaceKit
(MIT light model, 100 PCA face targets, head only), MetaHuman / Daz / Ready Player Me (platform-bound licences).

## 2. The MakeHuman / MPFB2 data (what a loader has to know)

- Repo https://github.com/makehumancommunity/mpfb2, data under `src/mpfb/data/`: `3dobjs/base.obj` (the hm08 base mesh,
  plain OBJ; body vertices 0-13379, then helper geometry: `mesh_metadata/basemesh_vertex_groups.json` has
  `"HelperGeometry": [[13380, 13605], [14598, 19149]]`, `"JointCubes": [[13606, 14597], [19150, 19157]]` plus `Left`/`Mid`
  ranges - body range 0-13379 is LIKELY, verify against the file), `mesh_metadata/hm08.mirror`, `hm08_config.json`,
  `basemesh_face_to_vertex_table.json.gz`, `basemesh_vertex_to_face_table.json.gz`, `proxy_corrective.json`.
- `targets/` = 25 folders + `target.json`: `arms asym breast buttocks cheek chin ears expression/units eyebrows eyes feet
  forehead genitals hands head hip legs macrodetails mouth neck nose pelvis stomach torso _images`. Files are
  `.target.gz`, named `<region>-<name>-<direction>`, left/right paired parts prefixed `l-`/`r-`. Examples:
  eyebrows (6): `eyebrows-angle-down|up`, `eyebrows-trans-backward|forward|down|up`; cheek (16): `l-cheek-bones-decr|incr`,
  `l-cheek-inner-decr|incr`, `l-cheek-trans-down|up`, `l-cheek-volume-decr|incr` (+ `r-`); nose (42): base, compression,
  curve concave/convex, flaring, greek, hump, nostrils angle/width, point, scale depth/horiz/vert, septumangle, trans,
  volume, width1-3; ears (44): flap, lobe, rot, scale(+depth/vert), shape pointed/round/square/triangle, trans, wing.
  Opposite pairs (one slider = two files, sign picks the file): `decr-incr`, `down-up`, `in-out`, `backward-forward`,
  `concave-convex`, `compress-uncompress`, `square-round`, `pointed-triangle`. Macro targets in `macrodetails/` (`macro.json`).
- `.target` line format (from `services/targetservice.py`): header `# This is a target file for MakeHuman` ... `# basemesh hm08`;
  skip blank lines and lines starting with `#` or `"`; data line `index x z -y` read as `index=int(p[0]), x=float(p[1]),
  y=-float(p[3]), z=float(p[2])` (Y/Z swapped, Y negated between file and internal axes); offsets scaled by the object's
  scale factor and added to the basis; `.gz` files are gunzipped UTF-8. Indices beyond the basis buffer (helpers deleted)
  are skipped.
- Licence: `LICENSE.ASSETS.md` = CC0 1.0 (assets), `LICENSE.CODE.md` separate (code GPL). Community asset packs are mixed
  CC0/CC-BY (elf ears targets on makehumancommunity.org are CC0: "Elf ears" by Joel Palmius, "Elf series: ears", "Elvs Elven Ears").
- MB-Lab (AGPL Blender add-on) has elves and a dwarf with pointed ears / special teeth: a second source of fantasy targets
  if MPFB2 community targets are not enough; orc tusks / horns do not exist as targets anywhere found: model them in
  Blender (MPFB2 "create target") or attach them as separate meshes at anchor vertices (cheaper, what Actors does).

## 3. The lab side: what board 8 will have to touch (facts from the tree, HEAD 7dc0d4a)

- three.js `^0.125.2` (`app/frontend/package.json:57`); `three-stl-loader` npm (`renderer.component.ts:109`), vendored
  `src/app/shared/libs/TransformControls.js` and `DRACO-loader.tool`, `STLExporter` (board 6 export), `THREE.Math.degToRad`
  (renderer.component.ts:1034,1050), no GLTFLoader/morph/skinned usage anywhere (`grep` found only BoxGeometry/Cylinder for
  the plate and axes). Loaders available in `node_modules/three/examples/jsm/loaders` (GLTF, DRACO, OBJ, STL).
- Upgrade path (three.js Migration Guide r125 -> r188, read 22.11.2026): `THREE.Math` -> `MathUtils` (r113, alias gone later);
  `BufferGeometry.merge` -> `BufferGeometryUtils.mergeGeometries` (r144/r151); `Raycaster.intersectObject(s)` recursive default
  true (r133); controls take `domElement` mandatory (r110), Pointer Events (r120), no `preventDefault`/`stopPropagation`
  (r127/r130); TransformControls derives from `Controls` with `scene.add(controls.getHelper())` (r169) and `connect()` needs an
  element (r175) -> replace the vendored copy by `three/addons/controls/TransformControls.js`; DRACO decoder path
  `examples/jsm/libs/draco/` (r148), `setDecoderConfig` deprecated (r185); `outputEncoding` -> `outputColorSpace`, `Texture.encoding`
  -> `colorSpace`, `ColorManagement.enabled` true by default (r152: colours of materials/lights shift - retune the plate/model
  colours); `physicallyCorrectLights` -> `useLegacyLights` (r150) -> gone (r155: lights ~ /PI brighter); WebGL1 removed (r163),
  `stencil` default false (r163); `examples/js` removed (r147), `build/three.min.js` removed (r161), imports `three/addons/...`;
  `material.morphTargets` flag removed (r131: morphing is automatic from the geometry); `Object3D.DefaultUp` -> `DEFAULT_UP`
  (r149); `Scene.autoUpdate` -> `Object3D.matrixWorldAutoUpdate` (r144). Upgrade in a few steps (r125 -> r150 -> r163 -> r186)
  with the fe-smoke/lab-ui gates between; `three-stl-loader` has no entries (check it still works or replace by
  `three/addons/loaders/STLLoader.js`).
- Integration shape (proposal): a "Character" panel in the renderer (presets: human/elf/dwarf/orc...; sliders grouped
  Face / Head / Body / Race; a "Place on plate" button). The character lives in a three.js group above the plate as a
  PREVIEW (like the upload preview of today); "Place on plate" bakes the current mesh (body vertices only, helpers
  stripped, scale to mm: MakeHuman units are decimetres, 1 unit = 100 mm - verify with `hm08_config.json`) into a binary STL
  through the existing STLExporter and feeds it through the existing upload path (`inbox.service` upload-link ->
  direct-upload -> POST platform-job) so the project is a normal project (gizmo, auto layout, export, previous projects).
  Pack hosting: the Actors pack (~40 MB) is served as static assets of the Angular app (`src/assets/character/`), loaded
  lazily, or built at `npm ci` time from an MPFB2 checkout by the Actors importer (keep the data OUT of git if > a few MB:
  a `scripts/fetch-character-pack.mjs` that downloads a release artefact is the honest option; decide in the board).
- Gates to add: a jest test for the target engine / pack loader on a tiny fixture (3 vertices, 2 targets), a lab-ui stage
  `character` (preset -> slider -> place on plate -> model in the list -> export STL byte count > the box), the existing
  fe-smoke/no-external-hosts (the pack must come from localhost).

## 4. Open questions for the user before the board

1. Actors as a dependency (git/vendored MIT packages, their pack format, their race recipes) vs own thin engine (option 2).
   Recommendation: Actors, after a 1-day spike that loads their pack in the lab's three.js scene (post-upgrade).
2. Which races at first: the Actors ten, or human + elf + dwarf + orc.
3. Hosting of the pack (git-ignored download vs committed assets).
4. Clothes/hair: Actors has garments (CC0/CC-BY); printing a figure usually wants a costume. Scope for a later board.

## 5. User decisions (22.11.2026 evening) and the spike results

Decisions: **Actors** as the engine; **all 10 races**; **clothes and hair in the panel from the catalog** (STL = body + garments, hair
excluded); the pack is **downloaded at bootstrap, git-ignored**; a spike first. Facts found the same evening: the lab is already on
Angular 22 / TypeScript 6 / jest 30 (`app/frontend/package.json`), so ONLY three.js must move (0.125 -> 0.186).

Spike (same evening, outside the lab, scratchpad `spike/`: `npm install three@0.186.1 https://github.com/ArndRosemeier/Actors/releases/download/v0.37.4/actors-generator-0.37.4.tgz`
pulled `@actors/core|human|three|generator` 0.37.4 in 13 s; `web/index.html` = import map (three -> `node_modules/three/build/three.module.js`,
`three/addons/` and `three/examples/jsm/` -> `node_modules/three/examples/jsm/`, `@actors/*` -> their `dist/index.js`); `server.mjs` static
server on 8787; `run.mjs` = playwright-core 1.65.1 driving the host Chrome headless with `--use-gl=angle --use-angle=swiftshader`):

- **Packs**: release asset `actors-packs-0.37.4.tar.gz` = 456.6 MB, contains `packs/{cat,chicken,cow,deer,dog,horse,human,squirrel}`;
  `tar -xzf ... packs/human` alone = **544 MB unpacked** (`base.bin`, `clips/`, `garments/`, `hair/`, `manifest.json` 973 KB, `targets/`,
  `textures/`). The lab's bootstrap script should download the archive once and extract only `packs/human` into a git-ignored folder
  served by the Angular dev server / dist (`src/assets/packs/human` or an `assets` glob in angular.json).
- **Load**: `Character.load({ pack: '/packs/human/manifest.json', renderer, clipLibraries: false })` = 2.1-2.4 s (first page load
  9.2 s total incl. the module graph); `setRace('elf')` + a shape = **98 ms**, `wear('knight')` (10 garments) = 485 ms. 8 meshes
  for a nude body (body, genitals-male, eyelashes, eyes, teeth, tongue, brows-eyebrow001, hair-long-waves), 18 dressed.
- **API confirmed** (d.ts in `node_modules/@actors/generator/dist/character.d.ts`, `catalog.d.ts`): `character.object` (THREE.Object3D to
  add to the scene), `character.actor.meshes: Map<name, SkinnedMesh>`, `character.catalog` (garments 226, outfits 95 presets incl. nude,
  underwear, casual, knight, viking, wizard, elven-gown, ranger..., hair 66, animations 84, details 234), `character.config` keys:
  race, race2, raceMix, raceSize, youth, body (HumanParams: gender, ageYears, muscle, weight, height...), details (raw MakeHuman
  modifiers, e.g. `l-cheek-bones-incr`), shape (named sliders: fat fitness shoulders chest waist belly hips bottom legs thighs arms
  neck head faceWidth fullness jaw cheekbones brow eyes nose noseWidth lips mouthWidth chin), skin/skinTone/skinColor, eyes/eyeColor/
  eyeGlow/pupil, skinPattern, hair/hairColor/beard/stubble, horns/hornSize/hornColor, tusks, tail/tailLength, brows, outfit[]/
  garmentColors, **anatomy** (false hides the genitals: set it for the lab), animation, expression, faceRig... `BODY_TYPES` ids: average
  slim athletic muscular curvy hourglass pear inverted stocky heavy lanky petite. Methods: `set(patch)`, `setRace(id)`, `wear(outfitId)`,
  `play(clip | null)` (null = bind pose), `seek(seconds)` + `paused = true` + `update(dt)` twice to freeze a pose from a clip,
  `randomize()`, `exportGlb()`, `dispose()`.
- **STL bake works**: own binary STL writer over every visible mesh except /hair|brow|lash|beard/ using `mesh.getVertexPosition(i, v)`
  (applies skinning + morphs in three >= r151) and `matrixWorld`. Elf nude: **117,108 triangles, 5.86 MB, y 0.000..1.889 m**; dwarf
  underwear: 115,912 tris, y 0..1.185 m; orc knight posed from `idle` t=1 s: 75,142 tris (garments hide body parts: the pack drops
  covered body triangles), y -0.043..1.871 (root motion of the clip: re-ground the bake to min y = 0 before upload). Units are
  **meters** (`manifest.units`), the lab is mm: scale x1000. No non-finite values. Files `spike/out/*.stl|png|json`.
- **Rendering caveat**: in SwiftShader (headless) the dressed orc's boots/greaves render partially; the STL contains them. Check on
  a real GPU: `node server.mjs` in the spike folder, then http://127.0.0.1:8787/?race=orc&outfit=knight&clip=idle&t=1 in Chrome.
  The lab-ui gate runs headless too, so the `character` stage must assert the STL bytes and the request flow, not pixels.
- One 404 on the first page load (favicon-class; the response listener saw none in the rerun). Pack files load lazily
  (targets per slider, garments per outfit) from the same origin: fine for `no-external-hosts`.

Board 8 shape (unchanged by the spike): wave 1 three.js upgrade (serial lane, gates between r150 / r163 / r186) in parallel with the
pack bootstrap script + jest fixtures; wave 2 a `CharacterService` wrapping `Character.load` in the renderer scene (metres -> mm group
scale, `anatomy: false`, `allow.races` = all 10); wave 3 the panel (race + mix, body type, shape sliders by group, details for the face,
outfit preset + hair, pose = clip + time); wave 4 bake STL (re-grounded, x1000) -> existing upload path -> project; lab-ui stage
`character`. Board 9: character config in the project metadata for re-editing; manifold union of garments.
