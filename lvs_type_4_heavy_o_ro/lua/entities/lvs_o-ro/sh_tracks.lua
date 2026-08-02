
if SERVER then
	ENT.PivotSteerEnable = true
	ENT.PivotSteerByBrake = true
	ENT.PivotSteerWheelRPM = 45

	function ENT:OnLeftTrackRepaired()
		self:SetBodygroup(7,0)
	end

	function ENT:OnLeftTrackDestroyed()
		self:SetBodygroup(7,1)
	end	
	
	function ENT:OnRightTrackRepaired()
		self:SetBodygroup(8,0)
	end

	function ENT:OnRightTrackDestroyed()
		self:SetBodygroup(8,1)
	end

	function ENT:TracksCreate( PObj )
		self:CreateTrackPhysics( "models/tracks/oro_track_phys.mdl" )
	
		local WheelModelB = "models/props_vehicles/tire001b_truck.mdl"
		
		local L1 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_LEFT, pos = Vector(150,62,20), mdl = WheelModelB } )
		local L2 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_LEFT, pos = Vector(98,62,20), mdl = WheelModelB } )
		local L3 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_LEFT, pos = Vector(46,62,20), mdl = WheelModelB } )
		local L4 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_LEFT, pos = Vector(-6,62,20), mdl = WheelModelB } )
		local L5 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_LEFT, pos = Vector(-58,62,20), mdl = WheelModelB } )
		local L6 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_LEFT, pos = Vector(-110,62,20), mdl = WheelModelB } )
		local L7 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_LEFT, pos = Vector(-162,62,20), mdl = WheelModelB } )
		local LeftWheelChain = self:CreateWheelChain( {L1, L2, L3, L4, L5, L6, L7} )
		self:SetTrackDriveWheelLeft( L4 )
		
		local R1 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_RIGHT, pos = Vector(150,-62,20), mdl = WheelModelB } )
		local R2 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_RIGHT, pos = Vector(98,-62,20), mdl = WheelModelB } )
		local R3 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_RIGHT, pos = Vector(46,-62,20), mdl = WheelModelB } )
		local R4 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_RIGHT, pos = Vector(-6,-62,20), mdl = WheelModelB } )
		local R5 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_RIGHT, pos = Vector(-58,-62,20), mdl = WheelModelB } )
		local R6 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_RIGHT, pos = Vector(-110,-62,20), mdl = WheelModelB } )
		local R7 = self:AddWheel( { hide = true, wheeltype = LVS.WHEELTYPE_RIGHT, pos = Vector(-162,-62,20), mdl = WheelModelB } )
		local RightWheelChain = self:CreateWheelChain( {R1, R2, R3, R4, R5, R6, R7} )
		self:SetTrackDriveWheelRight( R4 )

		local LeftTracksArmor = self:AddArmor( Vector(0,70,30), Angle(0,0,0), Vector(-210,-30,-33), Vector(195,11,33), 1200, 3000 )
		self:SetTrackArmorLeft( LeftTracksArmor, LeftWheelChain )

		local RightTracksArmor = self:AddArmor( Vector(0,-70,30), Angle(0,0,0), Vector(-210,-11,-33), Vector(195,30,33), 1200, 3000 )
		self:SetTrackArmorRight( RightTracksArmor, RightWheelChain )
		
		self:DefineAxle( {
			Axle = {
				ForwardAngle = Angle(0,0,0),
				SteerType = LVS.WHEEL_STEER_FRONT,
				SteerAngle = 15,
				TorqueFactor = 0,
				BrakeFactor = 1,
				UseHandbrake = true,
			},
			Wheels = { R1, L1 },
			Suspension = {
				Height = 3,
				MaxTravel = 15,
				ControlArmLength = 150,
				SpringConstant = 20000,
				SpringDamping = 2000,
				SpringRelativeDamping = 2000,
			},
		} )
		
		self:DefineAxle( {
			Axle = {
				ForwardAngle = Angle(0,0,0),
				SteerType = LVS.WHEEL_STEER_FRONT,
				SteerAngle = 15,
				TorqueFactor = 0,
				BrakeFactor = 1,
				UseHandbrake = true,
			},
			Wheels = { R2, L2 },
			Suspension = {
				Height = 3,
				MaxTravel = 15,
				ControlArmLength = 150,
				SpringConstant = 20000,
				SpringDamping = 2000,
				SpringRelativeDamping = 2000,
			},
		} )
		
		self:DefineAxle( {
			Axle = {
				ForwardAngle = Angle(0,0,0),
				SteerType = LVS.WHEEL_STEER_NONE,
				TorqueFactor = 1,
				BrakeFactor = 1,
				UseHandbrake = true,
			},
			Wheels = { R3, L3, L4, R4, R5, L5 },
			Suspension = {
				Height = 5,
				MaxTravel = 15,
				ControlArmLength = 150,
				SpringConstant = 20000,
				SpringDamping = 2000,
				SpringRelativeDamping = 2000,
			},
		} )
		
		self:DefineAxle( {
			Axle = {
				ForwardAngle = Angle(0,0,0),
				SteerType = LVS.WHEEL_STEER_REAR,
				SteerAngle = 15,
				TorqueFactor = 0,
				BrakeFactor = 1,
				UseHandbrake = true,
			},
			Wheels = { R6, L6 },
			Suspension = {
				Height = 8,
				MaxTravel = 15,
				ControlArmLength = 150,
				SpringConstant = 20000,
				SpringDamping = 2000,
				SpringRelativeDamping = 2000,
			},
		} )

		self:DefineAxle( {
			Axle = {
				ForwardAngle = Angle(0,0,0),
				SteerType = LVS.WHEEL_STEER_REAR,
				SteerAngle = 15,
				TorqueFactor = 0,
				BrakeFactor = 1,
				UseHandbrake = true,
			},
			Wheels = { R7, L7 },
			Suspension = {
				Height = 8,
				MaxTravel = 15,
				ControlArmLength = 150,
				SpringConstant = 20000,
				SpringDamping = 2000,
				SpringRelativeDamping = 2000,
			},
		} )
	end

