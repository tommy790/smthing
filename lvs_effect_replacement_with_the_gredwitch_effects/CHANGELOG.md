# Changelog

## v1.0.0 — Final

### Rewrite
- Rebuilt the addon as a clean modular structure: configuration, particle
  spawning, muzzle attachment resolution, muzzle flashes, barrel smoke,
  tracers, impacts, trails, and a central effect bridge.
- All effect mappings (tracer → color/caliber/muzzle/smoke, explosions,
  impacts, water, trails) live in one config file for easy tuning.

### Muzzle flashes & attachments
- Muzzle-mounted particles attach to the weapon with `PATTACH_POINT_FOLLOW`
  and follow the barrel as it traverses, elevates, recoils or moves with the
  vehicle.
- Attachment resolution order: LVS EffectData attachment id (validated) →
  LVS muzzle attachment name → named muzzle/barrel candidates nearest to the
  muzzle position → strict position match → world fallback only when no
  usable attachment exists.
- Multi-barrel vehicles (twin autocannons, multiple cannons, coax MGs)
  resolve each shot's correct barrel.
- Gred artillery muzzle blasts are spawned at the muzzle world position,
  oriented by the bullet direction, so they never spray sideways on models
  with mis-rotated attachments.

### Tracers
- Tracers use the proven server-relay mechanism: the server sends gred's own
  `gred_net_createtracer` message after each shot, and the Gredwitch base
  renders the beam — the same path gred's tanks use.
- Tracer messages are sent only to players who can see the shot (PVS),
  keeping multiplayer bandwidth low with many vehicles firing.

### Impacts
- Autocannon AP impacts use a small surface profile (smaller than HE).
- Cannon (40mm+) AP impacts use the dedicated AP spark.
- HE impacts use caliber-appropriate explosions (`gred_20mm` / `gred_40mm`).
- Impacts are oriented with the correct surface rotation.
- Duplicate-impact suppression: an autocannon's splash explosion suppresses
  the duplicate AP impact at the same spot.

### Smoke
- Cannons produce both the VJ narrow smoke column and muzzle smoke together.
- Replaced smoke fades out naturally instead of being deleted instantly.
- Rapid fire is throttled so smoke systems don't stack.
- Defence smoke canisters produce a persistent, continuous smoke cloud while
  active, then fade out after.

### Multiplayer & performance
- All visual effects are client-side; the server only relays a lightweight
  visual tracer message and never touches LVS damage, ballistics, physics or
  networking.
- Attachment data is cached per vehicle and invalidated when the model
  changes.
- Water and dust effects are position-throttled so they never stack into a
  screen-covering mess.

### LVS compatibility
- LVS damage, ballistics, projectile physics, weapon logic, vehicle physics,
  networking and firing mechanics are untouched.
- When a replacement fails or declines, the original LVS effect plays
  instead — LVS visuals are never broken.
