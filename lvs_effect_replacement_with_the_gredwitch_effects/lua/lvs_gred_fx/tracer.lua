--[[---------------------------------------------------------------------------
    LVS → Gredwitch FX : tracer system (client-side)

    Replaces the LVS tracer visuals with Gredwitch beam particles
    (gred_tracers_<color>_<caliber>) while leaving LVS projectile behaviour
    completely untouched:

      * the LVS bullet is simulated by LVS on the client; this module simply
        renders a beam from the muzzle (control point 0) to the bullet's live
        position (control point 1), updated every frame,
      * when the bullet dies the beam stops — exactly when LVS says the tracer
        is over (the override wrapper also runs the original LVS tracer Think
        silently so the lvs_bullet_impact_ap trigger keeps firing at LVS's
        exact timing; see bridge.lua / cl_lvs_gred_fx_override.lua),
      * each shot is recorded (entity, muzzle position, tracer name, mapping)
        so the muzzle-flash system can pair the correct PCF and the impact
        system can pick the correct caliber — no global util.Effect hook is
        needed.

    Duplicate LVS/Gredwitch tracers are impossible: the LVS tracer effect is
    registered through this addon's override wrapper, so either the gred beam
    plays (and the original LVS beam visuals are suppressed) or the wrapper
    falls back to the original LVS tracer — never both.
-----------------------------------------------------------------------------]]

if not CLIENT then return end

local cfg = LVS_GRED_FX.Config
local Debug = LVS_GRED_FX.Debug

LVS_GRED_FX_TRACER = LVS_GRED_FX_TRACER or {}

-- Recent shots per entity (weak keys). Bounded per entity; used to pair
-- muzzle flashes and to infer caliber for impacts.
local RECENT = setmetatable({}, { __mode = "k" })
local RECENT_MAX_PER_ENT = 8
local RECENT_WINDOW = 0.15

-- Last shot per entity, no expiry — cheap caliber inference for impacts.
local LAST_SHOT = setmetatable({}, { __mode = "k" })

-- Last caliber fired by ANY entity. LVS fires lvs_bullet_impact / AP impact
-- with the HIT surface as the entity (not the shooter), so the per-entity
-- lookup cannot find the caliber there. This global fallback restores the
-- old addon's behavior: contextless impacts still get the caliber of the
-- most recent shot.
local LAST_CALIBER = "20mm"

local function getList(ent)
    local list = RECENT[ent]
    if not list then
        list = {}
        RECENT[ent] = list
    end
    return list
end

