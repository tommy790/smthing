
ENT.Base = "lvs_tank_wheeldrive"

ENT.PrintName = "Type 4 O-Ro"
ENT.Author = "Терпилкинс"
ENT.Information = "Сарай №1"
ENT.Category = "[LVS] - Cars"

ENT.VehicleCategory = "Tanks"
ENT.VehicleSubCategory = "Heavy"

ENT.Spawnable			= true
ENT.AdminSpawnable		= false

ENT.MDL = "models/japan/Type 4 O-Ro.mdl"

ENT.AITEAM = 1

ENT.MaxHealth = 4500
ENT.MaxHealthFuelTank = 1300

ENT.DSArmorIgnoreForce = 1000

ENT.SteerSpeed = 1
ENT.SteerReturnSpeed = 2

ENT.PhysicsWeightScale = 4
ENT.PhysicsDampingSpeed = 1000
ENT.PhysicsInertia = Vector(6000,6000,1500)

ENT.MaxVelocity = 250
ENT.MaxVelocityReverse = 100

ENT.EngineCurve = 0.1
ENT.EngineTorque = 150

ENT.TransMinGearHoldTime = 0.1
ENT.TransShiftSpeed = 0

ENT.TransGears = 6
ENT.TransGearsReverse = 2

ENT.MouseSteerAngle = 45

ENT.lvsShowInSpawner = true

ENT.ProjectileVelocity = 15000
ENT.ProjectileVelocity57 = 17000
ENT.CannonArmorPenetration = 25700
ENT.CannonArmorPenetration1km = 23500
ENT.ProjectileDamageAP = 3200
ENT.ProjectileDamageHE = 4000
ENT.ProjectileExplosiveRadius = 850
ENT.CannonExplosivePenetration = 3000

function ENT:OnSetupDataTables()
	self:AddDT( "Bool", "UseHighExplosive" )
end

function ENT:GetAimVector()
	if self:GetAI() then
		return self:GetAIAimVector()
	end

	local pod = self:GetDriverSeat()

	if not IsValid( pod ) then return self:GetForward() end

	local Driver = self:GetDriver()

	if not IsValid( Driver ) then return pod:GetForward() end

	if SERVER then
		return pod:WorldToLocalAngles( Driver:EyeAngles() ):Forward()
	else
		return Driver:EyeAngles():Forward()
	end
end

function ENT:GunnerInRange( Dir )
	local pod = self:GetDriverSeat()

	if IsValid( pod ) and not pod:GetThirdPersonMode() then
		local ply = pod:GetDriver()

		if IsValid( ply ) and ply:lvsKeyDown( "ZOOM" ) then
			return true
		end
	end

	return self:AngleBetweenNormal( self:GetForward(), Dir ) < 60
end

