local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

UnloadBalesEarly = {}
UnloadBalesEarly_mt = Class(UnloadBalesEarly)
function UnloadBalesEarly.new()
	local self = setmetatable({}, UnloadBalesEarly_mt)
	self.overrideFillLevel = -1
	return self
end

function UnloadBalesEarly.onBalerLoad(baler, superFunc, savegame)
    local spec = baler.spec_baler

	-- Execute base game behavior first
    superFunc(baler, savegame)

	-- Allow unloading bales early for every single baler
    print(("%s: Forcing early unload possibility for %s %s '%s' at '%d' liters"):format(MOD_NAME, baler.typeName, baler.brand.title, baler.configFileNameClean, spec.unfinishedBaleThreshold))
    spec.canUnloadUnfinishedBale = true
end
Baler.onLoad = Utils.overwrittenFunction(Baler.onLoad, UnloadBalesEarly.onBalerLoad)


function UnloadBalesEarly:onHandleUnloadingBaleEvent(baler, superFunc)
	local spec = baler.spec_baler
	if spec.unloadingState == Baler.UNLOADING_CLOSED and #spec.bales == 0 and baler:getCanUnloadUnfinishedBale() then
		-- We are unloading a bale early, but there is no bale yet. Create one, and trigger a fill level override since otherwise a full bale
		-- will be created
		self.overrideFillLevel = baler:getFillUnitFillLevel(spec.fillUnitIndex)
		baler:finishBale()
		self.overrideFillLevel = -1
	end

	-- Now that we made sure a bale was created if necessary, call the base game behavior
	superFunc(baler)
end

function UnloadBalesEarly:interceptBaleCreation(baler, superFunc, baleFillType, fillLevel, baleServerId, baleTime, xmlFileName)
	local adjustedFillLevel = fillLevel
	-- Override the fill level when unloading an unfinished bale
	if self.overrideFillLevel >= 0 then
		adjustedFillLevel = self.overrideFillLevel
	end
	-- Call the base game behavior with the adjusted fill level
	return superFunc(baler, baleFillType, adjustedFillLevel, baleServerId, baleTime, xmlFileName)
end

-- Create an instance so we can persist variables
local unloadBalesEarly = UnloadBalesEarly.new()

-- Override methods and inject the instance into the calls so the required variables can be accessed
Baler.handleUnloadingBaleEvent = Utils.overwrittenFunction(Baler.handleUnloadingBaleEvent, function(baler, superFunc)
	unloadBalesEarly:onHandleUnloadingBaleEvent(baler, superFunc)
end)
Baler.createBale = Utils.overwrittenFunction(Baler.createBale, function(baler, superFunc, baleFillType, fillLevel, baleServerId, baleTime, xmlFileName)
	return unloadBalesEarly:interceptBaleCreation(baler, superFunc, baleFillType, fillLevel, baleServerId, baleTime, xmlFileName)
end)