-- Record a shot so the muzzle flash and impact systems can pair with it.
function LVS_GRED_FX_TRACER.NoteShot(ent, name, srcPos, map)
    if not IsValid(ent) then return end

    local rec = {
        time   = CurTime(),
        name   = name,
        srcPos = srcPos,
        map    = map,
    }

    if map and map.caliber then
        LAST_CALIBER = map.caliber
    end

    local list = getList(ent)
    list[#list + 1] = rec
    if #list > RECENT_MAX_PER_ENT then
        table.remove(list, 1)
    end

    LAST_SHOT[ent] = rec

    if cfg.DebugEnabled() then
        Debug("tracer recorded:", name, "ent:", ent:GetClass(),
            "caliber:", map and map.caliber or "?", "src:", tostring(srcPos))
    end
end

-- Find the most recent shot for `ent` whose source position is close to
-- `muzzlePos` (within 256 units). Passing a nil muzzlePos returns the newest
-- recent record for the entity.
function LVS_GRED_FX_TRACER.RecentShot(ent, muzzlePos)
    if not IsValid(ent) then return nil end

    local list = RECENT[ent]
    if not list then return nil end

    local now = CurTime()
    local best, bestD = nil, nil

    for i = #list, 1, -1 do
        local rec = list[i]
        if not rec or (now - rec.time) > RECENT_WINDOW then
            table.remove(list, i)
        else
            local d
            local matched = false
            if isvector(muzzlePos) and isvector(rec.srcPos) then
                d = rec.srcPos:DistToSqr(muzzlePos)
                matched = d <= 65536 -- 256 units association
            else
                d = i
                matched = true
            end
            if matched and (not bestD or d < bestD) then
                best, bestD = rec, d
            end
        end
    end

    return best
end

-- Caliber string for impact effects, inferred from the last shot of `ent`,
-- falling back to the most recent shot fired by any entity.
function LVS_GRED_FX_TRACER.CaliberFor(ent)
    if IsValid(ent) then
        local rec = LAST_SHOT[ent]
        if rec and rec.map and rec.map.caliber then
            return rec.map.caliber
        end
        -- Fall back to the recent list (entity may have changed).
        rec = LVS_GRED_FX_TRACER.RecentShot(ent, nil)
        if rec and rec.map and rec.map.caliber then
            return rec.map.caliber
        end
    end
    return LAST_CALIBER
end

local function getBullet(id)
    if LVS and LVS.GetBullet then
        return LVS:GetBullet(id)
    end
    return nil
end

--[[---------------------------------------------------------------------------
    Tracer effect lifecycle. `data` is the LVS tracer EffectData:
      Origin        = bullet.Src (world muzzle position)
      Normal        = bullet.Dir
      MaterialIndex = LVS bullet index
-----------------------------------------------------------------------------]]
-- Fire a gred_particle_tracer beam segment from muzzle to a target position.
-- Returns true when the effect was dispatched.
local function TracerFire(self, fromPos, toPos)
    local map = self._map or cfg.TracerDefaults
    local calIndex = cfg.CaliberIndex[map.caliber or "20mm"] or 3
    local colIndex = cfg.ColorIndex[map.color or "white"] or 3

    -- The gred_particle_tracer effect resolves gred.Particles internally;
    -- we only need the gred base to be present at all (like the old addon's
    -- gred.Calibre check).
    if not gred then return false end

    local effectdata = EffectData()
    effectdata:SetOrigin(fromPos)
    effectdata:SetFlags(calIndex)       -- gred caliber
    effectdata:SetMaterialIndex(colIndex) -- gred tracer color
    effectdata:SetStart(toPos)          -- beam endpoint

    local ok = pcall(util.Effect, "gred_particle_tracer", effectdata)
    return ok == true
end

-- Reference so Init can call TracerFire before Think exists at runtime.
local LVS_GRED_FX_TracerFire = TracerFire

function LVS_GRED_FX_TRACER.Init(name, self, data)
    self._gmode = "tracer"

    local bulletID = 0
    if data.GetMaterialIndex then
        bulletID = data:GetMaterialIndex() or 0
    end
    self._bulletID = bulletID

    local bullet = getBullet(bulletID)

    local srcPos = isvector(data:GetOrigin()) and data:GetOrigin() or nil
    local dir    = isvector(data:GetNormal()) and data:GetNormal() or nil

    if not srcPos and bullet then
        srcPos = bullet.Src
    end
    if not dir and bullet then
        dir = bullet.Dir
    end

    local ent = bullet and bullet.Entity
    if not IsValid(ent) then
        ent = data.GetEntity and data:GetEntity() or nil
    end

    local map = cfg.Tracers[name] or cfg.TracerDefaults

    -- Record the shot for muzzle-flash pairing and impact caliber inference.
    if IsValid(ent) and isvector(srcPos) then
        LVS_GRED_FX_TRACER.NoteShot(ent, name, srcPos, map)
    end

    if not isvector(srcPos) or not isvector(dir) then
        -- No usable geometry — declare handled (original tracer suppressed);
        -- the wrapper's silent original Think still drives lifetime/AP impact.
        return true
    end

    self._srcPos = srcPos

    self._pcf = "gred_tracers_" .. (map.color or "white") .. "_" .. (map.caliber or "20mm")
    self._map = map
    self._dir = dir
    self._die = CurTime() + cfg.TracerLifeCap
    self._nextFire = 0

    -- Render via gred's OWN gred_particle_tracer effect (util.Effect), the
    -- exact mechanism gred's own tanks use — this renders wherever gred's
    -- tracers render, and is the same effect class we know works in-game.
    local bulletPos = bullet and bullet.GetPos and bullet:GetPos() or nil
    local initEnd = isvector(bulletPos) and bulletPos or (srcPos + dir * 1200)

    if not LVS_GRED_FX_TracerFire(self, srcPos, initEnd) then
        -- Effect not available; the override wrapper falls back to the
        -- original LVS tracer (single tracer either way).
        return false
    end

    return true
end

function LVS_GRED_FX_TRACER.Think(self)
    if CurTime() > (self._die or 0) then
        LVS_GRED_FX_TRACER.Stop(self)
        return false
    end

    local bullet = getBullet(self._bulletID)
    local endpos = bullet and bullet.GetPos and bullet:GetPos() or nil

    if not isvector(endpos) then
        -- Bullet is gone; the wrapper's silent original Think will fire the
        -- AP impact and tell us to stop. Stop the beam now.
        LVS_GRED_FX_TRACER.Stop(self)
        return false
    end

    -- Re-fire a beam segment from the muzzle to the live bullet position on
    -- the update interval. Because the endpoint tracks the LIVE LVS bullet
    -- (which includes gravity drop when ballistics are on) and moves at the
    -- projectile's real speed, the tracer follows the ballistic arc and the
    -- projectile velocity.
    if CurTime() >= (self._nextFire or 0) then
        self._nextFire = CurTime() + cfg.TracerUpdateInterval
        LVS_GRED_FX_TracerFire(self, self._srcPos, endpos)
    end

    return true
end

function LVS_GRED_FX_TRACER.Stop(self)
    -- Each gred_particle_tracer effect owns its own lifetime (it stops
    -- itself); nothing to clean up here.
end
