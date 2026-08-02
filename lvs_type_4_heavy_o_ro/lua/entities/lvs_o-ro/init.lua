AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "sh_tracks.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "sh_turret.lua" )
AddCSLuaFile( "cl_tankview.lua" )
AddCSLuaFile( "cl_optics.lua" )
include("shared.lua")
include("sh_tracks.lua")
include("sh_turret.lua")

function ENT:OnSpawn( PObj )
	
	local DriverSeat = self:AddDriverSeat( Vector(85,-40,55), Angle(0,-90,0) )
	DriverSeat.HidePlayer = true
	
	-- local HatchDRHandler = self:AddDoorHandler( "!DriverhatchR", Vector(150,-35,60), Angle(0,0,0), Vector(-20,-20,-10), Vector(15,20,15), Vector(-10,-20,-10), Vector(15,20,15) )
	-- HatchDRHandler:SetSoundOpen( "lvs/vehicles/generic/car_hood_open.wav" )
	-- HatchDRHandler:SetSoundClose( "lvs/vehicles/generic/car_hood_close.wav" )
	-- HatchDRHandler:LinkToSeat(DriverSeat)
	
	-- local TopGunnerSeat = self:AddPassengerSeat( Vector(0,0,115), Angle(0,90,0) )
	-- TopGunnerSeat.HidePlayer = true
	-- self:SetTopGunnerSeat( TopGunnerSeat )
	
	-- local HatchDLHandler = self:AddDoorHandler( "!DriverhatchL", Vector(150,35,60), Angle(0,0,0), Vector(-20,-20,-10), Vector(15,20,15), Vector(-10,-20,-10), Vector(15,20,15) )
	-- HatchDLHandler:SetSoundOpen( "lvs/vehicles/generic/car_hood_open.wav" )
	-- HatchDLHandler:SetSoundClose( "lvs/vehicles/generic/car_hood_close.wav" )
	-- HatchDLHandler:LinkToSeat(TopGunnerSeat)

	local ID = self:LookupAttachment( "muzzle" )
	local Muzzle = self:GetAttachment( ID )
	self.SNDTurret = self:AddSoundEmitter( self:WorldToLocal( Muzzle.Pos ), "cannon_150mm_type38_shot_02.wav", "cannon_02_shot-001_interior.wav" )
	self.SNDTurret:SetSoundLevel( 95 )
	self.SNDTurret:SetParent( self, ID )
	
	local ID = self:LookupAttachment( "hull_muzzle" )
	local Muzzle = self:GetAttachment( ID )
	self.SNDRTTurret = self:AddSoundEmitter( self:WorldToLocal( Muzzle.Pos ), "cannon_37mm_kwk36_shot_01.wav" )
	self.SNDRTTurret:SetSoundLevel( 95 )
	self.SNDRTTurret:SetParent( self, ID )
	
	local ID = self:LookupAttachment( "muzzle_coax" )
	local Muzzle = self:GetAttachment( ID )
	self.SNDTurretMG = self:AddSoundEmitter( self:WorldToLocal( Muzzle.Pos ), "lvs/vehicles/sherman/mg_loop.wav", "lvs/vehicles/sherman/mg_loop_interior.wav" )
	self.SNDTurretMG:SetSoundLevel( 95 )
	self.SNDTurretMG:SetParent( self, ID )
	
	self:AddEngine( Vector(-152,0,35), Angle(0,0,0), Vector(-15,-40,0), Vector(80,40,35) )
	self:AddFuelTank( Vector(-50,0,66), Angle(0,0,0), 1200, LVS.FUELTYPE_PETROL,  Vector(-22,-65,10), Vector(10,65,25) )
	
	-- ammo rack weakspot
	self:AddAmmoRack( Vector(25,40,76), Vector(10,0,65), Angle(0,0,0), Vector(-13,-12,0), Vector(37,12,15) )
	self:AddAmmoRack( Vector(25,-40,76), Vector(10,0,65), Angle(0,0,0), Vector(-13,-12,0), Vector(37,12,15) )
	
	-- Trailer hitch
	self:AddTrailerHitch( Vector(-200,-30,36), LVS.HITCHTYPE_MALE )
	self:AddTrailerHitch( Vector(-200,30,36), LVS.HITCHTYPE_MALE )
	
	-- Front
	self:AddArmor( Vector(135,0,25), Angle(10,0,0), Vector(30,-36,7), Vector(50,36,39), 2400, 28000 )
	self:AddArmor( Vector(135,-30,25), Angle(10,0,0), Vector(30,-8.5,0), Vector(51,7,39), 2400, 28000 )
	self:AddArmor( Vector(135,30,25), Angle(10,0,0), Vector(30,-7,0), Vector(51,8.5,39), 2400, 28000 )
	
	self:AddArmor( Vector(145,0,23), Angle(-75,0,0), Vector(35,-36,-16), Vector(40,36,55), 1500, 14000 )
	
	self:AddArmor( Vector(60,0,55), Angle(0,0,0), Vector(35,-14,17), Vector(50,3,39.5), 2500, 28000 )
	self:AddArmor( Vector(60,40,55), Angle(0,50,0), Vector(32,-30,17), Vector(40,18,39.5), 2500, 22000 )
	self:AddArmor( Vector(60,-40,55), Angle(0,-50,0), Vector(32,-20,17), Vector(40,20,39.5), 2500, 22000 )
	
	self:AddArmor( Vector(65,0,55), Angle(0,0,0), Vector(35,3,24), Vector(50,39,35.5), 2100, 23000 ) -- hull gun
	self:AddArmor( Vector(60,0,55), Angle(0,0,0), Vector(35,3,17), Vector(50,39,24), 2500, 28000 )
	self:AddArmor( Vector(60,0,55), Angle(0,0,0), Vector(35,3,35.5), Vector(50,39,39.5), 2500, 28000 )
	self:AddArmor( Vector(60,0,55), Angle(0,0,0), Vector(35,39,17), Vector(50,50,39.5), 2500, 28000 )
	
	self:AddArmor( Vector(60,0,55), Angle(0,0,0), Vector(35,-38,24), Vector(50,-14,35.5), 2100, 23000 ) -- driver Hatch
	self:AddArmor( Vector(60,0,55), Angle(0,0,0), Vector(35,-58,17), Vector(50,-38,39.5), 2500, 28000 )
	self:AddArmor( Vector(60,0,55), Angle(0,0,0), Vector(35,-38,17), Vector(50,-14,24), 2500, 28000 )
	self:AddArmor( Vector(60,0,55), Angle(0,0,0), Vector(35,-38,35.5), Vector(50,-14,39.5), 2500, 28000 )
	
	self:AddArmor( Vector(146.4,0,34), Angle(0,0,0), Vector(-4,-36,-17), Vector(27,36,-7), 1000, 7000 )
	
	self:AddArmor( Vector(17,0,53), Angle(0,0,0), Vector(-218,-76,40), Vector(85,76,41.5), 850, 6500 )
	self:AddArmor( Vector(17,0,26), Angle(0,0,0), Vector(-218,-83,40), Vector(85,83,41.5), 600, 4000 )
	self:AddArmor( Vector(107,0,23), Angle(0,0,0), Vector(-270,-36,-7), Vector(44.5,36,0), 600, 4000 )
	
	self:AddArmor( Vector(120,-36,68), Angle(0,0,0), Vector(-50,-48,-3), Vector(60,-1,7), 3000, 4000 )
	self:AddArmor( Vector(120,36,68), Angle(0,0,0), Vector(-50,1,-3), Vector(60,48,7), 3000, 4000 )
	
	-- Rear side
	self:AddArmor( Vector(-190,0,36), Angle(0,0,0), Vector(-13,-36,-5), Vector(0,36,31), 1200, 12500 )
	self:AddArmor( Vector(-190,0,36), Angle(0,0,0), Vector(-13,-83,31), Vector(-6,83,59), 1200, 13000 )
	self:AddArmor( Vector(-20,0,-60), Angle(30,0,0), Vector(-194,-36,-7), Vector(-162,36,0), 800, 6000 )
	--self:AddArmor( Vector(-97,0,33), Angle(0,0,0), Vector(-89,-55.5,40), Vector(10,55.5,42), 800, 5000 )
	
	-- -- Right side
	self:AddArmor( Vector(0,-80,72), Angle(0,0,0), Vector(-202,-4,0), Vector(73,6,23), 1000, 9500 )
	self:AddArmor( Vector(0,-85,73), Angle(0,0,0), Vector(-204,-2,-45), Vector(190,2,0), 1200, 15500 )
	-- -- Inner side
	self:AddArmor( Vector(0,-36,70), Angle(0,0,0), Vector(-203,-2,-57), Vector(178,2,-2), 1000, 12000 )

	-- -- Left side
	self:AddArmor( Vector(0,80,72), Angle(0,0,0), Vector(-202,-6,0), Vector(73,4,23), 1000, 9500 )
	self:AddArmor( Vector(0,85,73), Angle(0,0,0), Vector(-204,-2,-45), Vector(190,2,0), 1200, 15500 )
	-- -- Inner side
	self:AddArmor( Vector(0,36,70), Angle(0,0,0), Vector(-203,-2,-57), Vector(178,2,-2), 1000, 12000 )
	
	self:MakeTurretPhysics()
