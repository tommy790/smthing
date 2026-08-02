--[[---------------------------------------------------------------------------
    LVS → Gredwitch FX : impacts & explosions (client-side)

    Handles normal impacts, AP impacts, HE/explosive impacts, laser impacts,
    shield impacts, water impacts and one-shot world effects.

    Duplicate-impact suppression:
      LVS autocannons/cannons fire BOTH a splash explosion (on collision) and
      lvs_bullet_impact_ap (on the tracer Think when the bullet ends) at the
      same spot. This module records every explosive/HE impact in a BOUNDED
      ring buffer (max C.ImpactBufferMax entries) that is entity-, position-
      and time-aware, and suppresses the AP impact when it matches a recent
      explosion nearby. The buffer is fixed-size and lazily overwritten, so it
      can never grow without bound.
-----------------------------------------------------------------------------]]

if not CLIENT then return end

local cfg = LVS_GRED_FX.Config
local Debug = LVS_GRED_FX.Debug

LVS_GRED_FX_IMPACTS = LVS_GRED_FX_IMPACTS or {}

--[[---------------------------------------------------------------------------
    Bounded ring buffer of recent explosive/HE impacts.
-----------------------------------------------------------------------------]]
local ring = {}
local ringNext = 1
local ringCount = 0

local function isExplosiveName(name)
    if not isstring(name) then return false end
    return string.find(name, "explosion", 1, true) ~= nil
        or string.find(name, "explosive", 1, true) ~= nil
end

local function RecordExplosion(name, ent, pos)
    if not isvector(pos) then return end

    ring[ringNext] = {
        name = name,
        ent  = ent,
        pos  = pos,
        time = CurTime(),
    }
    ringNext = ringNext % cfg.ImpactBufferMax + 1
    if ringCount < cfg.ImpactBufferMax then
        ringCount = ringCount + 1
    end
end

-- True when an explosive impact was recorded near `pos` within `window`
-- seconds. Passing `ent` tightens the match when the same entity fired both.
-- lvs_defence_explosion (flak) always pairs with an AP impact and drifts more,
-- so it uses its own wider time/space window.
local function RecentExplosionNear(pos, window, radiusSqr, ent)
    if not isvector(pos) then return false end

    local now = CurTime()

    for i = 1, ringCount do
        local e = ring[i]
        if e then
            local win = window
            local w = radiusSqr
            if e.name == "lvs_defence_explosion" then
                win = cfg.DefenceSuppressWindow
                w = cfg.DefenceSuppressRadiusSqr
            end
            if (now - e.time) <= win then
                local d = pos:DistToSqr(e.pos)
                if d <= w then
                    return true
                end
                -- Same-entity hits may drift a bit further while still being
                -- the same impact; only apply the widened check for matching
                -- entities.
                if ent and e.ent == ent and d <= w * 4 then
                    return true
                end
            end
        end
    end

    return false
end

function LVS_GRED_FX_IMPACTS.RecentExplosionNear(pos, window, radiusSqr, ent)
    return RecentExplosionNear(pos, window, radiusSqr, ent)
end

--[[---------------------------------------------------------------------------
    GredImpact — surface-aware impact via gred_particle_impact.

    Uses Gredwitch's own impact effect so rotation, surface material, decals
    and blood are handled correctly. Falls back to a simple surface particle
    when the Gredwitch base is not loaded.
-----------------------------------------------------------------------------]]
local MAT_IMPACT_FALLBACK = {
    [MAT_CONCRETE] = "doi_impact_concrete",
    [MAT_METAL]    = "doi_impact_metal",
    [MAT_WOOD]     = "doi_impact_wood",
    [MAT_GLASS]    = "doi_impact_glass",
    [MAT_SAND]     = "doi_impact_sand",
    [MAT_DIRT]     = "doi_impact_dirt",
    [MAT_GRASS]    = "doi_impact_grass",
    [MAT_SNOW]     = "doi_impact_snow",
    [MAT_FLESH]    = "doi_impact_metal",
    [MAT_ALIENFLESH] = "doi_impact_metal",
    [MAT_BLOODYFLESH] = "doi_impact_metal",
}