function ENT:InitWeapons()
	local COLOR_WHITE = Color(255,255,255,255)
	
	-- Main turret
	local weapon = {}
	weapon.Icon = true
	weapon.Ammo = 25
	weapon.Delay = 20
	weapon.HeatRateUp = 1
	weapon.HeatRateDown = 0.05
	weapon.Attack = function( ent )
		local ID = ent:LookupAttachment( "muzzle" )

		local Muzzle = ent:GetAttachment( ID )

		if not Muzzle then return end

		local bullet = {}
		bullet.Src 	= Muzzle.Pos
		bullet.Dir 	= Muzzle.Ang:Forward()
		bullet.Spread = Vector(0,0,0)
		bullet.EnableBallistics = true

		if ent:GetUseHighExplosive() then
			bullet.SplashDamageForce = ent.CannonExplosivePenetration
			bullet.HullSize 	= 5
			bullet.SplashDamage = ent.ProjectileDamageHE
			bullet.SplashDamageRadius = ent.ProjectileExplosiveRadius
			bullet.SplashDamageEffect = "lvs_bullet_impact_explosive"
			bullet.SplashDamageType = DMG_BLAST
			bullet.Velocity = ent.ProjectileVelocity
		else
			-- APHE
			bullet.Force	= ent.CannonArmorPenetration
			bullet.Force1km	= ent.CannonArmorPenetration1km
			bullet.HullSize 	= 0
			bullet.Damage	= ent.ProjectileDamageAP
			bullet.Velocity = ent.ProjectileVelocity
		end

		bullet.TracerName = "lvs_tracer_cannon"
		bullet.Attacker = ent:GetDriver()
		ent:LVSFireBullet( bullet )

		local effectdata = EffectData()
		effectdata:SetOrigin( bullet.Src )
		effectdata:SetNormal( bullet.Dir )
		effectdata:SetEntity( ent )
		util.Effect( "lvs_muzzle", effectdata )

		local PhysObj = ent:GetPhysicsObject()
		if IsValid( PhysObj ) then
			PhysObj:ApplyForceOffset( -bullet.Dir * 150000, bullet.Src )
		end

		ent:TakeAmmo( 1 )
		
		ent:PlayAnimation( "main_fire" )

		if not IsValid( ent.SNDTurret ) then return end

		ent.SNDTurret:PlayOnce( 100 + math.cos( CurTime() + ent:EntIndex() * 1337 ) * 5 + math.Rand(-1,1), 1 )

		--ent:EmitSound(self.CannonReloadSound, 75, 100, 1, CHAN_WEAPON )
	end

	weapon.OnThink = function( ent, active )		
		
		if ent:GetSelectedWeapon() ~= 1 then return end

		local ply = ent:GetDriver()

		if not IsValid( ply ) then return end

		local SwitchType = ply:lvsKeyDown( "CAR_SWAP_AMMO" )

		if ent._oldSwitchType ~= SwitchType then
			ent._oldSwitchType = SwitchType

			if SwitchType then
				ent:SetUseHighExplosive( not ent:GetUseHighExplosive() )
				ent:EmitSound("lvs/vehicles/tiger/cannon_unload.wav", 75, 100, 1, CHAN_WEAPON )
				ent:SetHeat( 1 )
				ent:SetOverheated( true )
			end
		end
	end
	
	weapon.OnSelect = function( ent )
		ent:TurretUpdateBallistics( ent.ProjectileVelocity, "muzzle" )
	end

	weapon.HudPaint = function( ent, X, Y, ply )
		
		local ID = ent:LookupAttachment( "muzzle" )

		local Muzzle = ent:GetAttachment( ID )

		if Muzzle then
			local traceTurret = util.TraceLine( {
				start = Muzzle.Pos,
				endpos = Muzzle.Pos + Muzzle.Ang:Forward() * 50000,
				filter = ent:GetCrosshairFilterEnts()
			} )

			local MuzzlePos2D = traceTurret.HitPos:ToScreen() 
			
			if ent:GetUseHighExplosive() then
				ent:PaintCrosshairSquare( MuzzlePos2D, COLOR_WHITE )
				ent:PaintCrosshairCenter( MuzzlePos2D, COLOR_WHITE )
			else
				ent:PaintCrosshairOuter( MuzzlePos2D, COLOR_WHITE )
				ent:PaintCrosshairCenter( MuzzlePos2D, COLOR_WHITE )
			end

			ent:LVSPaintHitMarker( MuzzlePos2D )
		end
	end
	self:AddWeapon( weapon )
	
	-- Hull gun
	local weapon = {}
	weapon.Icon = true
	weapon.Ammo = 60
	weapon.Delay = 3
	weapon.HeatRateUp = 1
	weapon.HeatRateDown = 0.3
	weapon.Attack = function( ent )
		local ID = ent:LookupAttachment( "hull_muzzle" )

		local Muzzle = ent:GetAttachment( ID )

		if not Muzzle then return end

		local bullet = {}
		bullet.Src 	= Muzzle.Pos
		bullet.Dir 	= Muzzle.Ang:Forward()
		bullet.Spread = Vector(0,0,0)
		bullet.Force	= 8700
		bullet.Force1km = 6800
		bullet.HullSize 	= 0
		bullet.Damage	= 900
		bullet.Velocity = ent.ProjectileVelocity57
		bullet.EnableBallistics = true

		bullet.TracerName = "lvs_tracer_cannon"
		bullet.Attacker 	= ent:GetDriver()
		ent:LVSFireBullet( bullet )

		local effectdata = EffectData()
		effectdata:SetOrigin( bullet.Src )
		effectdata:SetNormal( bullet.Dir )
		effectdata:SetEntity( ent )
		util.Effect( "lvs_muzzle", effectdata )

		local PhysObj = ent:GetPhysicsObject()
		if IsValid( PhysObj ) then
			PhysObj:ApplyForceOffset( -bullet.Dir * 50000, bullet.Src )
		end

		ent:TakeAmmo( 1 )
		
		ent:PlayAnimation( "hull_fire" )

		if not IsValid( ent.SNDRTTurret ) then return end

		ent.SNDRTTurret:PlayOnce( 100 + math.cos( CurTime() + ent:EntIndex() * 1337 ) * 5 + math.Rand(-1,1), 1 )

		ent:EmitSound("lvs/vehicles/tiger/cannon_reload.wav", 75, 100, 1, CHAN_WEAPON )
	end
	
	weapon.OnSelect = function( ent )
		if ent.SetTurretEnabled then
			ent:SetTurretEnabled( false )
		end
		ent:TurretUpdateBallistics( ent.ProjectileVelocity57, "hull_muzzle" )
	end
	
	weapon.OnDeselect = function( ent )
		if ent.SetTurretEnabled then
			ent:SetTurretEnabled( true )
		end
	end

	weapon.OnThink = function( ent, active )
		if ent:GetSelectedWeapon() == 4 then return end
		local base = ent:GetVehicle()

		if not IsValid( base ) then return end

		local AimRate = 25
		local targetAngles = ent:GetAimVector():Angle()

		local boneAnglesP = base:GetManipulateBoneAngles(2)
		local boneAnglesY = base:GetManipulateBoneAngles(1)

		local localAngles = base:WorldToLocalAngles(targetAngles)
		localAngles:Normalize()

		local newPitch = math.Clamp(math.ApproachAngle(boneAnglesP.p, localAngles.p, AimRate * FrameTime()), -15, 10)
		local newYaw = math.Clamp(math.ApproachAngle(boneAnglesY.y, localAngles.y, AimRate * FrameTime()), -10, 10)

		if IsValid(ent:GetDriver()) and ent:GetDriver():lvsKeyDown("FREELOOK") then return end
		base:ManipulateBoneAngles(2, Angle(newPitch, 0, 0))
		base:ManipulateBoneAngles(1, Angle(0, newYaw, 0))
	end
	
	weapon.HudPaint = function( ent, X, Y, ply )
		local ID = ent:LookupAttachment( "hull_muzzle" )

		local Muzzle = ent:GetAttachment( ID )

		if Muzzle then
			local traceTurret = util.TraceLine( {
				start = Muzzle.Pos,
				endpos = Muzzle.Pos + Muzzle.Ang:Forward() * 50000,
				filter = ent:GetCrosshairFilterEnts()
			} )

			local MuzzlePos2D = traceTurret.HitPos:ToScreen() 
			ent:PaintCrosshairCenter( MuzzlePos2D, COLOR_WHITE )
			ent:LVSPaintHitMarker( MuzzlePos2D )
		end
	end
	
	weapon.CalcView = function( ent, ply, pos, angles, fov, pod )
		if not pod:GetThirdPersonMode() then
		   if ply:lvsKeyDown("ZOOM") then
				local ID = self:LookupAttachment( "hull_sight" )
				local Attachment = self:GetAttachment( ID )
				local view = {}
				view.origin = Attachment.Pos -- Attachment.Ang:Forward() * 10 + Attachment.Ang:Up() * 0.5
				view.angles = Attachment.Ang
				view.fov = 60
				view.drawviewer = true
				return view	
			else
				local ID = self:LookupAttachment( "hull_sight" )
				local Attachment = self:GetAttachment( ID )
				local view = {}
				view.origin = Attachment.Pos -- Attachment.Ang:Forward() * 25 + Attachment.Ang:Up() * 2
				view.angles = Attachment.Ang
				view.fov = 90
				view.drawviewer = true
				return view	
			end
		else
			local ID = self:LookupAttachment( "turret" )
			local Attachment = self:GetAttachment( ID )
			return self:LVSCalcView( ply, Attachment.Pos, angles, fov, pod )
		end
	end
	self:AddWeapon( weapon )
	
	-- Machine gun
	local weapon = {}
	weapon.Icon = Material("lvs/weapons/mg.png")
	weapon.Ammo = 6000
	weapon.Delay = 0.15
	weapon.HeatRateUp = 0.2
	weapon.HeatRateDown = 0.3
	weapon.Attack = function( ent )
		local ID = ent:LookupAttachment( "muzzle_coax" )

		local Muzzle = ent:GetAttachment( ID )

		if not Muzzle then return end

		local bullet = {}
		bullet.EnableBallistics = true
		bullet.Src 	= Muzzle.Pos
		bullet.Dir 	= Muzzle.Ang:Forward()
		bullet.Spread 	= Vector(0.015,0.015,0.015)
		bullet.TracerName = "lvs_tracer_yellow"
		bullet.Force	= 10
		bullet.HullSize 	= 0
		bullet.Damage	= 25
		bullet.Velocity = 25000
		bullet.Attacker 	= ent:GetDriver()
		ent:LVSFireBullet( bullet )
		
		local effectdata = EffectData()
		effectdata:SetOrigin( bullet.Src )
		effectdata:SetNormal( bullet.Dir )
		effectdata:SetEntity( ent )
		util.Effect( "lvs_muzzle", effectdata )

		ent:TakeAmmo( 1 )
	end
	weapon.StartAttack = function( ent )
		if not IsValid( ent.SNDTurretMG ) then return end
		ent.SNDTurretMG:Play()
	end
	weapon.FinishAttack = function( ent )
		if not IsValid( ent.SNDTurretMG ) then return end
		ent.SNDTurretMG:Stop()
	end
	
	weapon.OnSelect = function( ent )
		if ent.SetTurretEnabled then
			ent:SetTurretEnabled( false )
		end
		ent:TurretUpdateBallistics( 25000, "muzzle_coax" )
	end
	
	weapon.OnDeselect = function( ent )
		if ent.SetTurretEnabled then
			ent:SetTurretEnabled( true )
		end
	end

	weapon.OnThink = function( ent, active )
		if ent:GetSelectedWeapon() == 4 then return end
		local base = ent:GetVehicle()

		if not IsValid( base ) then return end

		local AimRate = 25
		local targetAngles = ent:GetAimVector():Angle()

		local boneAnglesP = base:GetManipulateBoneAngles(2)
		local boneAnglesY = base:GetManipulateBoneAngles(1)

		local localAngles = base:WorldToLocalAngles(targetAngles)
		localAngles:Normalize()

		local newPitch = math.Clamp(math.ApproachAngle(boneAnglesP.p, localAngles.p, AimRate * FrameTime()), -15, 10)
		local newYaw = math.Clamp(math.ApproachAngle(boneAnglesY.y, localAngles.y, AimRate * FrameTime()), -10, 10)

		if IsValid(ent:GetDriver()) and ent:GetDriver():lvsKeyDown("FREELOOK") then return end
		base:ManipulateBoneAngles(2, Angle(newPitch, 0, 0))
		base:ManipulateBoneAngles(1, Angle(0, newYaw, 0))
	end
	
	weapon.HudPaint = function( ent, X, Y, ply )
		local ID = ent:LookupAttachment( "muzzle_coax" )

		local Muzzle = ent:GetAttachment( ID )

		if Muzzle then
			local traceTurret = util.TraceLine( {
				start = Muzzle.Pos,
				endpos = Muzzle.Pos + Muzzle.Ang:Forward() * 50000,
				filter = ent:GetCrosshairFilterEnts()
			} )

			local MuzzlePos2D = traceTurret.HitPos:ToScreen() 
			ent:PaintCrosshairCenter( MuzzlePos2D, COLOR_WHITE )
			ent:LVSPaintHitMarker( MuzzlePos2D )
		end
	end
	
	weapon.CalcView = function( ent, ply, pos, angles, fov, pod )
		if not pod:GetThirdPersonMode() then
		   if ply:lvsKeyDown("ZOOM") then
				local ID = self:LookupAttachment( "hull_sight" )
				local Attachment = self:GetAttachment( ID )
				local view = {}
				view.origin = Attachment.Pos -- Attachment.Ang:Forward() * 10 + Attachment.Ang:Up() * 0.5
				view.angles = Attachment.Ang
				view.fov = 60
				view.drawviewer = true
				return view	
			else
				local ID = self:LookupAttachment( "hull_sight" )
				local Attachment = self:GetAttachment( ID )
				local view = {}
				view.origin = Attachment.Pos -- Attachment.Ang:Forward() * 25 + Attachment.Ang:Up() * 2
				view.angles = Attachment.Ang
				view.fov = 90
				view.drawviewer = true
				return view	
			end
		else
			local ID = self:LookupAttachment( "turret" )
			local Attachment = self:GetAttachment( ID )
			return self:LVSCalcView( ply, Attachment.Pos, angles, fov, pod )
		end
	end
	self:AddWeapon( weapon )

	-- turret rotation disabler
	local weapon = {}
	weapon.Icon = Material("lvs/weapons/tank_noturret.png")
	weapon.Ammo = -1
	weapon.Delay = 0
	weapon.HeatRateUp = 0
	weapon.HeatRateDown = 0
	weapon.UseableByAI = false
	weapon.OnSelect = function( ent )
		if ent.SetTurretEnabled then
			ent:SetTurretEnabled( false )
		end
	end
	weapon.OnDeselect = function( ent )
		if ent.SetTurretEnabled then
			ent:SetTurretEnabled( true )
		end
	end
	self:AddWeapon( weapon )
