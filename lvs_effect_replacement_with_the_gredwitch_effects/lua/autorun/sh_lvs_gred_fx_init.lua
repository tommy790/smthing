-- Ship client-only override + bridge + effect list to clients.
AddCSLuaFile( "lvs_gred_fx/bridge.lua" )
AddCSLuaFile( "lvs_gred_fx/effect_list.lua" )
AddCSLuaFile( "lvs_gred_fx/tracer.lua" )
AddCSLuaFile( "autorun/client/cl_lvs_gred_fx_override.lua" )

-- Server-side ballistics (LVS:FireBullet runs untouched — damage/penetration)
if SERVER then
	include( "lvs_gred_fx/sv_ballistics.lua" )
end
