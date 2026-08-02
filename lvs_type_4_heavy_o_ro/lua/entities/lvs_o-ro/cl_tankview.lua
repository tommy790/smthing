include("entities/lvs_tank_wheeldrive/modules/cl_tankview.lua")

function ENT:TankViewOverride( ply, pos, angles, fov, pod )
	if ply == self:GetDriver() and not pod:GetThirdPersonMode() then
		local vieworigin, found = self:GetTurretViewOrigin()

		if found then pos = vieworigin end
	elseif ply == self:GetDriver() and pod:GetThirdPersonMode() then
		local ID = self:LookupAttachment( "turret" )
		local Muzzle = self:GetAttachment( ID )
		pos = Muzzle.Pos + Vector(0,0,60)
	end

	return pos, angles, fov
end

-- function ENT:TankGunnerViewOverride( ply, pos, angles, fov, pod )
	-- if ply == self:GetDriver() and not pod:GetThirdPersonMode() then
		-- local vieworigin, found = self:GetTurretViewOrigin()

		-- if found then pos = vieworigin end
	-- elseif ply == self:GetDriver() and pod:GetThirdPersonMode() then
		-- local ID = self:LookupAttachment( "main_turret" )
		-- local Muzzle = self:GetAttachment( ID )
		-- pos = Muzzle.Pos + Vector(0,0,60)
	-- end

	-- return pos, angles, fov
-- end