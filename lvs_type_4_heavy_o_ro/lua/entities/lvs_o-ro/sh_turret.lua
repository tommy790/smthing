include("entities/lvs_tank_wheeldrive_add/modules/sh_turret_mod_1.lua")
include("entities/lvs_tank_wheeldrive_add/modules/sh_turret_ballistics_mod_1.lua")

ENT.TurretBallisticsProjectileVelocity = ENT.ProjectileVelocity
ENT.TurretBallisticsMuzzleAttachment = "muzzle"
ENT.TurretBallisticsViewAttachment = "sight"

ENT.TurretPodIndex = 1
ENT.TurretAimRate = 18

ENT.TurretPitchBoneIndex = 7
ENT.TurretPitchMin = -20
ENT.TurretPitchMax = 10
ENT.TurretPitchMul = 1
ENT.TurretPitchOffset = 0

ENT.TurretYawBoneIndex = 6
ENT.TurretYawMul = 1
ENT.TurretYawOffset = 0

ENT.TurretYawSectors = {
       { angle_range = {135, 225},   pitch_range = {-20, 2} },
       { angle_range = {-225, -135},   pitch_range = {-20, 2} },

}

function ENT:GetTurretViewOrigin()
	local ID = self:LookupAttachment( self.TurretBallisticsViewAttachment )
	
	local Att = self:GetAttachment( ID )

	if not Att then return self:GetPos(), false end

	local Pos = Att.Pos

	return Pos, true
end