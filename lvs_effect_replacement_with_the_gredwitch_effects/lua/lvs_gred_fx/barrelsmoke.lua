--[[---------------------------------------------------------------------------
    LVS → Gredwitch FX : barrel smoke (client-side)

    Fully independent of the muzzle-flash system. Barrel smoke resolves its
    own muzzle attachment (muzzle.lua), attaches with PATTACH_POINT_FOLLOW and
    stops itself after a fixed lifetime. One smoke column at a time per
    (entity, attachment): firing again replaces the previous one so rapid
    autocannon fire never stacks smoke systems.

    Gated by the lvs_gred_fx_barrel_smoke cvar.
-----------------------------------------------------------------------------]]

if not CLIENT then return end

local cfg = LVS_GRED_FX.Config
local Debug = LVS_GRED_FX.Debug

LVS_GRED_FX_BARRELSMOKE = LVS_GRED_FX_BARRELSMOKE or {}

-- Weak-keyed: dead entities are dropped automatically by the GC.
local ACTIVE = setmetatable({}, { __mode = "k" })

-- Periodic sweeper: stop systems whose owner vanished or whose lifetime
-- expired without the StopAfter timer firing (safety net).
timer.Create("lvs_gred_fx_smoke_sweep", 2, 0, function()
    local now = CurTime()

    for ent, info in pairs(ACTIVE) do
        if not IsValid(ent) or (info.expires or 0) < now then
            if info.psys and IsValid(info.psys) then
                pcall(function() info.psys:StopEmission(false, false) end)
            end
            ACTIVE[ent] = nil
        end
    end
end)

function LVS_GRED_FX_BARRELSMOKE.Spawn(ent, muzzlePos, att, pcf)
    if not cfg.SmokeEnabled() then return end
    if not IsValid(ent) or not isvector(muzzlePos) then return end
    if not isstring(pcf) or pcf == "" then return end
    if not LVS_GRED_FX.Preload(pcf) then return end

    -- Replace the previous smoke on this entity (if any).
    local prev = ACTIVE[ent]
    if prev then
        if prev.psys and IsValid(prev.psys) then
            pcall(function() prev.psys:StopEmission(false, true) end)
        end
        ACTIVE[ent] = nil
    end

    -- Resolve the muzzle attachment independently of the flash system.
    local smokeAtt = att
    if not smokeAtt or smokeAtt <= 0 then
        smokeAtt = LVS_GRED_FX.ResolveMuzzleAttachment(ent, muzzlePos, 0)
    end

    local psys
    if smokeAtt and smokeAtt > 0 and LVS_GRED_FX.ValidAttachment(ent, smokeAtt) then
        -- forceHandle: smoke must be trackable so we can replace it later.
        psys = LVS_GRED_FX.SpawnAttached(pcf, ent, smokeAtt, {
            life = cfg.SmokeLife,
            clear = false,
            forceHandle = true,
        })
    end

    if not psys then
        if cfg.DebugEnabled() then
            Debug("barrel smoke world fallback:", pcf,
                "pos:", tostring(muzzlePos),
                "reason: no valid attachment", "att:", tostring(smokeAtt))
        end
        psys = LVS_GRED_FX.SpawnWorld(pcf, muzzlePos, angle_zero, cfg.SmokeLife, false)
    end

    if psys and IsValid(psys) then
        ACTIVE[ent] = {
            psys    = psys,
            att     = smokeAtt,
            expires = CurTime() + cfg.SmokeLife + 0.1,
        }
    end
end