end

function ENT:MakeTurretPhysics()
	local MainTurret = self:CreateTurretPhysics( {
		follow = "turret",
		mdl = "models/japan/oro_turret_phys.mdl",
	} )
	self:AddArmor( Vector(19,0,0), Angle(0,0,0), Vector(40,-42.5,-1), Vector(60,42.5,45), 2500, 29000, MainTurret )
	

	self:AddArmor( Vector(10,5,0), Angle(0,-70,0), Vector(45,-35,-1), Vector(65,42.5,50), 2000, 20000, MainTurret ) --Rt
	self:AddArmor( Vector(10,-5,0), Angle(0,70,0), Vector(45,-42.5,-1), Vector(65,35,50), 2000, 20000, MainTurret ) --Lt
	
	self:AddArmor( Vector(-35,10,0), Angle(0,-107,0), Vector(45,-35,-1), Vector(65,55,50), 1800, 19000, MainTurret ) --Rr
	self:AddArmor( Vector(-35,-10,0), Angle(0,107,0), Vector(45,-55,-1), Vector(65,35,50), 1800, 19000, MainTurret ) --Lr
	
	self:AddArmor( Vector(-30,0,0), Angle(0,0,0), Vector(-60,-42.5,-1), Vector(-50,42.5,45), 1500, 13000, MainTurret )
	
	self:AddArmor( Vector(19,0,0), Angle(0,0,0), Vector(-19,-45,-1), Vector(40,10,51), 1000, 8000, MainTurret )
	self:AddArmor( Vector(19,0,0), Angle(0,0,0), Vector(-19,10,-1), Vector(40,45,47.5), 1000, 8000, MainTurret )
	
	self:AddArmor( Vector(19,0,0), Angle(0,0,0), Vector(-100,-45,-1), Vector(-19,45,51), 900, 6500, MainTurret )
	
	self:AddArmor( Vector(-10,30,33), Angle(0,0,0), Vector(-27,-22,12), Vector(35,20,30), 1700, 17000, MainTurret )
end

function ENT:AlignView( ply )
	if not IsValid( ply ) then return end

	timer.Simple( 0, function()
		if not IsValid( ply ) or not IsValid( self ) then return end

		local Ang = Angle(0,90,0)

		local pod = ply:GetVehicle()

		if self:GetDriver() == ply and IsValid( pod ) then
			Ang = pod:LocalToWorldAngles( Angle(0,90,0) )
			Ang.r = 0
		end

		ply:SetEyeAngles( Ang )
	end)
end