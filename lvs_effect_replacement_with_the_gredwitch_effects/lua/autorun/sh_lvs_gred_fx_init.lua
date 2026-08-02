--[[---------------------------------------------------------------------------
    LVS → Gredwitch FX : shared init.

    This addon is a pure client-side visual compatibility layer. There is no
    server code: LVS damage, ballistics, projectile physics, weapon logic,
    vehicle physics, networking and firing mechanics all run untouched.

    All modules are shipped to clients via AddCSLuaFile and included by
    autorun/client/cl_lvs_gred_fx_override.lua in dependency order.
-----------------------------------------------------------------------------]]

local CLIENT_FILES = {
    "lvs_gred_fx/config.lua",
    "lvs_gred_fx/debug.lua",
    "lvs_gred_fx/particles.lua",
    "lvs_gred_fx/muzzle.lua",
    "lvs_gred_fx/tracer.lua",
    "lvs_gred_fx/muzzleflash.lua",
    "lvs_gred_fx/barrelsmoke.lua",
    "lvs_gred_fx/impacts.lua",
    "lvs_gred_fx/trails.lua",
    "lvs_gred_fx/bridge.lua",
    "lvs_gred_fx/effect_list.lua",
    "autorun/client/cl_lvs_gred_fx_override.lua",
}

for _, file in ipairs(CLIENT_FILES) do
    AddCSLuaFile(file)
end
