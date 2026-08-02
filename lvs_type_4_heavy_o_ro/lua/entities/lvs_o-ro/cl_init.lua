include("shared.lua")
include("sh_tracks.lua")
include("sh_turret.lua")
include("cl_tankview.lua")
include("cl_optics.lua")

ENT.OpticsProjectileSize = 14

function ENT:OnSpawn()
	self:CreateBonePoseParameter( "suspension_left_1", self:LookupBone( "wheel_road_left_1" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_2", self:LookupBone( "wheel_road_left_2" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_3", self:LookupBone( "wheel_road_left_3" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_4", self:LookupBone( "wheel_road_left_4" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_5", self:LookupBone( "wheel_road_left_5" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_6", self:LookupBone( "wheel_road_left_6" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_7", self:LookupBone( "wheel_road_left_7" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_8", self:LookupBone( "wheel_road_left_8" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_9", self:LookupBone( "wheel_road_left_9" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_left_10", self:LookupBone( "wheel_road_left_10" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )

	self:CreateBonePoseParameter( "suspension_right_1", self:LookupBone( "wheel_road_right_1" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_2", self:LookupBone( "wheel_road_right_2" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_3", self:LookupBone( "wheel_road_right_3" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_4", self:LookupBone( "wheel_road_right_4" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_5", self:LookupBone( "wheel_road_right_5" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_6", self:LookupBone( "wheel_road_right_6" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_7", self:LookupBone( "wheel_road_right_7" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_8", self:LookupBone( "wheel_road_right_8" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_9", self:LookupBone( "wheel_road_right_9" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "suspension_right_10", self:LookupBone( "wheel_road_right_10" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )

	self:CreateBonePoseParameter( "rsuspension_left_1", self:LookupBone( "wheel_road_left_1_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_2", self:LookupBone( "wheel_road_left_2_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_3", self:LookupBone( "wheel_road_left_3_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_4", self:LookupBone( "wheel_road_left_4_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_5", self:LookupBone( "wheel_road_left_5_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_6", self:LookupBone( "wheel_road_left_6_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_7", self:LookupBone( "wheel_road_left_7_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_8", self:LookupBone( "wheel_road_left_8_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_9", self:LookupBone( "wheel_road_left_9_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_left_10", self:LookupBone( "wheel_road_left_10_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )

	self:CreateBonePoseParameter( "rsuspension_right_1", self:LookupBone( "wheel_road_right_1_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_2", self:LookupBone( "wheel_road_right_2_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_3", self:LookupBone( "wheel_road_right_3_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_4", self:LookupBone( "wheel_road_right_4_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_5", self:LookupBone( "wheel_road_right_5_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_6", self:LookupBone( "wheel_road_right_6_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_7", self:LookupBone( "wheel_road_right_7_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_8", self:LookupBone( "wheel_road_right_8_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_9", self:LookupBone( "wheel_road_right_9_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )
	self:CreateBonePoseParameter( "rsuspension_right_10", self:LookupBone( "wheel_road_right_10_track" ), nil, nil, Vector(0,0,8), Vector(0,0,-8) )

	-- self:CreateBonePoseParameter( "DriverhatchR", self:LookupBone( "hatch_front_right" ), nil, Angle(-90,0,0) )
	-- self:CreateBonePoseParameter( "DriverhatchL", self:LookupBone( "hatch_front_left" ), nil, Angle(-90,0,0) )
end

local switch = Material("lvs/weapons/change_ammo.png")
local AP = Material("lvs/weapons/bullet_ap.png")
local HE = Material("lvs/weapons/tank_cannon.png")

function ENT:DrawWeaponIcon( PodID, ID, x, y, width, height, IsSelected, IconColor )
	local Icon = self:GetUseHighExplosive() and HE or AP

	surface.SetMaterial( Icon )
	surface.DrawTexturedRect( x, y, width, height )

	local ply = LocalPlayer()

	if not IsValid( ply ) or self:GetSelectedWeapon() ~= 1 then return end

	surface.SetMaterial( switch )
	surface.DrawTexturedRect( x + width + 5, y + 7, 24, 24 )

	local buttonCode = ply:lvsGetControls()[ "CAR_SWAP_AMMO" ]

	if not buttonCode then return end

	local KeyName = input.GetKeyName( buttonCode )

	if not KeyName then return end

	draw.DrawText( KeyName, "DermaDefault", x + width + 17, y + height * 0.5 + 7, Color(0,0,0,IconColor.a), TEXT_ALIGN_CENTER )
end


function ENT:OnEngineActiveChanged( Active )
	if Active then
		self:EmitSound( "lvs/vehicles/tiger/engine_start.wav", 75, 100,  LVS.EngineVolume )
	else
		self:EmitSound( "lvs/vehicles/tiger/engine_stop.wav", 75, 100,  LVS.EngineVolume )
	end
end

function ENT:OnFrame()
	local FT = RealFrameTime()
	self:AnimTrack( FT )
end

function ENT:AnimTrack( frametime )
	if !self:GetEngineActive() then return end

    local velocity = self:GetVelocity()
    local speed = velocity:Length()
    local forward = self:GetForward()
    local dir = velocity:GetNormalized()
    local directionSign = (forward:Dot(dir) >= 0) and 1 or -1

    local rpm = speed * 2
    local rotationAngle = rpm * frametime * directionSign

    self._rRPM = self._rRPM and (self._rRPM + rotationAngle) or 0

    local Rot = Angle(self._rRPM, 0, 0)
    Rot:Normalize()

	-- Left track
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_1" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_2" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_3" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_4" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_5" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_6" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_7" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_8" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_9" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_left_10" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_return_left" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_driver_left" ), Rot)
	
	-- Right track
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_1" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_2" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_3" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_4" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_5" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_6" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_7" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_8" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_9" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_road_right_10" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_driver_right" ), Rot)
	self:ManipulateBoneAngles(self:LookupBone( "wheel_return_right" ), Rot)
end

DEFINE_BASECLASS( "lvs_tank_wheeldrive" )

function ENT:CalcViewDirectInput( ply, pos, angles, fov, pod )
	return self:CalcTankView( ply, pos, angles, fov, pod )
end

function ENT:CalcViewDriver( ply, pos, angles, fov, pod )

	angles = ply:EyeAngles()

	return BaseClass.CalcViewDriver( self, ply, pos, angles, fov, pod )
end

function ENT:CalcViewPunch( ply, pos, angles, fov, pod )
	angles = ply:EyeAngles()

	return BaseClass.CalcViewPunch( self, ply, pos, angles, fov, pod )
end

function ENT:CalcViewOverride( ply, pos, angles, fov, pod )

	pos = pos + Vector(0,0,150) * math.abs( math.min( pod:GetUp().z, 0 ) )

	return pos, angles, fov
end