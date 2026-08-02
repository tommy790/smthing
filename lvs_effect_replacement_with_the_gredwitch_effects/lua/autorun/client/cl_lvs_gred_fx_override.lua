if not CLIENT then return end

LVS_GRED_FX_OVERRIDE = LVS_GRED_FX_OVERRIDE or {}
LVS_GRED_FX_OVERRIDE.OriginalEffects = LVS_GRED_FX_OVERRIDE.OriginalEffects or {}
LVS_GRED_FX_OVERRIDE.Registered = LVS_GRED_FX_OVERRIDE.Registered or {}
LVS_GRED_FX_OVERRIDE.BadOriginalInit = {}

local OVERRIDE_MARKER = "__lvs_gred_fx_override"

local function includeBridge()
        include("lvs_gred_fx/bridge.lua")
        include("lvs_gred_fx/tracer.lua")
        return include("lvs_gred_fx/effect_list.lua")
end

local function debugPrint(...)
        local c = GetConVar("lvs_gred_fx_debug")
        if c and c:GetBool() then
                print("[lvs_gred_fx]", ...)
        end
end

local function isEnabled()
        return LVS_GRED_FX and LVS_GRED_FX.Enabled and LVS_GRED_FX.Enabled() or false
end

local function captureOriginal(effectName)
        local existing = LVS_GRED_FX_OVERRIDE.OriginalEffects[effectName]
        if existing and existing.Template then return end
        if not effects or not effects.Create then return end

        local ok, instance = pcall(effects.Create, effectName)
        if not ok or not istable(instance) then return end
        if instance[OVERRIDE_MARKER] then return end

        LVS_GRED_FX_OVERRIDE.OriginalEffects[effectName] = {
                Init = instance.Init,
                Think = instance.Think,
                Render = instance.Render,
                Template = instance,
        }
end

local function seedOriginalFields(effectName, self)
        local orig = LVS_GRED_FX_OVERRIDE.OriginalEffects[effectName]
        local template = orig and orig.Template
        if not istable(template) then return end

        -- Original LVS effects often store materials/tables as fields on EFFECT
        -- (for example SmokeMat and MatSmoke). Because our registered wrapper is the
        -- runtime effect object, calling the original Init without these fields makes
        -- otherwise valid LVS effects error. Copy non-lifecycle fields before fallback.
        for k, v in pairs(template) do
                if k ~= "Init" and k ~= "Think" and k ~= "Render" and k ~= OVERRIDE_MARKER then
                        self[k] = v
                end
        end
end

local function callOriginalInit(effectName, self, data)
        if LVS_GRED_FX_OVERRIDE.BadOriginalInit and LVS_GRED_FX_OVERRIDE.BadOriginalInit[effectName] then
                return false
        end

        local orig = LVS_GRED_FX_OVERRIDE.OriginalEffects[effectName]
        if not orig or not orig.Init then return true end

        seedOriginalFields(effectName, self)
        local ok, err = pcall(orig.Init, self, data)
        if not ok then
                -- Some LVS tracer effects can error when third-party bullet data is missing optional
                -- fields such as MatSmoke. Do not spam every shot; remember the failure and stop
                -- trying that broken original until Lua is reloaded.
                LVS_GRED_FX_OVERRIDE.BadOriginalInit = LVS_GRED_FX_OVERRIDE.BadOriginalInit or {}
                if not LVS_GRED_FX_OVERRIDE.BadOriginalInit[effectName] then
                        LVS_GRED_FX_OVERRIDE.BadOriginalInit[effectName] = true
                        ErrorNoHalt("[lvs_gred_fx] Original Init failed for " .. tostring(effectName) .. ": " .. tostring(err) .. "\n")
                end
                return false
        end

        return true
end

local function shouldRunOriginalFeedback(effectName)
        return LVS_GRED_FX
                and LVS_GRED_FX.ShouldRunOriginalFeedback
                and LVS_GRED_FX.ShouldRunOriginalFeedback(effectName) == true
