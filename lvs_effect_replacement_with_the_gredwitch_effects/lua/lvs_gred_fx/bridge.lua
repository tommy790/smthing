if not CLIENT then return end

LVS_GRED_FX = LVS_GRED_FX or {}

-- Configuration CVars

local function getOrCreateClientConVar(name, default, helpText)

	return GetConVar(name) or CreateClientConVar(name, default, true, false, helpText, 0, 1)

end

local cv = getOrCreateClientConVar(

	"lvs_gred_fx",

	"1",

	"Replace LVS client VFX with Gredwitch PCF particles."

)

local cv_debug = getOrCreateClientConVar(

	"lvs_gred_fx_debug",

	"0",

	"Print debug info for Gredwitch LVS effect override mapping."

)

local cv_smoke = getOrCreateClientConVar(

	"lvs_gred_fx_barrel_smoke",

	"1",

	"Enable barrel smoke after firing cannons."

)

local PWO = PATTACH_WORLDORIGIN

-- Internal Utility Functions

local function particleHost()

	local w = game.GetWorld()

	if IsValid(w) then return w end

	local z = Entity(0)

	if IsValid(z) then return z end

	return nil

end

local function enabled()
	return cv:GetBool()
end

function LVS_GRED_FX.Enabled()

	return enabled()

end

LVS_GRED_FX_MUZZLE_SUPPRESS_UNTIL = LVS_GRED_FX_MUZZLE_SUPPRESS_UNTIL or 0

LVS_GRED_FX_ALLOW_OWN_PARTICLE = LVS_GRED_FX_ALLOW_OWN_PARTICLE or false

function LVS_GRED_FX.SuppressMuzzleFlash(duration)

	LVS_GRED_FX_MUZZLE_SUPPRESS_UNTIL = math.max(

		LVS_GRED_FX_MUZZLE_SUPPRESS_UNTIL or 0,

		CurTime() + (duration or 0.10)

	)

end

function LVS_GRED_FX.IsSuppressingMuzzleFlash()

	return enabled()

		and not LVS_GRED_FX_ALLOW_OWN_PARTICLE

		and (LVS_GRED_FX_MUZZLE_SUPPRESS_UNTIL or 0) > CurTime()

end

-- Ammo Rack Logic

local AMMORACK_ACTIVE = setmetatable({}, { __mode = "k" })

local function stopAmmoRack(ent)

	local info = AMMORACK_ACTIVE[ent]

	if not info then return end

	if info.psys and info.psys.StopEmission then

		pcall(function()

			info.psys:StopEmission(false, true)

		end)

	end

	AMMORACK_ACTIVE[ent] = nil

end

hook.Add("Think", "lvs_gred_fx_ammorack_stop", function()
	if not enabled() then
		for ent, info in pairs(AMMORACK_ACTIVE) do
			stopAmmoRack(ent)
		end
		return
	end
	for ent, info in pairs(AMMORACK_ACTIVE) do
		if not IsValid(ent) then
			stopAmmoRack(ent)
		end
	end
end)

-- Particle Spawning

local PRECACHED = {}

-- Caliber string → gred.Calibre index (used for gred_particle_impact effect)
local CALIBER_TO_INDEX = {
	["7mm"]  = 1,
	["12mm"] = 2,
	["20mm"] = 3,
	["30mm"] = 4,
	["40mm"] = 5,
}

-- Recent explosive impact positions, used to suppress the AP impact that LVS
-- autocannons fire on top of their splash explosion. LVS fires both
-- lvs_bullet_impact_explosive (on collision) and lvs_bullet_impact_ap (on the
-- next Think from the tracer) at the same spot, producing an explosion + AP
-- impact mix. Each entry = { pos, time }.
local RECENT_EXPLOSIONS = {}

-- Dedicated tracker for lvs_defence_explosion (flak autocannon splash).

-- Uses a wider time/space window than RECENT_EXPLOSIONS so the AP impact

-- that follows is reliably suppressed. lvs_defence_explosion should NEVER

-- play an AP impact replacement.

local RECENT_DEFENCE_EXPLOSIONS = {}

-- Periodic cleanup: remove explosion entries older than 2s. Without this, the

-- table grows indefinitely if no AP impacts fire to trigger cleanup.

timer.Create("lvs_gred_fx_explosion_cleanup", 2, 0, function()

	local now = CurTime()

	for i = #RECENT_EXPLOSIONS, 1, -1 do

		if (now - RECENT_EXPLOSIONS[i].time) > 2 then table.remove(RECENT_EXPLOSIONS, i) end

	end

	for i = #RECENT_DEFENCE_EXPLOSIONS, 1, -1 do

		if (now - RECENT_DEFENCE_EXPLOSIONS[i].time) > 3 then table.remove(RECENT_DEFENCE_EXPLOSIONS, i) end

	end

end)

local function pfx(name, pos, ang)

	if not name or not enabled() then return false end

	if cv_debug:GetBool() then

		print("[lvs_gred_fx] spawn pcf:", name, "pos:", pos, "ang:", ang)

	end

	if not PRECACHED[name] then

		local ok = pcall(PrecacheParticleSystem, name)

		if not ok then return false end

		PRECACHED[name] = true

	end

	local oldAllow = LVS_GRED_FX_ALLOW_OWN_PARTICLE

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = true

	local ok = pcall(ParticleEffect, name, pos, ang or Angle(0, 0, 0), nil)

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = oldAllow

	return ok == true

end

local function timedPfx(name, pos, ang, duration)

	if not name or not enabled() then return false end

	if not PRECACHED[name] then

		local ok = pcall(PrecacheParticleSystem, name)

		if not ok then return false end

		PRECACHED[name] = true

	end

	ang = ang or Angle(0, 0, 0)

	duration = duration or 1

	local oldAllow = LVS_GRED_FX_ALLOW_OWN_PARTICLE

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = true

	local ok, psys

	if CreateParticleSystemNoEntity then

		ok, psys = pcall(CreateParticleSystemNoEntity, name, pos, ang)

	end

	if (not ok or not psys) and CreateParticleSystem then

		local host = particleHost()

		if host then

			ok, psys = pcall(CreateParticleSystem, host, name, PWO, 0, pos)

		end

	end

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = oldAllow

	if not ok or not psys then

		return pfx(name, pos, ang)

	end

	timer.Simple(duration, function()

		if psys and psys.StopEmission then

			pcall(function() psys:StopEmission(false) end)

		end

	end)

	return true

end

-- Spawn gred_particle_impact — Gredwitch's own surface-aware bullet impact.
-- This handles rotation, surface material detection, decals, blood, and
-- caliber-specific particles correctly. Use this instead of manually calling
-- ins_impact_* particles.
local function gredImpact(pos, normal, caliber, isWater)

	if not enabled() then return end

	local calIndex = CALIBER_TO_INDEX[caliber or "20mm"] or 3

	if not gred or not gred.Calibre or not gred.Calibre[calIndex] then

		-- Fallback if gred isn't loaded
		local n = normal or vector_up
		local tr = util.TraceLine({
			start = pos + n * 0.5,
			endpos = pos - n * 12,
			mask = MASK_SHOT,
		})
		local mat = tr.MatType or 0
		local m = {
			[76] = "ins_impact_concrete", [70] = "ins_impact_metal",
			[88] = "ins_impact_wood", [89] = "ins_impact_glass",
			[85] = "ins_impact_sand", [68] = "ins_impact_dirt",
		}
		return pfx(m[mat] or "ins_impact_metal", pos, (tr.HitNormal or n):Angle())
	end

	local e = EffectData()
	e:SetOrigin(pos)
	e:SetAngles((normal or vector_up):Angle())
	e:SetFlags(calIndex) -- gred.Calibre index
	e:SetMaterialIndex(isWater and 0 or 1) -- 1 = ground, 0 = water
	e:SetSurfaceProp(0)

	util.Effect("gred_particle_impact", e)

	return true