function LVS_GRED_FX.GredImpact(pos, normal, caliber, isWater)
    if not cfg.Enabled() then return false end
    if not isvector(pos) then return false end

    local n = isvector(normal) and normal or vector_up
    local cal = isstring(caliber) and caliber or "20mm"
    local calIndex = cfg.CaliberIndex[cal] or 3

    -- Gredwitch base present: use its own impact effect.
    if gred and gred.Calibre and gred.Calibre[calIndex] then
        local e = EffectData()
        e:SetOrigin(pos)
        e:SetAngles(n:Angle())
        e:SetFlags(calIndex)
        e:SetMaterialIndex(isWater and 0 or 1) -- 1 = ground, 0 = water
        e:SetSurfaceProp(LVS_GRED_FX.SurfacePropIndex(pos, n))

        local ok = pcall(util.Effect, "gred_particle_impact", e)
        return ok
    end

    -- Gredwitch base missing: minimal surface-based fallback particle.
    local tr = util.TraceLine({
        start = pos + n * 1,
        endpos = pos - n * 12,
        mask = MASK_SHOT,
    })

    local mat = tr.MatType or MAT_METAL
    local pcf = (not isWater) and (MAT_IMPACT_FALLBACK[mat] or "doi_impact_metal") or "doi_impact_water"

    return LVS_GRED_FX.SpawnWorldOneShot(pcf, pos, n:Angle())
end

-- Compute the gred.Mats surface index at a world position for gred_particle_impact.
function LVS_GRED_FX.SurfacePropIndex(pos, n)
    if not gred or not gred.Mats then return 0 end

    local tr = util.TraceLine({
        start = pos + n * 1,
        endpos = pos - n * 12,
        mask = MASK_SHOT,
    })

    if tr.Hit then
        local name = tr.SurfaceProps and util.GetSurfacePropName(tr.SurfaceProps) or nil
        if isstring(name) then
            local idx = gred.Mats[name]
            if idx and idx > 0 then return idx end
        end
    end

    return 0
end

--[[---------------------------------------------------------------------------
    Water detection helper.
-----------------------------------------------------------------------------]]
function LVS_GRED_FX.IsInWater(pos)
    if not isvector(pos) then return false end

    local tr = util.TraceLine({
        start = pos + Vector(0, 0, 4),
        endpos = pos - Vector(0, 0, 4),
        mask = MASK_WATER,
    })

    return tr.Hit == true
end

--[[---------------------------------------------------------------------------
    Position-based throttle for frequently re-fired effects (smoke puffs).
    Bounded: entries older than the window are dropped lazily and the table is
    wiped once it grows past 64 keys.
-----------------------------------------------------------------------------]]
local throttles = {}
local throttleCount = 0

local function ThrottleAt(pos, keyName, window)
    if not isvector(pos) then return true end

    local key = keyName .. ":" .. math.floor(pos.x / 50) .. "," .. math.floor(pos.y / 50) .. "," .. math.floor(pos.z / 50)

    local now = CurTime()
    local expires = throttles[key]

    if throttleCount > 64 then
        -- Keep the table bounded: drop expired entries in one pass.
        local nextThrottles = {}
        local n = 0
        for k, v in pairs(throttles) do
            if v > now then
                nextThrottles[k] = v
                n = n + 1
            end
        end
        throttles = nextThrottles
        throttleCount = n
    end

    if expires and expires > now then
        return false
    end

    throttles[key] = now + window
    throttleCount = throttleCount + 1

    return true
end