end

local function _feedbackNoop() end
local function _feedbackNil() return nil end

local FEEDBACK_DUMMY_PARTICLE = {}
setmetatable(FEEDBACK_DUMMY_PARTICLE, {
        __index = function() return _feedbackNoop end,
})

local FEEDBACK_DUMMY_EMITTER = {}
function FEEDBACK_DUMMY_EMITTER:Add() return FEEDBACK_DUMMY_PARTICLE end
function FEEDBACK_DUMMY_EMITTER:Finish() end
function FEEDBACK_DUMMY_EMITTER:SetNoDraw() end
function FEEDBACK_DUMMY_EMITTER:Draw() end
function FEEDBACK_DUMMY_EMITTER:IsValid() return true end
setmetatable(FEEDBACK_DUMMY_EMITTER, {
        __index = function() return _feedbackNoop end,
})

local function callOriginalFeedbackOnly(effectName, self, data)
        local orig = LVS_GRED_FX_OVERRIDE.OriginalEffects[effectName]
        if not orig or not orig.Init then return false end
        if not shouldRunOriginalFeedback(effectName) and not orig.Think then return false end

        seedOriginalFields(effectName, self)

        -- Run original LVS Init only for non-visual feedback such as util.ScreenShake.
        -- Suppress the visual/audio side effects so the replacement particles remain the
        -- only visuals. util.ScreenShake is intentionally NOT replaced.
        local old = {
                ParticleEffect = ParticleEffect,
                ParticleEffectAttach = ParticleEffectAttach,
                CreateParticleSystem = CreateParticleSystem,
                CreateParticleSystemNoEntity = CreateParticleSystemNoEntity,
                ParticleEmitter = ParticleEmitter,
                DynamicLight = DynamicLight,
                utilEffect = util and util.Effect,
                utilDecal = util and util.Decal,
                soundPlay = sound and sound.Play,
        }

        ParticleEffect = _feedbackNoop
        ParticleEffectAttach = _feedbackNoop
        CreateParticleSystem = _feedbackNil
        CreateParticleSystemNoEntity = _feedbackNil
        ParticleEmitter = function() return FEEDBACK_DUMMY_EMITTER end
        DynamicLight = _feedbackNil
        if util then
                util.Effect = _feedbackNoop
                util.Decal = _feedbackNoop
        end
        if sound then sound.Play = _feedbackNoop end

        local ok, err = pcall(orig.Init, self, data)
        if not ok then
                debugPrint("original feedback/lifetime init failed", effectName, err)
        end

        ParticleEffect = old.ParticleEffect
        ParticleEffectAttach = old.ParticleEffectAttach
        CreateParticleSystem = old.CreateParticleSystem
        CreateParticleSystemNoEntity = old.CreateParticleSystemNoEntity
        ParticleEmitter = old.ParticleEmitter
        DynamicLight = old.DynamicLight
        if util then
                util.Effect = old.utilEffect
                util.Decal = old.utilDecal
        end
        if sound then sound.Play = old.soundPlay end

        -- Return true only when the original LVS effect has a Think function that can be
        -- used as the authoritative lifetime oracle for our replacement particle system.
        return ok == true and orig.Think ~= nil
end