end

-- Tracer / Muzzle Mapping

local LAST_TRACER = LVS_GRED_FX_LAST_TRACER or setmetatable({}, { __mode = "k" })

LVS_GRED_FX_LAST_TRACER = LAST_TRACER

local TRACER_MUZZLE_WINDOW = 0.15

local DEFAULT_MUZZLE_PCF = "muzzleflash_bar_3p"

local MUZZLE_BY_TRACER = {

	lvs_tracer_yellow_small = "muzzleflash_mg42_3p",

	lvs_pulserifle_tracer = "muzzleflash_mg42_3p",

	lvs_pulserifle_tracer_large = "muzzleflash_mg42_3p",

	lvs_tracer_orange = "muzzleflash_bar_3p",

	lvs_tracer_green = "muzzleflash_bar_3p",

	lvs_tracer_yellow = "muzzleflash_bar_3p",

	lvs_tracer_white = "muzzleflash_bar_3p",

	lvs_tracer_autocannon = "muzzleflash_bar_3p",

	lvs_tracer_missile = "muzzleflash_bar_3p",

	lvs_tracer_cannon = "gred_arti_muzzle_blast_alt",

	lvs_tracer_proton = "gred_arti_muzzle_blast_alt",

	lvs_laser_blue = "muzzleflash_bar_3p",

	lvs_laser_blue_long = "muzzleflash_bar_3p",

	lvs_laser_blue_short = "muzzleflash_bar_3p",

	lvs_laser_green = "muzzleflash_bar_3p",

	lvs_laser_green_short = "muzzleflash_bar_3p",

	lvs_laser_red = "muzzleflash_bar_3p",

	lvs_laser_red_short = "muzzleflash_bar_3p",

	lvs_laser_red_aat = "gred_arti_muzzle_blast_alt",

}

local function attachmentNearPosition(ent, pos, maxDistSqr)

	if not IsValid(ent) or not ent.GetAttachments or not isvector(pos) then return 0 end

	if ent.SetupBones then pcall(ent.SetupBones, ent) end

	local atts = ent:GetAttachments()

	if not atts or #atts <= 0 then return 0 end

	local bestAtt = 0

	local bestDist = math.huge

	maxDistSqr = maxDistSqr or 4096 -- 64 units default, strict enough to avoid base attachments

	-- Pick the attachment nearest to the muzzle/tracer source center. Do not use any

	-- name/order guessing, and do not pick anything outside the strict radius.

	for i = 1, #atts do

		local id = atts[i].id

		if id and id > 0 then

			local attData = ent:GetAttachment(id)

			if attData then

				local dist = attData.Pos:DistToSqr(pos)

				if dist < bestDist then

					bestDist = dist

					bestAtt = id

				end

			end

		end

	end

	if bestAtt <= 0 or bestDist > maxDistSqr then return 0 end

	return bestAtt

end

-- Quick caliber lookup by tracer name (used before TRACER table is defined)
local TRACER_CAL = {
	lvs_tracer_orange = "20mm",
	lvs_tracer_green = "20mm",
	lvs_tracer_yellow = "20mm",
	lvs_tracer_yellow_small = "12mm",
	lvs_tracer_white = "20mm",
	lvs_tracer_autocannon = "30mm",
	lvs_tracer_cannon = "40mm",
	lvs_tracer_missile = "30mm",
	lvs_tracer_proton = "40mm",
	lvs_pulserifle_tracer = "7mm",
	lvs_pulserifle_tracer_large = "12mm",
	lvs_laser_blue = "30mm",
	lvs_laser_blue_long = "30mm",
	lvs_laser_blue_short = "20mm",
	lvs_laser_green = "30mm",
	lvs_laser_green_short = "20mm",
	lvs_laser_red = "30mm",
	lvs_laser_red_short = "20mm",
	lvs_laser_red_aat = "40mm",
}

local function noteTracerFor(ent, tracerName, srcPos)

	if not IsValid(ent) or not tracerName then return end

	local list = LAST_TRACER[ent]

	if not list then

		list = {}

		LAST_TRACER[ent] = list

	end

	-- Track caliber for AP/HE hit particles
	local _tcal = TRACER_CAL[tracerName] or "20mm"
	LVS_GRED_FX._lastCaliber = _tcal
	LVS_GRED_FX._lastTracerName = tracerName

	list[#list + 1] = {

		caliber = _tcal,

		name = tracerName,

		time = CurTime(),

		srcPos = srcPos,

		-- The tracer's bullet source is the authoritative muzzle source. Use a tight

		-- 16-unit radius so only an attachment essentially AT the source position is

		-- accepted. The old 64-unit radius could pick the wrong barrel on multi-barrel

		-- vehicles where two muzzles are within 64 units of each other.

		att = attachmentNearPosition(ent, srcPos, 256),

	}

	-- Keep the list small; only very recent records can match a muzzle flash.

	if #list > 8 then table.remove(list, 1) end

	LVS_GRED_FX.SuppressMuzzleFlash(0.12)

end

local function getRecentTracerRecord(ent, muzzlePos)

	if not IsValid(ent) then return nil end

	local list = LAST_TRACER[ent]

	if not list then return nil end

	local now = CurTime()

	local best

	local bestDist = math.huge

	for i = #list, 1, -1 do

		local rec = list[i]

		if not rec or (now - (rec.time or 0)) > TRACER_MUZZLE_WINDOW then

			table.remove(list, i)

		else

			local dist = 0

			if isvector(muzzlePos) and isvector(rec.srcPos) then

				dist = rec.srcPos:DistToSqr(muzzlePos)

				-- Muzzle EffectData origin and LVS bullet SrcEntity can separate while aiming

				-- up/down because the client receives/interpolates them at slightly different

				-- times. Keep attachment validation itself at 64 units, but allow a wider

				-- tracer-to-muzzle association window so aiming down does not drop to id 0.

				if dist > 65536 then continue end -- 256 units association only

			else

				dist = #list - i

			end

			if dist < bestDist then

				bestDist = dist

				best = rec

			end

		end

	end

	return best

end

local function pickMuzzleAttachment(ent, muzzlePos)

	local rec = getRecentTracerRecord(ent, muzzlePos)

	return rec and rec.att or 0

end

local function resolveMuzzleEntity(ent)

	-- lvs_base_gunner creates the muzzle effect on the gunner entity, but LVS stores

	-- and networks the tracer/bullet Entity as the parent vehicle Base. Use the same

	-- entity the tracer came from so "this tracer = this muzzleflash" can find the

	-- record and PATTACH to the vehicle attachment instead of failing with id 0.

	if IsValid(ent) and ent.GetVehicle then

		local base = ent:GetVehicle()

		if IsValid(base) then return base end

	end

	return ent

end

-- HE/explosive hit particles — actual explosions, visually distinct from AP

local HE_HIT_BY_CALIBER = {

	["7mm"]  = "gred_20mm",

	["12mm"] = "gred_20mm",

	["20mm"] = "gred_20mm",

	["30mm"] = "gred_20mm",

	["40mm"] = "gred_40mm",

}

