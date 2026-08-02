-- LVS Gredwitch FX — Ballistics Replacement (server-side)
-- LVS:FireBullet for damage/penetration, then Gredwitch tracer via gred_net_createtracer

if not SERVER then return end

LVS_GRED_FX_BALLISTICS = LVS_GRED_FX_BALLISTICS or {}

local CAL_TABLE = {
	["wac_base_7mm"] = 1, ["wac_base_12mm"] = 2, ["wac_base_20mm"] = 3,
	["wac_base_30mm"] = 4, ["wac_base_40mm"] = 5,
}
local COL_TABLE = { ["red"] = 1, ["green"] = 2, ["white"] = 3, ["yellow"] = 4 }
local TRACER_MAP = {
	lvs_tracer_orange = { "yellow", "20mm" }, lvs_tracer_green = { "green", "20mm" },
	lvs_tracer_yellow = { "yellow", "20mm" }, lvs_tracer_yellow_small = { "yellow", "12mm" },
	lvs_tracer_white = { "white", "20mm" }, lvs_tracer_autocannon = { "white", "30mm" },
	lvs_tracer_cannon = { "white", "40mm" }, lvs_tracer_missile = { "yellow", "30mm" },
	lvs_tracer_proton = { "white", "40mm" },
	lvs_pulserifle_tracer = { "white", "7mm" }, lvs_pulserifle_tracer_large = { "white", "12mm" },
	lvs_laser_blue = { "white", "30mm" }, lvs_laser_blue_long = { "white", "30mm" },
	lvs_laser_blue_short = { "white", "20mm" }, lvs_laser_green = { "green", "30mm" },
	lvs_laser_green_short = { "green", "20mm" }, lvs_laser_red = { "red", "30mm" },
	lvs_laser_red_aat = { "red", "40mm" }, lvs_laser_red_short = { "red", "20mm" },
}

local function ApplySpread(dir, spreadVec)
	if not spreadVec or spreadVec:LengthSqr() <= 0 then return dir end
	return (dir + VectorRand() * spreadVec * 0.5):GetNormalized()
end

-- Ballistic endpoint matching LVS's DoBulletFlight
local function BallisticEndpoint(pos, dir, velocity, enableBallistics, gravity, filter)
	if not enableBallistics then
		local tr = util.TraceLine({ start = pos, endpos = pos + dir * 99999, filter = filter, mask = MASK_SHOT + MASK_WATER })
		return tr.HitPos or (pos + dir * 10000)
	end
	local t, dt = 0, math.min(99999 / velocity / 30, 0.25)
	local prevPos, grav = pos, gravity or Vector(0, 0, -600)
	for i = 1, 200 do
		t = t + dt
		local cur = pos + dir * velocity * t + grav * t * t
		local tr = util.TraceLine({ start = prevPos, endpos = cur, filter = filter, mask = MASK_SHOT + MASK_WATER })
		if tr.Hit then return tr.HitPos end
		prevPos = cur
		if cur.z < -20000 then break end
	end
	return prevPos
end

local function TryOverrideFireBullet()
	if not LVS or not LVS.FireBullet then timer.Simple(0.5, TryOverrideFireBullet) return end
	LVS_GRED_FX_BALLISTICS._originalFireBullet = LVS_GRED_FX_BALLISTICS._originalFireBullet or LVS.FireBullet

	function LVS:FireBullet(data)
		local cv = GetConVar("lvs_gred_fx")
		if cv and not cv:GetBool() then return LVS_GRED_FX_BALLISTICS._originalFireBullet(self, data) end

		LVS_GRED_FX_BALLISTICS._originalFireBullet(self, data)

		local mapping = TRACER_MAP[data.TracerName]
		if not mapping then return end

		local color, caliberKey = mapping[1], mapping[2]
		local calID, colID = CAL_TABLE["wac_base_" .. caliberKey], COL_TABLE[color]
		if not calID or not colID then return end

		local pos = data.Src or vector_origin
		local dir = ApplySpread(data.Dir or Vector(1, 0, 0), data.Spread)
		local filter = data.Entity
		if data.Entity and data.Entity.GetCrosshairFilterEnts then filter = data.Entity:GetCrosshairFilterEnts() end

		local endpos = BallisticEndpoint(pos, dir, data.Velocity or 2500, data.EnableBallistics == true, data.EnableBallistics and physenv.GetGravity() or nil, filter)

		net.Start("gred_net_createtracer")
			net.WriteVector(pos)
			net.WriteUInt(calID, 3)
			net.WriteUInt(colID, 3)
			net.WriteVector(endpos)
		net.Broadcast()
	end
end

hook.Add("InitPostEntity", "lvs_gred_fx_ballistics", TryOverrideFireBullet)
TryOverrideFireBullet()