--[[---------------------------------------------------------------------------
    One-shot dispatch table (world-space effects).
-----------------------------------------------------------------------------]]
local function dispatchOneShot(name, self, data)
    local pos = data.GetOrigin and data:GetOrigin() or nil
    local nrm = data.GetNormal and data:GetNormal() or nil
    local ent = data.GetEntity and data:GetEntity() or nil

    if not isvector(pos) then return false end

    local ang = isvector(nrm) and nrm:Angle() or nil

    -- Record ANY explosive/HE effect for AP duplicate suppression.
    if isExplosiveName(name) then
        RecordExplosion(name, ent, pos)
        if cfg.DebugEnabled() then
            Debug("recorded explosion:", name, "pos:", tostring(pos))
        end
    end

    local pcf = cfg.ExplosionMap[name]

    if pcf then
        if LVS_GRED_FX.IsInWater(pos) and (name == "lvs_explosion" or name == "lvs_explosion_bomb" or name == "lvs_explosion_small" or name == "lvs_explosion_nodebris" or name == "lvs_trailer_explosion") then
            LVS_GRED_FX.SpawnWorld(cfg.WaterExplosionPcf, pos, ang, 1.5, false)
        else
            LVS_GRED_FX.SpawnWorld(pcf, pos, ang, 1.5, false)
        end
        return true
    end

    if name == "lvs_laser_explosion" or name == "lvs_laser_explosion_aat" or name:find("lvs_laser_explosion", 1, true) then
        LVS_GRED_FX.SpawnWorld(cfg.LaserExplosionPcf, pos, ang, 1.2, false)
        return true
    end

    if name == "lvs_bullet_impact_explosive" then
        -- HE hit: caliber-specific explosion (visually distinct from AP).
        local cal = LVS_GRED_FX_TRACER.CaliberFor(ent)
        local hePcf = cfg.HEImpactByCaliber[cal] or "gred_20mm"
        if LVS_GRED_FX.IsInWater(pos) then
            LVS_GRED_FX.SpawnWorld(cfg.WaterExplosionPcf, pos, ang, 1.5, false)
        else
            LVS_GRED_FX.SpawnWorld(hePcf, pos, ang, 1.5, false)
        end
        return true
    end

    if name == "lvs_bullet_impact_ap" then
        -- AP impact: suppress when it overlaps a recent explosive impact
        -- (LVS fires both at the same spot; we only want one visual).
        if RecentExplosionNear(pos, cfg.SuppressWindow, cfg.SuppressRadiusSqr, ent) then
            if cfg.DebugEnabled() then
                Debug("AP impact suppressed (duplicate of recent explosion) at", tostring(pos))
            end
            return true
        end

        local n = isvector(nrm) and nrm or vector_up
        local cal = LVS_GRED_FX_TRACER.CaliberFor(ent)
        local apPcf = cfg.APImpactPcfByCaliber[cal]

        if apPcf then
            LVS_GRED_FX.SpawnWorld(apPcf, pos + n * 2, n:Angle(), 1.2, false)
        else
            -- Autocannon / small-calibre AP: surface-aware impact with the
            -- 12mm profile (doi_gunrun_impact) — visually distinct from HE.
            LVS_GRED_FX.GredImpact(pos, n, cfg.APImpactSmallCaliber)
        end
        return true
    end

    if name == "lvs_bullet_impact" then
        -- Generic bullet / splash impact: surface-aware.
        local cal = LVS_GRED_FX_TRACER.CaliberFor(ent)
        LVS_GRED_FX.GredImpact(pos, nrm, cal, LVS_GRED_FX.IsInWater(pos))
        return true
    end

    if name == "lvs_laser_impact" then
        LVS_GRED_FX.SpawnWorld(cfg.LaserImpactPcf, pos, ang, 0.8, true)
        return true
    end

    if name == "lvs_shield_impact" then
        LVS_GRED_FX.SpawnWorld(cfg.ShieldImpactPcf, pos, ang, 0.8, true)
        return true
    end

    if cfg.WaterByEffect[name] then
        LVS_GRED_FX.SpawnWorld(cfg.WaterByEffect[name], pos, ang or angle_zero, 1.0, false)
        return true
    end

    if name == "lvs_physics_scrape" or name == "lvs_physics_trackscraping" or name == "lvs_physics_turretscraping" then
        -- Scrape effects can fire every physics tick while a vehicle grinds
        -- against the ground; throttle by position so spark systems never
        -- stack up during a long scrape.
        if ThrottleAt(pos, "scrape", 0.15) then
            LVS_GRED_FX.SpawnWorld(cfg.ScrapePcf, pos, ang or angle_zero, 0.6, true)
        end
        return true
    end

    if name == "lvs_defence_smoke" then
        -- LVS re-fires this every 0.2s while the smoke canister is active;
        -- throttle by position so smoke puffs never stack into dozens of
        -- overlapping systems.
        if ThrottleAt(pos, "defence_smoke", 1.5) then
            LVS_GRED_FX.SpawnWorld(cfg.DefenceSmokePcf, pos, angle_zero, 2.0, false)
        end
        return true
    end

    if name == "lvs_walker_stomp" then
        LVS_GRED_FX.SpawnWorld(cfg.StompDustPcf, pos, angle_zero, 1.2, false)
        LVS_GRED_FX.SpawnWorld("ins_rpg_explosion", pos + Vector(0, 0, 8), angle_zero, 1.0, false)
        return true
    end

    if name == "lvs_rotor_destruction" then
        LVS_GRED_FX.SpawnWorld(cfg.RotorExplosionPcf, pos, angle_zero, 1.2, false)
        return true
    end

    if name == "lvs_tire_blow" then
        LVS_GRED_FX.SpawnWorld(cfg.StompDustPcf, pos, angle_zero, 1.0, false)
        return true
    end

    if name:find("muzzle", 1, true) then
        -- Unknown/third-party muzzle effect: use the generic attached flash.
        return LVS_GRED_FX_MUZZLEFLASH.SpawnGeneric(name, self, data)
    end

    return false
end

function LVS_GRED_FX_IMPACTS.Dispatch(name, self, data)
    return dispatchOneShot(name, self, data)
end