local function callOriginalThinkSilently(effectName, self)
        local orig = LVS_GRED_FX_OVERRIDE.OriginalEffects[effectName]
        if not orig or not orig.Think then return nil end

        local old = {
                ParticleEffect = ParticleEffect,
                ParticleEffectAttach = ParticleEffectAttach,
                CreateParticleSystem = CreateParticleSystem,
                CreateParticleSystemNoEntity = CreateParticleSystemNoEntity,
                ParticleEmitter = ParticleEmitter,
                DynamicLight = DynamicLight,
                utilEffect = util and util.Effect,
                utilDecal = util and util.Decal,
                soundPlay = sound and sound.Play,
        }

        ParticleEffect = _feedbackNoop
        ParticleEffectAttach = _feedbackNoop
        CreateParticleSystem = _feedbackNil
        CreateParticleSystemNoEntity = _feedbackNil
        ParticleEmitter = function() return FEEDBACK_DUMMY_EMITTER end
        DynamicLight = _feedbackNil
        if util then
                util.Effect = function(n, effectData, allowOverride, ignorePredictionOrRecipientFilter)
                        -- LVS tracer Think() is where LVS decides to fire the terminal AP impact:
                        -- util.Effect("lvs_bullet_impact_ap", effectdata). Let that exact nested
                        -- effect pass through so our registered AP replacement runs when LVS says it
                        -- should. Suppress all other nested visuals.
                        if n == "lvs_bullet_impact_ap" and old.utilEffect then
                                return old.utilEffect(n, effectData, allowOverride, ignorePredictionOrRecipientFilter)
                        end
                end
                util.Decal = _feedbackNoop
        end
        if sound then sound.Play = _feedbackNoop end

        local ok, ret = pcall(orig.Think, self)

        ParticleEffect = old.ParticleEffect
        ParticleEffectAttach = old.ParticleEffectAttach
        CreateParticleSystem = old.CreateParticleSystem
        CreateParticleSystemNoEntity = old.CreateParticleSystemNoEntity
        ParticleEmitter = old.ParticleEmitter
        DynamicLight = old.DynamicLight
        if util then
                util.Effect = old.utilEffect
                util.Decal = old.utilDecal
        end
        if sound then sound.Play = old.soundPlay end

        if not ok then
                debugPrint("original lifetime think failed", effectName, ret)
                return nil
        end

        return ret == true
end

local function stopReplacement(effectName, self)
        if LVS_GRED_FX and LVS_GRED_FX.Stop then
                pcall(LVS_GRED_FX.Stop, effectName, self)
        end
end

local function callOriginalThink(effectName, self)
        local orig = LVS_GRED_FX_OVERRIDE.OriginalEffects[effectName]
        if not orig or not orig.Think then return false end

        local ok, ret = pcall(orig.Think, self)
        if not ok then return false end
        return ret == true
end

local function callOriginalRender(effectName, self)
        local orig = LVS_GRED_FX_OVERRIDE.OriginalEffects[effectName]
        if not orig or not orig.Render then return end

        local ok, err = pcall(orig.Render, self)
        if not ok then
                ErrorNoHalt("[lvs_gred_fx] Original Render failed for " .. tostring(effectName) .. ": " .. tostring(err) .. "\n")
        end
end

local function normalizeHandled(ret)
        -- Bridge contract:
        --   true  = replacement was created; do not run/render original.
        --   false = replacement declined/failed; fall back to original unless the bridge
        --           marks this effect as unsafe to fall back.
        --   nil   = legacy bridge handler completed without a return; treat as handled.
        if ret == false then return false end
        return true
end

local function suppressOriginalOnFailure(effectName)
        return LVS_GRED_FX
                and LVS_GRED_FX.SuppressOriginalOnFailure
                and LVS_GRED_FX.SuppressOriginalOnFailure(effectName) == true
end

