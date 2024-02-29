local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

UnloadBalesEarly = {}

---------------------------
--- Enable early unload ---
---------------------------

-- Create a handler for bale unloading
local earlyUnloadHandler = EarlyUnloadHandler.new()
-- Override methods and inject the instance into the calls so the required variables can be accessed
Baler.handleUnloadingBaleEvent = Utils.overwrittenFunction(Baler.handleUnloadingBaleEvent, function(baler, superFunc)
	earlyUnloadHandler:onHandleUnloadingBaleEvent(baler, superFunc)
end)
Baler.createBale = Utils.overwrittenFunction(Baler.createBale, function(baler, superFunc, baleFillType, fillLevel, baleServerId, baleTime, xmlFileName)
	return earlyUnloadHandler:interceptBaleCreation(baler, superFunc, baleFillType, fillLevel, baleServerId, baleTime, xmlFileName)
end)

-- Override methods which don't require any settings
Baler.onLoad = Utils.overwrittenFunction(Baler.onLoad, EarlyUnloadHandler.onBalerLoad)
Baler.updateActionEvents = Utils.overwrittenFunction(Baler.updateActionEvents, EarlyUnloadHandler.updateActionEvents)
Baler.onRegisterActionEvents = Utils.overwrittenFunction(Baler.onRegisterActionEvents, EarlyUnloadHandler.onRegisterActionEvents)
Baler.getCanUnloadUnfinishedBale = Utils.overwrittenFunction(Baler.getCanUnloadUnfinishedBale, EarlyUnloadHandler.getCanUnloadUnfinishedBale)
Baler.onUpdateTick = Utils.appendedFunction(Baler.onUpdateTick, EarlyUnloadHandler.after_onUpdateTick)
Baler.actionEventUnloading = Utils.overwrittenFunction(Baler.actionEventUnloading, EarlyUnloadHandler.onActionEventUnloading)

-----------------------
--- Enable settings ---
-----------------------

---Creates a settings object which can be accessed from the UI and the rest of the code
---@param   mission     table   @The object which is later available as g_currentMission
local function createModSettings(mission)
	-- Register the settings object globally so we can access it from the event class and others later
    mission.unloadBalesEarlySettings = UnloadBalesSettings.new()
    addModEventListener(mission.unloadBalesEarlySettings)
end
Mission00.load = Utils.prependedFunction(Mission00.load, createModSettings)

---Destroys the settings object when it is no longer needed.
local function destroyModSettings()
    if g_currentMission ~= nil and g_currentMission.unloadBalesEarlySettings ~= nil then
        removeModEventListener(g_currentMission.unloadBalesEarlySettings)
        g_currentMission.unloadBalesEarlySettings = nil
    end
end
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, destroyModSettings)

---Restore the settings when the map has finished loading
BaseMission.loadMapFinished = Utils.prependedFunction(BaseMission.loadMapFinished, function(...)
	UnloadBalesSettingsRepository.restoreSettings()
end)
-- Save settings when the savegame is being saved
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, UnloadBalesSettingsRepository.storeSettings)
