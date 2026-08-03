--[[---------------------------------------------------------------------------
    LVS → Gredwitch FX : tracer system (client-side)

    Replaces the LVS tracer visuals with the actual GREDWITCH TRACER PARTICLES
    (gred_tracers_<color>_<caliber>) while leaving LVS projectile behaviour
    completely untouched.

    Rendering: spawns the real gred tracer particle system on the world
    (Entity(0), PATTACH_WORLDORIGIN) — the exact mechanism gred's own
    gred_particle_tracer effect uses — with:
      * control point 0 = the muzzle (world position),
      * control point 1 = the LIVE LVS bullet position, re-set every frame in
        Think(). Because the LVS bullet is simulated with gravity when
        ballistics are enabled, the tracer follows the real ballistic arc and
        the projectile's real speed.
    The handle is validated directly (not via the entity-only global IsValid),
    so the particle system is accepted and renders.

      * when the bullet dies the beam stops — the override wrapper's silent
        original Think still fires lvs_bullet_impact_ap at LVS's exact timing,
      * the original LVS tracer visual is suppressed (the wrapper owns the
        registration), so there is never a duplicate LVS + Gred tracer,
      * each shot is recorded (entity, muzzle position, tracer name, mapping)
        so the muzzle-flash system can pair the correct PCF and the impact
        system can pick the correct caliber.
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

-- Hard lifetime cap: LVS already removes bullets older than 5s; this only
-- guards against an edge case where the bullet record leaks.
local BEAM_MAX_LIFE = 5

--[[---------------------------------------------------------------------------
    Tracer effect lifecycle. `data` is the LVS tracer EffectData:
      Origin        = bullet.Src (world muzzle position)
      Normal        = bullet.Dir
      MaterialIndex = LVS bullet index
-----------------------------------------------------------------------------]]
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

    -- The actual gred tracer particle.
    local pcf = "gred_tracers_" .. (map.color or "white") .. "_" .. (map.caliber or "20mm")

    if not LVS_GRED_FX.Preload(pcf) then
        -- Gred beam unavailable: the override wrapper falls back to the
        -- original LVS tracer (single tracer either way).
        return false
    end

    -- Spawn the real gred tracer particle on the world, exactly like gred's
    -- own gred_particle_tracer effect does (Entity(0), PATTACH_WORLDORIGIN).
    -- Validate the handle directly: particle system handles are NOT entities,
    -- so the global IsValid() (which checks IsEntity) returns false for them.
    local ok, psys = pcall(CreateParticleSystem, Entity(0), pcf, PATTACH_WORLDORIGIN, 0, srcPos)

    if not ok or psys == nil then
        return false
    end
    if psys.IsValid and not psys:IsValid() then
        return false
    end

    -- Control point 0 = muzzle; control point 1 = live bullet position.
    local bulletPos = bullet and bullet.GetPos and bullet:GetPos() or (srcPos + dir * 1200)
    if not isvector(bulletPos) then bulletPos = srcPos + dir * 1200 end

    pcall(function()
        psys:SetControlPoint(0, srcPos)
        psys:SetControlPoint(1, bulletPos)
    end)

    self._psys = psys
    self._die = CurTime() + BEAM_MAX_LIFE

    if cfg.DebugEnabled() then
        Debug("tracer beam:", pcf, "following LVS bullet", bulletID,
            "from", tostring(srcPos), "tip", tostring(bulletPos))
    end

    return true
end

function LVS_GRED_FX_TRACER.Think(self)
    local psys = self._psys
    if not psys or (psys.IsValid and not psys:IsValid()) then return false end

    if CurTime() > (self._die or 0) then
        LVS_GRED_FX_TRACER.Stop(self)
        return false
    end

    local bullet = getBullet(self._bulletID)
    local pos = bullet and bullet.GetPos and bullet:GetPos() or nil

    if not isvector(pos) then
        -- Bullet is gone; the wrapper's silent original Think will fire the
        -- AP impact and tell us to stop. Stop the beam now.
        LVS_GRED_FX_TRACER.Stop(self)
        return false
    end

    -- Follow the live LVS projectile: its position already includes the
    -- ballistic gravity arc (EnableBallistics) and travels at LVS velocity,
    -- so the beam tip tracks the real projectile speed and drop each frame.
    pcall(function() psys:SetControlPoint(1, pos) end)

    return true
end

function LVS_GRED_FX_TRACER.Stop(self)
    if not self then return end
    if self._psys and (not self._psys.IsValid or self._psys:IsValid()) then
        pcall(function() self._psys:StopEmission(false, true) end)
    end
    self._psys = nil
end