local function registerOverride(effectName)
        if not isstring(effectName) or effectName == "" then return end

        captureOriginal(effectName)

        local EFFECT = {}
        EFFECT[OVERRIDE_MARKER] = true
        EFFECT._lvs_gred_effect_name = effectName

        function EFFECT:Init(data)
                self._lvs_gred_effect_name = effectName
                self._lvs_gred_fx_handled = false

                if not isEnabled() or not LVS_GRED_FX or not LVS_GRED_FX.Init then
                        if suppressOriginalOnFailure(effectName) then
                                self._lvs_gred_fx_handled = true
                                return
                        end
                        callOriginalInit(effectName, self, data)
                        return
                end

                local ok, ret = pcall(LVS_GRED_FX.Init, effectName, self, data)
                if not ok then
                        ErrorNoHalt("[lvs_gred_fx] Replacement Init failed for " .. tostring(effectName) .. ": " .. tostring(ret) .. "\n")
                        if suppressOriginalOnFailure(effectName) then
                                self._lvs_gred_fx_handled = true
                                return
                        end
                        callOriginalInit(effectName, self, data)
                        return
                end

                if not normalizeHandled(ret) then
                        if suppressOriginalOnFailure(effectName) then
                                self._lvs_gred_fx_handled = true
                                return
                        end
                        callOriginalInit(effectName, self, data)
                        return
                end

                self._lvs_gred_fx_original_lifetime = callOriginalFeedbackOnly(effectName, self, data)
                self._lvs_gred_fx_handled = true
        end

        function EFFECT:Think()
                if self._lvs_gred_fx_handled and isEnabled() and LVS_GRED_FX and LVS_GRED_FX.Think then
                        -- If the original LVS effect has a Think lifetime, let LVS decide exactly
                        -- when the replacement should stop. Its visuals stay suppressed; only the
                        -- boolean lifetime result is used.
                        if self._lvs_gred_fx_original_lifetime then
                                local lvsAlive = callOriginalThinkSilently(effectName, self)
                                if lvsAlive == false then
                                        stopReplacement(effectName, self)
                                        return false
                                end
                        end

                        local ok, ret = pcall(LVS_GRED_FX.Think, effectName, self)
                        if ok then
                                if ret ~= true then stopReplacement(effectName, self) end
                                return ret == true
                        end
                        stopReplacement(effectName, self)
                        return false
                end

                return callOriginalThink(effectName, self)
        end

        function EFFECT:Render()
                if self._lvs_gred_fx_handled and isEnabled() and LVS_GRED_FX and LVS_GRED_FX.Render then
                        pcall(LVS_GRED_FX.Render, effectName, self)
                        return
                end

                callOriginalRender(effectName, self)
        end

        effects.Register(EFFECT, effectName)
        LVS_GRED_FX_OVERRIDE.Registered[effectName] = true
        debugPrint("registered effect override", effectName)
end

local function applyOverrides()
        if not effects or not effects.Register then return end

        local names = includeBridge()
        if not istable(names) then
                ErrorNoHalt("[lvs_gred_fx] Failed to include lvs_gred_fx/effect_list.lua\n")
                return
        end

        for i = 1, #names do
                registerOverride(names[i])
        end
end

hook.Add("InitPostEntity", "lvs_gred_fx_override_effects", applyOverrides)
hook.Add("OnReloaded", "lvs_gred_fx_override_effects", applyOverrides)
-- Apply more than once during startup. Some LVS/effect addons register their effects
-- after client autorun; late passes ensure our exact-name replacements, including
-- lvs_bullet_impact_ap, remain the active registered effects without global hooks.
timer.Simple(0, applyOverrides)
timer.Simple(1, applyOverrides)
timer.Simple(5, applyOverrides)

hook.Add("PopulateToolMenu", "LVS_GRED_FX_Menu", function()
        spawnmenu.AddToolMenuOption("Options", "LVS", "LVS_Gred_FX", "Gredwitch FX", "", "", function(panel)
                panel:ClearControls()
                panel:Help("Client-side LVS visual effect replacements using Gredwitch-style particle systems.")

                panel:CheckBox("Enable Gredwitch FX Overrides", "lvs_gred_fx")
                panel:ControlHelp("Replaces registered LVS client VFX. Server networking is left untouched.")

                panel:CheckBox("Enable Cannon Barrel Smoke", "lvs_gred_fx_barrel_smoke")
                panel:ControlHelp("Spawns short-lived barrel smoke after cannon shots when the particle exists.")

                panel:CheckBox("Enable Debug Mode", "lvs_gred_fx_debug")
                panel:ControlHelp("Prints mapping and spawn diagnostics to the console.")
        end)
end)
