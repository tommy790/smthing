-- LVS Gredwitch FX — Tracer System (client-side)
-- Minimal handler — just suppresses the original LVS tracer visual.
-- The actual beam is rendered from gred_net_createtracer sent by the server.

if not CLIENT then return end

LVS_GRED_FX_TRACER = LVS_GRED_FX_TRACER or {}

function LVS_GRED_FX_TRACER.Init(name, self, data)
	self._gmode = "tracer_oneshot"
	return true
end

function LVS_GRED_FX_TRACER.Think(self)
	return true
end

function LVS_GRED_FX_TRACER.Stop(self)
	if self and self._psys and self._psys.StopEmission then
		pcall(function() self._psys:StopEmission(false, false) end)
		self._psys = nil
	end
end