-- Get the caliber from an entity's last tracer record

local function getEntityCaliber(ent)

	if IsValid(ent) then

		local list = LAST_TRACER[ent]

		if list and #list > 0 then

			local rec = list[#list]

			if rec and rec.caliber then return rec.caliber end

		end

	end

	return LVS_GRED_FX._lastCaliber or "20mm"

end

local function heImpactAt(pos, normal, caliber)

	-- HE/explosive hit — uses explosion particles, NOT surface-based impacts.
	-- Explosions don't need surface-relative rotation, they work omnidirectionally.

	local n = normal or vector_up

	local ang = n:Angle()

	caliber = caliber or LVS_GRED_FX._lastCaliber or "20mm"

	local pcf = HE_HIT_BY_CALIBER[caliber] or "ins_rpg_explosion"

	pfx(pcf, pos, ang)

	return true

end

-- Tracer Definition

local ENT_TRAIL

local TRACER = {

	lvs_tracer_orange = { "yellow", "20mm" },

	lvs_tracer_green = { "green", "20mm" },

	lvs_tracer_yellow = { "yellow", "20mm" },

	lvs_tracer_yellow_small = { "yellow", "12mm" },

	lvs_tracer_white = { "white", "20mm" },

	lvs_tracer_autocannon = { "white", "30mm" },

	lvs_tracer_cannon = { "white", "40mm" },

	lvs_tracer_missile = { "yellow", "30mm" },

	lvs_tracer_proton = { "white", "40mm" },

	lvs_pulserifle_tracer = { "white", "7mm" },

	lvs_pulserifle_tracer_large = { "white", "12mm" },

	lvs_laser_blue = { "white", "30mm" },

	lvs_laser_blue_long = { "white", "30mm" },

	lvs_laser_blue_short = { "white", "20mm" },

	lvs_laser_green = { "green", "30mm" },

	lvs_laser_green_short = { "green", "20mm" },

	lvs_laser_red = { "red", "30mm" },

	lvs_laser_red_short = { "red", "20mm" },

	lvs_laser_red_aat = { "red", "40mm" },

}

local function isTracerName(n)

	if not isstring(n) then return false end

	return TRACER[n] ~= nil

		or n:sub(1, 11) == "lvs_tracer_"

		or n:sub(1, 20) == "lvs_pulserifle_tracer"

		or (

			n:sub(1, 10) == "lvs_laser_"

			and n ~= "lvs_laser_blue_continuous"

			and n ~= "lvs_laser_impact"

			and n:sub(1, 18) ~= "lvs_laser_explosion"

			and n ~= "lvs_laser_charge"

		)

end

function LVS_GRED_FX.SuppressOriginalOnFailure(name)

	if not cv:GetBool() then return false end

	-- Suppress fallback for tracers (use Gredwitch particle or nothing) and
	-- entity-attached effects (trails, fire) where a half-replaced jet would
	-- look worse than nothing.

	return isTracerName(name)

		or (ENT_TRAIL and ENT_TRAIL[name] ~= nil)

		or name == "lvs_carengine_fire"

		or name == "lvs_carfueltank_fire"

end

function LVS_GRED_FX.ShouldRunOriginalFeedback(name)

	-- Let the original LVS effect decide when/if screenshake should happen. The

	-- override wrapper runs original Init in feedback-only mode for these effect

	-- classes, suppressing particles/lights while preserving util.ScreenShake calls.

	return name == "lvs_explosion"

		or name == "lvs_explosion_bomb"

		or name == "lvs_explosion_small"

		or name == "lvs_explosion_nodebris"

		or name == "lvs_trailer_explosion"

		or name == "lvs_defence_explosion"

		or name == "lvs_concussion_explosion"

		or name == "lvs_proton_explosion"

		or name == "lvs_bullet_impact_explosive"

		or name == "lvs_bullet_impact_ap"

		or name == "lvs_laser_impact"

		or name:find("lvs_laser_explosion", 1, true) ~= nil

end

-- Cannon Smoke (Barrel Heat)

local function validSmokeAttachment(ent, att, bpos)

	att = tonumber(att) or 0

	if att <= 0 or not IsValid(ent) or not ent.GetAttachment then return 0 end

	local attData = ent:GetAttachment(att)

	if not attData then return 0 end

	-- Toolgun actions and some LVS weapons can leave EffectData attachment as 0 or a

	-- stale/base-model id. Reject attachments that are not very close to the actual

	-- muzzle position so smoke never snaps to attachment 0/vehicle origin/random base

	-- point. Keep this strict: if the barrel attachment cannot be proven, use a

	-- world-position particle instead of a guessed entity attachment.

	if isvector(bpos) and attData.Pos:DistToSqr(bpos) > 4096 then return 0 end -- 64 units

	return att

end

local function nearestSmokeAttachment(ent, centerPos)

	if not IsValid(ent) or not ent.GetAttachments or not isvector(centerPos) then return 0 end

	if ent.SetupBones then pcall(ent.SetupBones, ent) end

	local bestDist = math.huge

	local bestAtt = 0

	local atts = ent:GetAttachments()

	if not atts or #atts <= 0 then return 0 end

	-- The smoke detection box is centered on the tracer source/attachment position,

	-- not the muzzle EffectData origin. This prevents aiming up/down from making the

	-- smoke validator drop to attachment id 0.

	for i = 1, #atts do

		local id = atts[i].id

		local attData = ent:GetAttachment(id)

		if attData then

			local dist = attData.Pos:DistToSqr(centerPos)

			if id and id > 0 and dist < bestDist and dist <= 4096 then

				bestDist = dist

				bestAtt = id

			end

		end

	end

	return bestAtt

end

local MUZZLE_NO_ATTACH = {

	-- Cannon/artillery muzzleflashes look wrong when attached to LVS muzzle

	-- attachments on some models. Spawn them at the LVS muzzle world position instead.

	gred_arti_muzzle_blast_alt = true,

	gred_arti_muzzle_blast = true,

}

local MUZZLE_ATTACH_ROLL_FIX_DEFAULT = {

	-- Most vehicles use the PCF/attachment roll correctly. Keep default empty so a

	-- vehicle-specific fix does not break other LVS vehicles.

}

local MUZZLE_ATTACH_ROLL_FIX_BY_MODEL = {

	-- Day of Defeat Willys Jeep MG model has its MG42-style muzzleflash rolled

	-- sideways on the LVS attachment. Scope the correction to this exact model only.

	["models/diggercars/willys/willys_mg.mdl"] = {

		muzzleflash_mg42_3p = -90,

	},

}

local MUZZLE_ATTACH_ROLL_FIX_BY_CLASS = {

	-- Day of Defeat Willys Jeep MG has its MG42-style muzzleflash rolled sideways on

	-- the LVS attachment. Scope the correction to this exact vehicle class only.

	lvs_wheeldrive_dodwillyjeep_mg = {

		muzzleflash_mg42_3p = -90,

	},

}

local function validMuzzleAttachment(ent, att, bpos)

	att = tonumber(att) or 0

	if att <= 0 or not IsValid(ent) or not ent.GetAttachment then return 0 end

	if ent.SetupBones then pcall(ent.SetupBones, ent) end

	local attData = ent:GetAttachment(att)

	if not attData then return 0 end

	-- Muzzle flashes use the tracer-derived id. Keep the validation strict so stale

	-- toolgun/base-origin attachment state is rejected.

	if isvector(bpos) and attData.Pos:DistToSqr(bpos) > 4096 then return 0 end -- 64 units

	return att

end

local function getMuzzleRollFix(name, ent)

	local model = IsValid(ent) and ent:GetModel() or nil

	if isstring(model) then

		model = string.lower(model)

		local byModel = MUZZLE_ATTACH_ROLL_FIX_BY_MODEL[model]

		if byModel and byModel[name] ~= nil then return byModel[name] end

	end

	local class = IsValid(ent) and ent:GetClass() or nil

	if isstring(class) then

		local byClass = MUZZLE_ATTACH_ROLL_FIX_BY_CLASS[class]

		if byClass and byClass[name] ~= nil then return byClass[name] end

	end

	return MUZZLE_ATTACH_ROLL_FIX_DEFAULT[name]

end

local function applyParticleRoll(psys, ang, roll)

	if not psys or not isangle(ang) or not roll then return end

	local fixed = Angle(ang.p, ang.y, ang.r)

	fixed:RotateAroundAxis(fixed:Forward(), roll)

	if psys.SetControlPointOrientation then

		pcall(function()

			psys:SetControlPointOrientation(0, fixed:Forward(), fixed:Right(), fixed:Up())

		end)

	elseif psys.SetControlPointForwardVector then

		pcall(function()

			psys:SetControlPointForwardVector(0, fixed:Forward())

		end)

	end

end

local function attachedMuzzlePfx(name, ent, bpos, ang, tracer_att, fallback_att)

	if not name or not enabled() then return false end

	if not isvector(bpos) then return false end

	if not PRECACHED[name] then

		local ok = pcall(PrecacheParticleSystem, name)

		if not ok then return false end

		PRECACHED[name] = true

	end

	-- Cannon/Haubitze artillery muzzleflashes intentionally do not use PATTACH. They

	-- are spawned at the exact LVS muzzle world position to avoid the 90-degree roll

	-- issue on attached Gred artillery particles.

	if MUZZLE_NO_ATTACH[name] then

		if cv_debug:GetBool() then print("[lvs_gred_fx] cannon/haubitze muzzle world pcf:", name) end

		return pfx(name, bpos, ang)

	end

	local att = tonumber(tracer_att) or 0

	-- First choice: the attachment id recorded from the matching tracer source.

	if att > 0 and IsValid(ent) and ent.GetAttachment then

		if ent.SetupBones then pcall(ent.SetupBones, ent) end

		if not ent:GetAttachment(att) then att = 0 end

	end

	-- Second choice for non-cannon muzzleflashes only: a valid LVS EffectData

	-- attachment. This keeps every non-cannon muzzleflash PATTACHed while still

	-- rejecting id 0/stale toolgun attachment state.

	if att <= 0 then

		att = validMuzzleAttachment(ent, fallback_att, bpos)

	end

	-- No nearest-attachment guessing. The old fallback used attachmentNearPosition

	-- to pick the nearest attachment within 64 units, which could attach the muzzle

	-- flash to the WRONG barrel on multi-barrel vehicles. If we do not have a trusted

	-- attachment from the tracer or the EffectData, spawn at the muzzle world position

	-- instead of guessing.

	if att <= 0 then

		if cv_debug:GetBool() then print("[lvs_gred_fx] no trusted attachment, using world position:", name) end

		return pfx(name, bpos, ang)

	end

	if att > 0 and IsValid(ent) then

		local oldAllow = LVS_GRED_FX_ALLOW_OWN_PARTICLE

		LVS_GRED_FX_ALLOW_OWN_PARTICLE = true

		local ok, psys

		local rollFix = getMuzzleRollFix(name, ent)

		if rollFix and CreateParticleSystem then

			-- Still PATTACH_POINT_FOLLOW, but CreateParticleSystem gives us a handle so

			-- we can correct the particle roll for PCFs that are sideways on LVS attachments.

			ok, psys = pcall(CreateParticleSystem, ent, name, PATTACH_POINT_FOLLOW, att, vector_origin)

			if ok and psys then

				applyParticleRoll(psys, ang, rollFix)

				timer.Simple(0.35, function()

					if psys and psys.StopEmission then pcall(function() psys:StopEmission(false, false) end) end

				end)

			end

		else

			ok = pcall(ParticleEffectAttach, name, PATTACH_POINT_FOLLOW, ent, att)

		end

		LVS_GRED_FX_ALLOW_OWN_PARTICLE = oldAllow

		if ok then

			if cv_debug:GetBool() then print("[lvs_gred_fx] attached muzzle pcf:", name, "att:", att, "tracer_att:", tostring(tracer_att), "fallback_att:", tostring(fallback_att), "rollfix:", tostring(rollFix)) end

			return true

		end

	end

	-- Requested behavior: all non-cannon/haubitze muzzleflashes must use PATTACH. If

	-- no safe attachment exists, do not spawn a misleading world-position flash.

	if cv_debug:GetBool() then

		print("[lvs_gred_fx] skipped non-cannon muzzle; no safe PATTACH id:", name, tostring(tracer_att), tostring(fallback_att))

	end

	return false

end

local attachCannonSmoke

local function muzzleDOIAttached(ent, pos, ang, tracer_att, fallback_att)

	local ok = false

	ok = attachedMuzzlePfx("muzzleflash_sparks_variant_6", ent, pos, ang, tracer_att, fallback_att) or ok

	ok = attachedMuzzlePfx("muzzleflash_1p_glow", ent, pos, ang, tracer_att, fallback_att) or ok

	ok = attachedMuzzlePfx("muzzleflash_m590_1p_core", ent, pos, ang, tracer_att, fallback_att) or ok

	ok = attachedMuzzlePfx("muzzleflash_smoke_small_variant_1", ent, pos, ang, tracer_att, fallback_att) or ok

	return ok

end

local function spawnTracerMatchedMuzzle(ent, pos, ang, forcedPcf, doSmoke, smokeAtt, smokeParticle)

	-- LVS usually creates the muzzle effect before the client receives/starts the

	-- tracer effect. Retry briefly, then use the tracer record for this entity to

	-- choose both the PCF and the only attachment id allowed for PATTACH_POINT_FOLLOW.

	local startTime = CurTime()

	local attempts = 0

	local function trySpawn()

		if not enabled() then return end

		attempts = attempts + 1

		local attachEnt = resolveMuzzleEntity(ent)

		local rec = getRecentTracerRecord(attachEnt, pos)

		if not rec and attempts < 5 and CurTime() - startTime < 0.08 then

			timer.Simple(0, trySpawn)

			return

		end

		local pcf = forcedPcf or (rec and (MUZZLE_BY_TRACER[rec.name] or DEFAULT_MUZZLE_PCF)) or DEFAULT_MUZZLE_PCF

		local tracerAtt = rec and rec.att or 0

		attachedMuzzlePfx(pcf, attachEnt, pos, ang, tracerAtt, smokeAtt)

		local allowSmoke = smokeParticle ~= nil

			or (rec and (rec.name == "lvs_tracer_cannon" or rec.name == "lvs_tracer_proton" or rec.name == "lvs_tracer_autocannon" or rec.name == "lvs_tracer_missile" or rec.name == "lvs_tracer_yellow_small" or rec.name == "lvs_tracer_white" or rec.name == "lvs_tracer_yellow" or rec.name == "lvs_tracer_orange" or rec.name == "lvs_tracer_green"))

		if doSmoke and allowSmoke then

			-- Choose smoke particle based on weapon type:
			-- Cannon/large tank guns (lvs_tracer_cannon/proton) -> vj_smoke_white_narrow
			-- Autocannons and small arms -> weapon_muzzle_smoke
			local smokeParticleName = smokeParticle
			if not smokeParticleName then
				local tName = rec and rec.name or ""
				if tName == "lvs_tracer_cannon" or tName == "lvs_tracer_proton" then
					smokeParticleName = "vj_smoke_white_narrow"
				else
					smokeParticleName = "weapon_muzzle_smoke"
				end
			end
			local smokeAttId = (rec and rec.att) or smokeAtt
			local smokeSrcPos = rec and rec.srcPos
			attachCannonSmoke(attachEnt, pos, smokeAttId, smokeParticleName, smokeSrcPos)
		end

	end

	timer.Simple(0, trySpawn)

	return true

end

function attachCannonSmoke(ent, bpos, data_att, custom_particle, tracerSourcePos)

	if not cv_smoke:GetBool() then return end

	if not IsValid(ent) or not isvector(bpos) then return end

	-- For cannon smoke, validate/choose the attachment around the tracer source point

	-- because that is the actual barrel center LVS used for this shot. The muzzle

	-- EffectData origin can drift while aiming up/down and made smoke fall back to id 0.

	local attachCenter = isvector(tracerSourcePos) and tracerSourcePos or bpos

	local pName = custom_particle or "vj_smoke_white_narrow"

	pcall(PrecacheParticleSystem, pName)

	

	if ent._lvs_gred_smoke_pcf and IsValid(ent._lvs_gred_smoke_pcf) then

		pcall(function() ent._lvs_gred_smoke_pcf:StopEmission(false) end)

	end

	-- Trust the tracer-derived attachment ID without proximity re-validation.

	-- The tracer already proved this is the correct barrel attachment for this shot.

	-- Re-validating with validSmokeAttachment (64-unit proximity) can reject the

	-- correct ID due to client interpolation timing and fall back to

	-- nearestSmokeAttachment, which may pick a WRONG attachment on multi-barrel

	-- vehicles. Only fall back to proximity search when no tracer ID was provided.

	local att = tonumber(data_att) or 0

	if att > 0 and IsValid(ent) and ent.GetAttachment then

		if ent.SetupBones then pcall(ent.SetupBones, ent) end

		if not ent:GetAttachment(att) then att = 0 end

	end

	if att <= 0 then att = nearestSmokeAttachment(ent, attachCenter) end

	local ok, smk_psys

	if att > 0 then

		ok, smk_psys = pcall(CreateParticleSystem, ent, pName, PATTACH_POINT_FOLLOW, att, vector_origin)

	end

	if not ok or not smk_psys then

		-- Do NOT fall back to any entity attachment type using attachment id 0. After

		-- using the toolgun, some clients report stale/invalid attachment state and id 0

		-- snaps the smoke to the vehicle base. If no verified barrel attachment exists,

		-- spawn the smoke at the muzzle world position and stop emission after 2.5s.

		if cv_debug:GetBool() then

			print("[lvs_gred_fx] barrel smoke using world-position fallback; invalid attachment", tostring(data_att))

		end

		if timedPfx(pName, bpos, Angle(0, 0, 0), 2.5) then return end

		pfx(pName, bpos, Angle(0, 0, 0))

		return

	end

	ent._lvs_gred_smoke_pcf = smk_psys

	ent._lvs_gred_smoke_bonefix_until = CurTime() + 2.5

	local hookName = "LVS_SmokeBoneFix_" .. ent:EntIndex()

	hook.Add("Think", hookName, function()

		if not IsValid(ent) or (ent._lvs_gred_smoke_bonefix_until or 0) < CurTime() then

			hook.Remove("Think", hookName)

			return

		end

		ent:SetupBones()

	end)

	timer.Simple(2.5, function()

		if IsValid(smk_psys) and smk_psys.StopEmission then pcall(function() smk_psys:StopEmission(false) end) end

		if IsValid(ent) and ent._lvs_gred_smoke_pcf == smk_psys then ent._lvs_gred_smoke_pcf = nil end

	end)

end

-- Core LVS Effect Lifecycle

-- Tracers and laser beams are NOT overridden (not in effect_list). The original

-- LVS tracer/laser effects play without any wrapper interference. The util.Effect

-- hook below records tracers for muzzle-flash pairing without overriding them.

-- Missile/Rocket Trails (ATTACHED)

ENT_TRAIL = {

	lvs_missiletrail = { "rockettrail", Vector(-8, 0, 0) },

	lvs_concussion_trail = { "grenadetrail", vector_origin },

	lvs_proton_trail = { "weapon_tracers_smoke", vector_origin },

}

local function isFireTrailDebrisCandidate(ent, fallback)

	if not IsValid(ent) or ent == fallback then return false end

	if ent:IsPlayer() or ent:IsNPC() or ent:IsWeapon() then return false end

	local class = ent:GetClass() or ""

	if class == "worldspawn" then return false end

	-- Prefer actual debris/physics pieces over the original vehicle base. Normal LVS

	-- destruction can send lvs_firetrail with the vehicle/base entity instead of the

	-- spawned debris entity, which made PATTACH_POINT_FOLLOW bind to a random base

	-- attachment. Nearby physical debris is the correct target.

	if class:find("gib", 1, true) or class:find("debris", 1, true) or class:find("part", 1, true) then return true end

	if class == "prop_physics" or class == "prop_physics_multiplayer" then return true end

	local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil

	return IsValid(phys)

end

local function findFireTrailTarget(fallback, pos)

	local bestEnt

	local bestDist = math.huge

	if ents and ents.FindInSphere and isvector(pos) then

		local found = ents.FindInSphere(pos, 256)

		for i = 1, #found do

			local ent = found[i]

			if isFireTrailDebrisCandidate(ent, fallback) then

				local dist = ent:GetPos():DistToSqr(pos)

				if dist < bestDist then

					bestDist = dist

					bestEnt = ent

				end

			end

		end

	end

	if IsValid(bestEnt) then return bestEnt end

	return IsValid(fallback) and fallback or nil

end

local function validFireTrailAttachment(ent, att, pos)

	att = tonumber(att) or 0

	if att <= 0 or not IsValid(ent) or not ent.GetAttachment then return 0 end

	local attData = ent:GetAttachment(att)

	if not attData then return 0 end

	-- If the attachment is nowhere near the effect origin, it is almost certainly a

	-- base-vehicle attachment id and not the debris trail point.

	if isvector(pos) and attData.Pos:DistToSqr(pos) > 65536 then return 0 end -- 256 units

	return att

end

local function initFireTrail(self, data)

	-- LVS uses lvs_firetrail for destroyed vehicle/debris fire trails. Replace the

	-- default LVS sprite/emitter effect with a Gred rocket trail. Use POINT_FOLLOW

	-- only when LVS gives a valid debris attachment; otherwise follow the debris

	-- origin at the effect offset so it does not attach to a random vehicle-base id.

	self._gmode = "enttrail"

	self._softStopTrail = true

	local fallback = data:GetEntity()

	local pos = data:GetOrigin()

	local ent = findFireTrailTarget(fallback, pos)

	self._gent = ent

	if not IsValid(ent) or not enabled() then return false end

	local pcf = "rockettrail"

	pcall(PrecacheParticleSystem, pcf)

	local att = validFireTrailAttachment(ent, data:GetAttachment(), pos)

	local attachType = PATTACH_ABSORIGIN_FOLLOW

	local attachID = 0

	local offset = isvector(pos) and ent:WorldToLocal(pos) or vector_origin

	if att > 0 then

		attachType = PATTACH_POINT_FOLLOW

		attachID = att

		offset = vector_origin

	end

	local oldAllow = LVS_GRED_FX_ALLOW_OWN_PARTICLE

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = true

	local ok, psys = pcall(CreateParticleSystem, ent, pcf, attachType, attachID, offset)

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = oldAllow

	if ok and psys then

		self._psys = psys

		return true

	end

	return false

end

local function initEntTrail(name, self, data)

	self._gmode = "enttrail"

	local ent = data:GetEntity()

	self._gent = ent

	if not IsValid(ent) or not enabled() then return end

	local t = ENT_TRAIL[name] or { "weapon_tracers_smoke", vector_origin }

	local pcf, off = t[1], t[2]

	pcall(PrecacheParticleSystem, pcf)

	local oldAllow = LVS_GRED_FX_ALLOW_OWN_PARTICLE

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = true

	-- Use PATTACH_ABSORIGIN_FOLLOW to keep the trail locked to the entity origin + offset

	local ok, psys = pcall(CreateParticleSystem, ent, pcf, PATTACH_ABSORIGIN_FOLLOW, 0, off)

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = oldAllow

	if ok and psys then self._psys = psys end

end

local function thinkEntTrail(self)

	if not enabled() or not IsValid(self._gent) then 

		if self._psys and self._psys.StopEmission then

			-- Stop emitting and let existing particles fade naturally. The wrapper now

			-- uses the original LVS Think result as the authoritative lifetime where

			-- available, so this runs exactly when LVS says the effect is over.

			pcall(function() self._psys:StopEmission(false, false) end)

			self._psys = nil

		end

		return false 

	end

	return true

end

-- Charging effects

local function initLaserCharge(self, data)

	self._gmode, self._gent, self._gatt, self._gdie, self._gnext = "laserchg", data:GetEntity(), data:GetAttachment(), CurTime() + 0.35, 0

end

local function thinkLaserCharge(self)

	if not enabled() or (self._gdie or 0) < CurTime() or not IsValid(self._gent) then return false end

	if CurTime() < (self._gnext or 0) then return true end

	self._gnext = CurTime() + 0.04

	local att = self._gent:GetAttachment(self._gatt or 0)

	if att then pfx("muzzleflash_sparks_variant_6", att.Pos, att.Ang) end

	return true

end

-- One-Shot Dispatcher

-- Attached fire lifecycle (car engine fire, fuel-tank fire).

-- These LVS effects are spawned on a vehicle/projectile entity and persist briefly

-- via a DieTime-based Think. Attach the Gredwitch fire/flame particle to the entity

-- with PATTACH_ABSORIGIN_FOLLOW so it stays locked to the burning body, and stop

-- emission when the effect's lifetime ends.

local function initEntFire(name, self, data)

	self._gmode = "entfire"

	local ent = data:GetEntity()

	self._gent = ent

	-- Match the original LVS LifeTime (1s for car engine/fuel-tank fire). LVS re-fires

	-- the effect periodically while the vehicle is still burning, so each instance is

	-- short-lived and a fresh particle is attached on each re-fire.

	self._gdie = CurTime() + 1

	if not IsValid(ent) or not enabled() then return false end

	-- fuel-tank fire is the larger blaze (fire_large_01); engine fire is a smaller

	-- sustained burn (fire_jet_01). Do NOT use flame_jet for engine fire — that is the

	-- ammorack fire particle, and using it makes a simple engine fire look like the

	-- vehicle got ammoracked. All three fire particles are now visually distinct:

	--   ammorack  = flame_jet       (violent jet, unchanged)
	--   engine    = fire_jet_01     (sustained burn, distinct from ammorack)
	--   fuel tank = fire_large_01   (large blaze)

	local pcf = name == "lvs_carfueltank_fire" and "fire_large_01" or "fire_jet_01"

	pcall(PrecacheParticleSystem, pcf)

	-- Position the fire at the engine/fuel-tank location, not the vehicle origin.

	-- LVS sets data:GetOrigin() to the engine entity's world position and

	-- data:GetEntity() to the base vehicle. Convert the world position to a local

	-- offset on the vehicle so the fire follows the vehicle at the correct spot —

	-- exactly like the original LVS effect (Ent:WorldToLocal(Pos + randomPos)).

	local firePos = data:GetOrigin() or ent:GetPos()

	local offset = ent:WorldToLocal(firePos)

	local oldAllow = LVS_GRED_FX_ALLOW_OWN_PARTICLE

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = true

	local ok, psys = pcall(CreateParticleSystem, ent, pcf, PATTACH_ABSORIGIN_FOLLOW, 0, offset)

	LVS_GRED_FX_ALLOW_OWN_PARTICLE = oldAllow

	if ok and psys then self._psys = psys end

	return true

end

local function thinkEntFire(self)

	if not enabled() or (self._gdie or 0) < CurTime() or not IsValid(self._gent) then

		if self._psys and self._psys.StopEmission then

			pcall(function() self._psys:StopEmission(false, false) end)

			self._psys = nil

		end

		return false

	end

	return true

end


local function dispatchOneShot(name, self, data)

	local pos, nrm, mag, ent, att = data:GetOrigin(), data:GetNormal(), data:GetMagnitude(), data:GetEntity(), data:GetAttachment()

	if cv_debug:GetBool() then

		print("[lvs_gred_fx] dispatch:", name, "ent:", IsValid(ent) and ent:GetClass() or "none", "mag:", mag)

	end

	-- Record ANY explosion-type effect for AP overlap suppression. LVS

	-- autocannons/cannons fire both an explosion (splash damage, on collision)

	-- and lvs_bullet_impact_ap (on the next tracer Think) at the same spot. The

	-- explosion effect name varies by weapon: lvs_bullet_impact_explosive (pak40,
	-- turrets), lvs_defence_explosion (flak), etc. Catch them all generically so
	-- the suppression is not weapon-specific and does not depend on magnitude
	-- (which is the same for every weapon).

	if name:find("explosion", 1, true) or name:find("explosive", 1, true) then

		RECENT_EXPLOSIONS[#RECENT_EXPLOSIONS + 1] = { pos = pos, time = CurTime() }

		if cv_debug:GetBool() then print("[lvs_gred_fx] recorded explosion at:", pos, "name:", name) end

	end

	-- lvs_defence_explosion gets a dedicated wider-window entry so the AP impact
	-- that follows is always suppressed, regardless of position drift.

	if name == "lvs_defence_explosion" then

		RECENT_DEFENCE_EXPLOSIONS[#RECENT_DEFENCE_EXPLOSIONS + 1] = { pos = pos, time = CurTime() }

	end

	if name == "lvs_explosion" then

		pfx("doi_flak88_explosion", pos, nrm and nrm:Angle())

		sound.Play("LVS.DYNAMIC_EXPLOSION", pos, 140, 100, 1)

	elseif name == "lvs_explosion_bomb" then

		pfx("doi_flak88_explosion", pos, nrm and nrm:Angle())

		sound.Play("LVS.DYNAMIC_EXPLOSION", pos, 140, 100, 1)

	elseif name == "lvs_explosion_small" or name == "lvs_explosion_nodebris" then

		pfx("ins_rpg_explosion", pos, nrm and nrm:Angle())

	elseif name == "lvs_trailer_explosion" then

		pfx("gred_40mm", pos, Angle(0, 0, 0))

	elseif name == "lvs_defence_explosion" then

		pfx("gred_20mm", pos, nrm and nrm:Angle())

	elseif name == "lvs_concussion_explosion" or name == "lvs_proton_explosion" then

		pfx("napalm_explosion_midair", pos, Angle(0, 0, 0))

	elseif name:find("lvs_laser_explosion", 1, true) then

		pfx("high_explosive_air_2", pos, Angle(0, 0, 0))

	elseif name == "lvs_bullet_impact_explosive" then

		-- HE hit: caliber-specific explosion (never shares particle with AP)
		local cal = getEntityCaliber(ent)
		heImpactAt(pos, nrm, cal)

	elseif name == "lvs_bullet_impact_ap" then

		-- LVS autocannons/cannons fire BOTH a splash explosion (on collision) and
		-- lvs_bullet_impact_ap (on the tracer Think when the bullet ends) at the same
		-- spot. From debug logs, the AP impact fires FIRST and the explosion fires
		-- ~1 frame later. So a "check past explosions" approach always misses.
		--
		-- Fix: DEFER the AP particle by 0.1s. During that window, if ANY explosion
		-- fires at approximately the same position, cancel the AP particle. If no
		-- explosion fires, spawn the AP particle. This is purely position+time based
		-- (not magnitude — every weapon uses the same mag) and works for all
		-- explosion effect names.

		local apPos = pos
		local apNrm = nrm

		-- Get caliber from the entity's last tracer for a caliber-appropriate AP hit
		local apCal = getEntityCaliber(ent)

		if cv_debug:GetBool() then print("[lvs_gred_fx] AP impact deferred 0.1s at:", apPos, "cal:", apCal) end

		timer.Simple(0.1, function()

			if not enabled() then return end

			local now = CurTime()

			local cancelled = false

			-- Check dedicated lvs_defence_explosion tracker FIRST with a wide window.
			-- lvs_defence_explosion should NEVER play an AP impact replacement.

			for i = #RECENT_DEFENCE_EXPLOSIONS, 1, -1 do

				local entry = RECENT_DEFENCE_EXPLOSIONS[i]

				if (now - entry.time) > 1.5 then

					table.remove(RECENT_DEFENCE_EXPLOSIONS, i)

				elseif apPos:DistToSqr(entry.pos) < 250000 then -- within 500 units

					cancelled = true

					if cv_debug:GetBool() then print("[lvs_gred_fx] AP impact cancelled (defence explosion)") end

					break

				end

			end

			-- Fall back to generic explosion check (0.5s / 300 units).

			if not cancelled then

				for i = #RECENT_EXPLOSIONS, 1, -1 do

					local entry = RECENT_EXPLOSIONS[i]

					if (now - entry.time) > 0.5 then

						table.remove(RECENT_EXPLOSIONS, i)

					elseif apPos:DistToSqr(entry.pos) < 90000 then -- within 300 units

						cancelled = true

						if cv_debug:GetBool() then print("[lvs_gred_fx] AP impact cancelled (explosive overlap)") end

						break

					end

				end

			end

			if not cancelled then

				if cv_debug:GetBool() then print("[lvs_gred_fx] AP impact replacement fired (deferred)") end

				-- Use Gredwitch's own surface-aware impact particle for autocannon AP.
				-- gred_particle_impact handles rotation, surface material, decals, and
				-- caliber-appropriate particles correctly — everything we failed at manually.
				-- For 40mm+ tank AP, use the dedicated tank AP spark instead.
				if apCal == "40mm" then
					pfx("gred_ap_impact", apPos + (apNrm or vector_up) * 2, (apNrm or vector_up):Angle())
				else
					-- Use 12mm caliber for autocannon AP so gred_particle_impact
					-- plays doi_gunrun_impact — visually distinct from gred_20mm (HE)
					-- but same scale, with proper surface-relative rotation.
					gredImpact(apPos, apNrm, "12mm")
				end

			end

		end)

		return true

	elseif name == "lvs_bullet_impact" then

		-- Generic bullet hitting a surface: use Gredwitch's own surface-aware impact.
		-- This replaces the manual ins_impact_* particle spawning that had rotation issues.
		local cal = getEntityCaliber(ent)
		gredImpact(pos, nrm, cal)

	elseif name == "lvs_laser_impact" then

		pfx("high_explosive_air_2", pos, Angle(0, 0, 0))

	elseif name == "lvs_shield_impact" then

		pfx("AP_impact_wall", pos, nrm and nrm:Angle())

	elseif name == "lvs_haubitze_muzzle" then

		LVS_GRED_FX.SuppressMuzzleFlash(0.12)

		-- Spawn the Gredwitch muzzle flash for the haubitze
		spawnTracerMatchedMuzzle(ent, pos, nrm and nrm:Angle(), "gred_arti_muzzle_blast_alt", true, att, "vj_smoke_white_medium")

		-- Spawn a static Gredwitch tracer beam for the haubitze
		if enabled() and nrm then
			local pcf = "gred_tracers_white_40mm"
			pcall(PrecacheParticleSystem, pcf)
			local tr = util.TraceLine({ start = pos, endpos = pos + nrm * 99999, mask = MASK_SHOT + MASK_WATER })
			local endpos = tr.HitPos or (pos + nrm * 10000)
			local oldAllow = LVS_GRED_FX_ALLOW_OWN_PARTICLE
			LVS_GRED_FX_ALLOW_OWN_PARTICLE = true
			local ok, psys = pcall(CreateParticleSystem, game.GetWorld(), pcf, PATTACH_WORLDORIGIN, 0, pos)
			LVS_GRED_FX_ALLOW_OWN_PARTICLE = oldAllow
			if ok and psys then
				psys:SetControlPoint(1, endpos)
				local lifetime = math.Clamp(pos:DistToSqr(endpos) * 6.8 / (24000 * 24000), 0.05, 0.5)
				timer.Simple(lifetime, function() if psys and psys.StopEmission then pcall(function() psys:StopEmission(false, true) end) end end)
			end
		end
		return true

	elseif name == "lvs_muzzle" or name == "lvs_muzzle_colorable" then

		LVS_GRED_FX.SuppressMuzzleFlash(0.12)

		-- Keep the tracer->muzzle pairing: after the matching tracer starts,
		-- LAST_TRACER[ent] decides both which PCF is used and which attachment id is
		-- allowed for PATTACH_POINT_FOLLOW. No EffectData attachment and no nearest-id
		-- guessing is used for muzzleflashes.

		return spawnTracerMatchedMuzzle(ent, pos, nrm and nrm:Angle(), nil, true, att)

	elseif name == "lvs_pulserifle_muzzle" then

		LVS_GRED_FX.SuppressMuzzleFlash(0.12)

		return spawnTracerMatchedMuzzle(ent, pos, nrm and nrm:Angle(), "muzzleflash_mg42_3p", false, att)

	elseif name == "lvs_defence_smoke" then

		-- Defence smoke: single short puff. Throttled by position to prevent spam.
		local throttleKey = math.Round(pos.x / 50) * 50 .. "_" .. math.Round(pos.y / 50) * 50
		if LVS_GRED_FX._lastSmokePos and LVS_GRED_FX._lastSmokePos[throttleKey] and LVS_GRED_FX._lastSmokePos[throttleKey] > CurTime() then
			return true
		end
		if not LVS_GRED_FX._lastSmokePos then LVS_GRED_FX._lastSmokePos = {} end
		LVS_GRED_FX._lastSmokePos[throttleKey] = CurTime() + 3
		timedPfx("m203_smokegrenade", pos, Angle(0, 0, 0), 2)

	elseif name == "lvs_walker_stomp" then

		pfx("doi_ceilingDust_large", pos, Angle(0, 0, 0))

		pfx("ins_rpg_explosion", pos + Vector(0, 0, 8), Angle(0, 0, 0))

	elseif name == "lvs_rotor_destruction" then

		pfx("high_explosive_air_2", pos, Angle(0, 0, 0))

	elseif name == "lvs_tire_blow" then

		pfx("doi_ceilingDust_large", pos, Angle(0, 0, 0))

	elseif name == "lvs_trailer_flak" then

		-- Flak airburst. Gredwitch's own 20mm/30mm/40mm airburst particles are the
		-- correct visual for an LVS flak trailer detonating in the air.

		pfx("gred_20mm_airburst", pos, Angle(90, 0, 0))

		pfx("gred_40mm_airburst", pos, Angle(90, 0, 0))

	elseif name == "lvs_truck_exhaust" then

		-- Short diesel smoke puff at the exhaust port. LVS gates this on throttle/RPM;
		-- the replacement just plays the smoke at the position LVS chose.

		timedPfx("vj_smoke_white_narrow", pos, nrm and nrm:Angle() or Angle(0, 0, 0), 1.2)

	elseif name == "lvs_hover_water" or name == "lvs_physics_water" or name == "lvs_physics_wheelwatersplash" then

		-- Hovercraft / wheel water spray. Gredwitch water_small is the small splash.

		pfx("water_small", pos, nrm and nrm:Angle() or Angle(0, 0, 0))

	elseif name == "lvs_physics_water_advanced" then

		pfx("water_medium", pos, nrm and nrm:Angle() or Angle(0, 0, 0))

	elseif name == "lvs_physics_scrape" or name == "lvs_physics_trackscraping" or name == "lvs_physics_turretscraping" then

		-- Metal-on-ground scraping sparks. muzzleflash_sparks_variant_6 is the Gredwitch
		-- spark burst used for charge/muzzle sparks and reads well as scrape sparks.

		pfx("muzzleflash_sparks_variant_6", pos, nrm and nrm:Angle() or Angle(0, 0, 0))

	elseif name:find("explosion", 1, true) then

		pfx("ins_rpg_explosion", pos, nrm and nrm:Angle())

	elseif name:find("muzzle", 1, true) then

		LVS_GRED_FX.SuppressMuzzleFlash(0.12)

		timer.Simple(0, function()

			if not enabled() then return end

			muzzleDOIAttached(ent, pos, nrm and nrm:Angle(), pickMuzzleAttachment(ent, pos), att)

		end)

		return true

	else

		return false

	end

end

-- Tracer Recording Hook (no override)

-- Record tracers for muzzle-flash pairing WITHOUT overriding the tracer effects.

-- LVS fires util.Effect(bullet.TracerName, effectdata) with the bullet index in

-- data:GetMaterialIndex(). We intercept that call, look up the bullet to get the

-- firing entity and source position, call noteTracerFor() so the next muzzle flash

-- can pair with the correct PCF and attachment, then let the original util.Effect

-- run so the original LVS tracer plays normally. No tracer effects are overridden.
do

	-- Save the stock util.Effect only once (before any hook is installed).
	-- bridge.lua is include()'d multiple times (InitPostEntity + timers), so the
	-- hook must be re-installed each time to reference the current local
	-- functions (noteTracerFor, resolveMuzzleEntity, isTracerName) and the
	-- current local LAST_TRACER table. Always call the stock function to avoid
	-- nested hook chains.

	_LVS_GRED_FX_STOCK_EFFECT = _LVS_GRED_FX_STOCK_EFFECT or util.Effect

	local _stockEffect = _LVS_GRED_FX_STOCK_EFFECT

	function util.Effect(name, data, ...)

		if isstring(name) and isTracerName(name) and data and data.GetMaterialIndex and LVS and LVS.GetBullet then

			local gid = data:GetMaterialIndex()

			local bullet = LVS:GetBullet(gid)

			if bullet and bullet.Entity and IsValid(bullet.Entity) then

				local srcPos = data:GetOrigin()

				if bullet.SrcEntity and isvector(bullet.SrcEntity) then

					srcPos = bullet.Entity:LocalToWorld(bullet.SrcEntity)

				end

				local recordEnt = resolveMuzzleEntity(bullet.Entity)

				if cv_debug:GetBool() then

					print("[lvs_gred_fx] tracer recorded:", name, "ent:", tostring(recordEnt), "srcPos:", srcPos)

				end

				noteTracerFor(recordEnt, name, srcPos)

			end

		end

		return _stockEffect(name, data, ...)

	end

end

-- Public Interface

function LVS_GRED_FX.Init(name, self, data)

	self._gname = name

	if not enabled() then return false end

	if name == "lvs_firetrail" then return initFireTrail(self, data) end

	if ENT_TRAIL[name] then return initEntTrail(name, self, data) end

	if name == "lvs_laser_charge" then return initLaserCharge(self, data) end

	-- Attached fire / flamethrower effects: route to the dedicated PATTACH_ABSORIGIN_FOLLOW

	-- lifecycle so the Gredwitch fire/flame particle stays locked to the burning body.

	if name == "lvs_carengine_fire" or name == "lvs_carfueltank_fire" then return initEntFire(name, self, data) end

	if name:find("lvs_ammorack_fire", 1, true) then 
		local ent = data:GetEntity()
		if IsValid(ent) and not AMMORACK_ACTIVE[ent] then 
			pcall(PrecacheParticleSystem, "flame_jet")
			local oldAllow = LVS_GRED_FX_ALLOW_OWN_PARTICLE
			LVS_GRED_FX_ALLOW_OWN_PARTICLE = true
			local ok, psys = pcall(CreateParticleSystem, ent, "flame_jet", PATTACH_ABSORIGIN_FOLLOW, 0, vector_origin)
			LVS_GRED_FX_ALLOW_OWN_PARTICLE = oldAllow
			if ok and psys then AMMORACK_ACTIVE[ent] = { psys = psys } end
		end
		return 
	end

	-- Tracers: route to the modular tracer system (Gredwitch-style beam particles).
	if isTracerName(name) then return LVS_GRED_FX_TRACER.Init(name, self, data) end

	return dispatchOneShot(name, self, data)

end

function LVS_GRED_FX.Think(name, self)

	if not enabled() then return false end

	if self._gmode == "enttrail" then return thinkEntTrail(self) end

	if self._gmode == "laserchg" then return thinkLaserCharge(self) end

	if self._gmode == "entfire" then return thinkEntFire(self) end

	if self._gmode == "tracer_oneshot" then return LVS_GRED_FX_TRACER.Think(self) end

	return false

end

function LVS_GRED_FX.Stop(name, self)

	-- Called by the override wrapper when the original LVS effect lifetime ends.
	-- Stop emission instead of removing instantly so trails/smoke fade naturally.

	if self and self._psys and self._psys.StopEmission then

		pcall(function() self._psys:StopEmission(false, false) end)

		self._psys = nil

	end

	-- Tracer cleanup
	if self._gmode == "tracer_oneshot" then LVS_GRED_FX_TRACER.Stop(self) end

end

function LVS_GRED_FX.Render(name, self) end