end

ENT.EngineSounds = {
	{
		sound = "lvs/vehicles/tiger/eng_idle_loop.wav",
		Volume = 1,
		Pitch = 70,
		PitchMul = 30,
		SoundLevel = 75,
		SoundType = LVS.SOUNDTYPE_IDLE_ONLY,
	},
	{
		sound = "lvs/vehicles/tiger/eng_loop.wav",
		Volume = 1,
		Pitch = 30,
		PitchMul = 100,
		SoundLevel = 85,
		SoundType = LVS.SOUNDTYPE_NONE,
		UseDoppler = true,
	},
}

ENT.ExhaustPositions = {
	{effect = "lvs_truck_exhaust", pos = Vector(-216,-3,70),ang = Angle(0,-180,0),},

	{effect = "lvs_truck_exhaust",pos = Vector(-216,-3,70),ang = Angle(0,180,0),},
}

ENT.Lights = {
	{
		Trigger = "main",
		Sprites = {
			{ pos = Vector(172,-28.5,67.5), colorB = 200, colorA = 150, },
			{ pos = Vector(172,28.5,67.5), colorB = 200, colorA = 150, },
		},
		ProjectedTextures = {
			{ pos = Vector(172,-28.5,67.5), ang = Angle(0,0,0), colorB = 200, colorA = 150, shadows = true },
			{ pos = Vector(172,28.5,67.5), ang = Angle(0,0,0), colorB = 200, colorA = 150, shadows = true },
		},
	},
	{
		Trigger = "high",
		ProjectedTextures = {
			{ pos = Vector(172,-28.5,67.5), ang = Angle(0,0,0), colorB = 200, colorA = 150, shadows = true },
			{ pos = Vector(172,28.5,67.5), ang = Angle(0,0,0), colorB = 200, colorA = 150, shadows = true },
		},
	},
	{
		Trigger = "main+high",
		SubMaterialID = 7,
		Sprites = {
			{ pos = Vector(172,-28.5,67.5), colorB = 200, colorA = 150 },
			{ pos = Vector(172,28.5,67.5), colorB = 200, colorA = 150 },
		},
	},
	{
		Trigger = "brake",
		SubMaterialID = 2,
		Sprites = {
			{ pos = Vector(-204,-65,86), colorG = 0, colorB = 0, colorA = 150 },
			{ pos = Vector(-204,57,86), colorG = 0, colorB = 0, colorA = 150 },
			{ pos = Vector(-204,64,86), colorG = 0, colorB = 0, colorA = 150 },
			{ pos = Vector(-204,71,86), colorG = 0, colorB = 0, colorA = 150 },
		}
	},

}

ENT.RandomColor = {
	{
		Skin = 0,
		Color = Color(255,255,255),
	},
	{
		Skin = 1,
		Color = Color(255,255,255),
	},
	{
		Skin = 2,
		Color = Color(255,255,255),
	},
	{
		Skin = 3,
		Color = Color(255,255,255),
	},
	{
		Skin = 4,
		Color = Color(255,255,255),
	},
	-- {
		-- Skin = 5,
		-- Color = Color(255,255,255),
	-- },
	-- {
		-- Skin = 6,
		-- Color = Color(255,255,255),
	-- },
}