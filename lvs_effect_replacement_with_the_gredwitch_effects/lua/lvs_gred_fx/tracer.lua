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

-- Caliber string for impact effects, inferred from the last shot of `ent`.
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
    return "20mm"
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

    local pcf = "gred_tracers_" .. (map.color or "white") .. "_" .. (map.caliber or "20mm")
    self._pcf = pcf

    if not LVS_GRED_FX.Preload(pcf) then
        -- Gred beam unavailable: the override wrapper falls back to the
        -- original LVS tracer (single tracer either way).
        return false
    end

    local ok, psys = pcall(CreateParticleSystem, game.GetWorld(), pcf, PATTACH_WORLDORIGIN, 0, srcPos)

    -- The particle handle is not an entity; validate it directly (see
    -- particles.lua SpawnWorld for details).
    if ok and psys ~= nil and (not psys.IsValid or psys:IsValid()) then
        -- Initial beam: a short stub in the firing direction; Think() extends
        -- it to the live bullet position every frame.
        pcall(function() psys:SetControlPoint(1, srcPos + dir * 1200) end)
        self._psys = psys
        self._die = CurTime() + cfg.TracerLifeCap

        if cfg.DebugEnabled() then
            Debug("tracer beam:", pcf, "from", tostring(srcPos), "color:", map.color, "cal:", map.caliber)
        end

        return true
    end

    return false
end

function LVS_GRED_FX_TRACER.Think(self)
    local psys = self._psys
    if not psys or (psys.IsValid and not psys:IsValid()) then return false end

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

    pcall(function() psys:SetControlPoint(1, endpos) end)
    return true
end

function LVS_GRED_FX_TRACER.Stop(self)
    if not self then return end
    if self._psys and (not self._psys.IsValid or self._psys:IsValid()) then
        pcall(function() self._psys:StopEmission(false, true) end)
    end
    self._psys = nil
end
