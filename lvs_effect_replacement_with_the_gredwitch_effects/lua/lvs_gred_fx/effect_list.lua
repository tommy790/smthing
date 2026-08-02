-- Effect list for LVS Gredwitch FX override.
-- Each name must match util.Effect("lvs_*") exactly (lowercase).
-- Only effects listed here are overridden by the Gredwitch particle replacements.
-- Tracers are replaced with Gredwitch-style beam particles.
-- Flamestream effects are NOT overridden — LVS handles them natively.

return {
        -- Impacts
        "lvs_bullet_impact",
        "lvs_bullet_impact_ap",
        "lvs_bullet_impact_explosive",
        "lvs_laser_impact",
        "lvs_shield_impact",

        -- Explosions
        "lvs_concussion_explosion",
        "lvs_defence_explosion",
        "lvs_explosion",
        "lvs_explosion_bomb",
        "lvs_explosion_nodebris",
        "lvs_explosion_small",
        "lvs_laser_explosion",
        "lvs_laser_explosion_aat",
        "lvs_proton_explosion",
        "lvs_trailer_explosion",

        -- Muzzle flashes
        "lvs_haubitze_muzzle",
        "lvs_muzzle",
        "lvs_muzzle_colorable",
        "lvs_pulserifle_muzzle",

        -- Fire / flame (NOT including flamestream — LVS handles natively)
        "lvs_ammorack_fire",
        "lvs_carengine_fire",
        "lvs_carfueltank_fire",
        "lvs_firetrail",

        -- Trails (entity-attached)
        "lvs_concussion_trail",
        "lvs_missiletrail",
        "lvs_proton_trail",

        -- Smoke / exhaust
        "lvs_defence_smoke",
        "lvs_truck_exhaust",

        -- Physics (scrape, water, etc.)
        "lvs_hover_water",
        "lvs_physics_scrape",
        "lvs_physics_trackscraping",
        "lvs_physics_turretscraping",
        "lvs_physics_water",
        "lvs_physics_water_advanced",
        "lvs_physics_wheelwatersplash",

        -- Misc
        "lvs_laser_charge",
        "lvs_rotor_destruction",
        "lvs_tire_blow",
        "lvs_trailer_flak",
        "lvs_walker_stomp",

        -- ================================================================
        -- Tracers — replaced with Gredwitch-style beam particles.
        -- The override system captures these, bridge.lua routes them to
        -- LVS_GRED_FX_TRACER.Init which spawns gred_tracers_<color>_<caliber>.
        -- The original LVS tracer's Think runs silently and fires
        -- lvs_bullet_impact_ap when the bullet hits (AP hit particles).
        -- ================================================================
        "lvs_tracer_autocannon",
        "lvs_tracer_cannon",
        "lvs_tracer_green",
        "lvs_tracer_missile",
        "lvs_tracer_orange",
        "lvs_tracer_proton",
        "lvs_tracer_white",
        "lvs_tracer_yellow",
        "lvs_tracer_yellow_small",
        "lvs_pulserifle_tracer",
        "lvs_pulserifle_tracer_large",
        "lvs_laser_blue",
        "lvs_laser_blue_long",
        "lvs_laser_blue_short",
        "lvs_laser_green",
        "lvs_laser_green_short",
        "lvs_laser_red",
        "lvs_laser_red_aat",
        "lvs_laser_red_short",

        -- Flamestream: LVS handles these natively.
        -- "lvs_flamestream",
        -- "lvs_flamestream_start",
        -- "lvs_flamestream_finish",

        -- Haubitze trail: keep original LVS haubitze trail
        -- "lvs_haubitze_trail",

        -- Physics dust/impact: already gated by LVS.ShowPhysicsEffects
        -- "lvs_physics_dust",
        -- "lvs_physics_trackdust",
        -- "lvs_physics_wheeldust",
        -- "lvs_physics_impact",
        -- "lvs_physics_wheelsmoke",
}
