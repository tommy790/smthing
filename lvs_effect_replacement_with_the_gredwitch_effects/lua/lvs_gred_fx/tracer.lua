--[[---------------------------------------------------------------------------
    LVS → Gredwitch FX : tracer system (client-side)

    Replaces the LVS tracer visuals with a Gredwitch-STYLED tracer beam that
    follows the LIVE LVS projectile, while leaving LVS projectile behaviour
    completely untouched.

    Rendering: the beam is drawn by a dedicated effect (gred_lvs_tracer) using
    render.DrawBeam in its Render() — the exact mechanism LVS's own tracer
    effects use, which is guaranteed to render. (The gred particle-system
    tracers were not rendering in some environments, so we draw the beam
    instead, colored/width-styled after gred's tracers.)

      * the beam trails BEHIND the live LVS bullet, growing as the projectile
        flies (bullet:GetLength()), so it follows the real ballistic arc
        (gravity included) and the projectile's real speed,
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

-- Caliber string for impact effects. Prefer the per-entity record, then the
-- global last-fired caliber (impacts often arrive with the hit surface as the
-- entity, which has no record of its own).
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

--[[---------------------------------------------------------------------------
    gred_lvs_tracer — the drawn tracer effect.

    Init receives the LVS tracer EffectData (Origin = muzzle, Normal = dir,
    MaterialIndex = LVS bullet index). Each frame Render() draws a beam
    trailing the live LVS bullet, colored/styled by the tracer's caliber and
    color (resolved from the bullet's TracerName). Uses render.DrawBeam —
    the same mechanism as LVS's own tracer effects, so it always renders.
-----------------------------------------------------------------------------]]

local TRACER_COLORS = {
    white  = Color(255, 255, 255, 255),
    yellow = Color(255, 215, 80, 255),
    red    = Color(255, 80, 60, 255),
    green  = Color(100, 255, 100, 255),
}

local TRACER_WIDTH = {
    ["7mm"]  = 3,
    ["12mm"] = 4,
    ["20mm"] = 6,
    ["30mm"] = 10,
    ["40mm"] = 14,
    ["50mm"] = 16,
}

local BeamMat = Material("effects/lvs_base/spark")
local GlowMat = Material("sprites/light_glow02_add")

local function ResolveStyle(tracerName)
    local map = cfg.Tracers[tracerName] or cfg.TracerDefaults
    local color = TRACER_COLORS[map.color] or TRACER_COLORS.white
    local width = TRACER_WIDTH[map.caliber] or 6
    return color, width
end

local TRACER_EFFECT = {}

function TRACER_EFFECT:Init(data)
    self.ID = data:GetMaterialIndex() or 0

    self.Src = isvector(data:GetOrigin()) and data:GetOrigin() or nil
    self.Dir = isvector(data:GetNormal()) and data:GetNormal() or nil

    if not self.Src then
        local bullet = getBullet(self.ID)
        if bullet then self.Src = bullet.Src end
    end
    if not self.Src then
        self.Src = vector_origin
    end
    if not self.Dir then
        self.Dir = vector_up
    end

    local bullet = getBullet(self.ID)
    local tracerName = bullet and bullet.TracerName or nil
    self.Col, self.Width = ResolveStyle(tracerName)

    if self.SetRenderBoundsWS then
        self:SetRenderBoundsWS(self.Src, self.Src + self.Dir * 50000)
    end
end

function TRACER_EFFECT:Think()
    -- The beam lives exactly as long as the LVS bullet.
    return getBullet(self.ID) ~= nil
end

function TRACER_EFFECT:Render()
    local bullet = getBullet(self.ID)
    if not bullet then return end

    local pos = bullet:GetPos()
    if not isvector(pos) then return end

    local dir = bullet:GetDir() or self.Dir

    -- Beam trails behind the bullet and grows as the projectile flies,
    -- exactly like LVS's own tracers — so it follows the real arc and speed.
    local len = 0
    if bullet.GetLength then
        len = bullet:GetLength() or 0
    end
    local tail = math.max(len * 2000, 60)
    local start = pos - dir * tail

    local col = self.Col

    -- Outer glow layer.
    render.SetMaterial(GlowMat)
    render.DrawBeam(start, pos, self.Width * 2.2, 0.7, 0, Color(col.r, col.g, col.b, 80))

    -- Bright core layer.
    render.SetMaterial(BeamMat)
    render.DrawBeam(start, pos, self.Width, 1, 0, col)
    render.DrawBeam(start, pos, self.Width * 0.5, 1, 0, Color(255, 255, 255, 220))
end

effects.Register(TRACER_EFFECT, "gred_lvs_tracer")

--[[---------------------------------------------------------------------------
    Tracer effect lifecycle (the LVS tracer wrapper instance).

    `data` is the LVS tracer EffectData:
      Origin        = bullet.Src (world muzzle position)
      Normal        = bullet.Dir
      MaterialIndex = LVS bullet index

    This instance stays alive while the LVS bullet exists (so the wrapper's
    silent original Think keeps firing lvs_bullet_impact_ap at LVS's timing);
    the actual beam is drawn by the gred_lvs_tracer effect above.
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

    -- Dispatch the drawn tracer effect (it reads the bullet index from the
    -- same EffectData and draws the beam each frame). If it fails to start,
    -- fall back to the original LVS tracer — a single tracer either way.
    local ok = pcall(util.Effect, "gred_lvs_tracer", data)
    if not ok then
        return false
    end

    return true
end

function LVS_GRED_FX_TRACER.Think(self)
    -- Keep the LVS wrapper instance alive while the bullet exists so the
    -- silent original Think can fire lvs_bullet_impact_ap when it ends.
    if not getBullet(self._bulletID) then
        LVS_GRED_FX_TRACER.Stop(self)
        return false
    end
    return true
end

function LVS_GRED_FX_TRACER.Stop(self)
    -- The gred_lvs_tracer effect owns its own lifetime (its Think ends when
    -- the bullet is gone); nothing to clean up here.
end
