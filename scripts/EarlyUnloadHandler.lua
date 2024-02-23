---@class EarlyUnloadHandler
---This class is responsible for allowing the player to unload bales early
---The logic for doing that is already in the game, we just have to enable it and do some calls to make sure the physics work properly
---for balers which weren't intended to have that functionality.
EarlyUnloadHandler = {}
local EarlyUnloadHandler_mt = Class(EarlyUnloadHandler)

---Creates a new instance
---@return table @The new instance
function EarlyUnloadHandler.new()
	local self = setmetatable({}, EarlyUnloadHandler_mt)
	self.overrideFillLevel = -1
	return self
end

---Allows unloading unfinished bales on all balers on load, independent of their XML settings
---@param baler table @The baler which is being loaded
---@param superFunc function @The base game implementation
---@param savegame table @The save game object
function EarlyUnloadHandler.onBalerLoad(baler, superFunc, savegame)
    local spec = baler.spec_baler

	-- Execute base game behavior first
    superFunc(baler, savegame)

	-- Allow unloading bales early for every single baler
    print(("%s: Forcing early unload possibility for %s %s '%s' at '%d' liters"):format(MOD_NAME, baler.typeName, baler.brand.title, baler.configFileNameClean, spec.unfinishedBaleThreshold))
    spec.EarlyUnloadHandlerEnabled = not spec.canUnloadUnfinishedBale
	spec.canUnloadUnfinishedBale = true
end

---Unloads the bale after the player pressed the hotkey
---@param baler table @The baler instance
---@param superFunc function @The base game implementation
function EarlyUnloadHandler:onHandleUnloadingBaleEvent(baler, superFunc)
	local spec = baler.spec_baler
	if spec.unloadingState == Baler.UNLOADING_CLOSED and #spec.bales == 0 and baler:getCanUnloadUnfinishedBale() then
		-- Remember the current fill level of the baler
		self.overrideFillLevel = baler:getFillUnitFillLevel(spec.fillUnitIndex)
		-- Set the bale to max fill level so the physics doesn't bug out when unloading
		local maxFillLevel = baler:getFillUnitCapacity(spec.fillUnitIndex)
		baler:updateDummyBale(spec.dummyBale, spec.fillTypeIndex, maxFillLevel, maxFillLevel)
		baler:setAnimationTime(spec.baleTypes[spec.currentBaleTypeIndex].animations.fill, 1)
		-- Finish the bale, which will override the fill level
		baler:finishBale()
		-- Reset the override so other bales will not fail
		self.overrideFillLevel = -1
	end

	-- Now that we made sure a bale was created if necessary, call the base game behavior
	superFunc(baler)
end

---Intercepts bale creation and adjusts the overrides the fill level, but only when finishBale() was called from within onHandleUnloadingBaleEvent
---This is done so the bale and bale physics are created for a full sized bale, but then the bale which will be dropped only has the actual amount 
---of liters.
---@param baler table @The baler instance
---@param superFunc function @The base game implementation
---@param baleFillType number @The type of bale (grass, cotton, ...)
---@param fillLevel number @The amount of liters in the bale
---@param baleServerId number @The ID of the bale on the server
---@param baleTime number @Not sure, probably an animation time
---@param xmlFileName string @The name of the XML which contains bale data (when loading)
---@return boolean @True if a valid bale was created
function EarlyUnloadHandler:interceptBaleCreation(baler, superFunc, baleFillType, fillLevel, baleServerId, baleTime, xmlFileName)
	local adjustedFillLevel = fillLevel
	-- Override the fill level when unloading an unfinished bale
	if self.overrideFillLevel >= 0 then
		adjustedFillLevel = self.overrideFillLevel
	end
	-- Call the base game behavior with the adjusted fill level
	return superFunc(baler, baleFillType, adjustedFillLevel, baleServerId, baleTime, xmlFileName)
end

---Enables or disables our hotkey for unloading bales, dependent on whether or not the threshold was reached
---@param baler table @The baler instance
---@param superFunc function @The base game implementation
function EarlyUnloadHandler.updateActionEvents(baler, superFunc)
	-- Enable base game actions
	superFunc(baler)

	-- Enable the unload early option when necessary
	local spec = baler.spec_baler
    local actionEvent = spec.actionEvents[InputAction.TOGGLE_PIPE]
    if actionEvent ~= nil then
		local showAction = false
        if baler:isUnloadingAllowed() and (spec.hasUnloadingAnimation or spec.allowsBaleUnloading) then
			if spec.unloadingState == Baler.UNLOADING_CLOSED then
				if baler:getCanUnloadUnfinishedBale() and not spec.platformReadyToDrop then
					g_inputBinding:setActionEventText(actionEvent.actionEventId, spec.texts.unloadUnfinishedBale)
					showAction = true
				end
			end
			g_inputBinding:setActionEventActive(actionEvent.actionEventId, showAction)
		end
    end
end

---Registers the action for unloading early when necessary
---@param baler table @The baler instance
---@param superFunc function @The base game implementation
---@param isActiveForInput boolean @True if the baler is the currently selected implement
---@param isActiveForInputIgnoreSelection boolean @True if the player is in a tractor which is connected to the baler
function EarlyUnloadHandler.onRegisterActionEvents(baler, superFunc, isActiveForInput, isActiveForInputIgnoreSelection)
	-- Create the base game actions first - this will clear the event list
	superFunc(baler, isActiveForInput, isActiveForInputIgnoreSelection)

	-- Now add an "unload now" option for balers which don't have them
	local spec = baler.spec_baler
	if baler.isClient and isActiveForInputIgnoreSelection then
		local _, actionEventId = baler:addPoweredActionEvent(spec.actionEvents, InputAction.TOGGLE_PIPE, baler, Baler.actionEventUnloading, false, true, false, true, nil)
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
	end

	-- Upade action events again to include our new option
	Baler.updateActionEvents(baler)
end

---Checks whether or not unfinished bales can be unloaded
---@param baler table @The baler instance
---@param superFunc function @The base game implementation
---@return boolean @True if the baler can unload right now
function EarlyUnloadHandler.getCanUnloadUnfinishedBale(baler, superFunc)
    -- Adjust the threshold now. This will also adjust it for functions which don't use the getter
    local spec = baler.spec_baler
    spec.unfinishedBaleThreshold = baler:getFillUnitCapacity(spec.fillUnitIndex) * g_currentMission.unloadBalesEarlySettings:getUnloadThresholdInPercent() / 100
    -- Return the base game implementation now that we adjusted the threshold
    return superFunc(baler)
end