else

	ENT.TrackSystemEnable = true

	ENT.TrackScrollTexture = "models/wot/vehicles/japan/tracks/type_4_track_d"
	ENT.ScrollTextureData = {
		["$bumpmap"] = "models/wot/vehicles/japan/tracks/type_4_track_n",
		["$phong"] = "1",
		["$phongboost"] = "0.02", 
		["$phongexponent"] = "3",
		["$phongfresnelranges"] = "[1 1 1]",
		["$translate"] = "[0.0 0.0 0.0]",
		["$colorfix"] = "{255 255 255}",
		["Proxies"] = {
			["TextureTransform"] = {
				["translateVar"] = "$translate",
				["centerVar"]    = "$center",
				["resultVar"]    = "$basetexturetransform",
			},
			["Equals"] = {
				["srcVar1"] =  "$colorfix",
				["resultVar"] = "$color",
			}
		}
	}

	ENT.TrackLeftSubMaterialID = 5
	ENT.TrackLeftSubMaterialMul = Vector(0,0.01515,0)

	ENT.TrackRightSubMaterialID = 7
	ENT.TrackRightSubMaterialMul = Vector(0,0.01515,0)

	ENT.TrackPoseParameterLeft = "spin_wheels_left"
	ENT.TrackPoseParameterLeftMul =  -1.252

	ENT.TrackPoseParameterRight = "spin_wheels_right"
	ENT.TrackPoseParameterRightMul =  -1.252

	ENT.TrackSounds = "lvs/vehicles/tiger/tracks_loop.wav"
	ENT.TrackHull = Vector(10,10,10)
	ENT.TrackData = {}
	for i = 1, 10 do
		for n = 0, 1 do
			local LR = n == 0 and "l" or "r"
			local LeftRight = n == 0 and "left" or "right"
			local data = {
				Attachment = {
					name = "suspension_"..LR.."_"..i,
					toGroundDistance = 16,
					traceLength = 100,
				},
				PoseParameter = {
					name = "!suspension_"..LeftRight.."_"..i,
					rangeMultiplier = 0.7,
					lerpSpeed = 10,
				},
			}
			table.insert( ENT.TrackData, data )
		end
	end
	for i = 1, 10 do
		for n = 0, 1 do
			local LR = n == 0 and "l" or "r"
			local LeftRight = n == 0 and "left" or "right"
			local data = {
				Attachment = {
					name = "suspension_"..LR.."_"..i,
					toGroundDistance = 16,
					traceLength = 100,
				},
				PoseParameter = {
					name = "!rsuspension_"..LeftRight.."_"..i,
					rangeMultiplier = 0.7,
					lerpSpeed = 10,
				},
			}
			table.insert( ENT.TrackData, data )
		end
	end

end