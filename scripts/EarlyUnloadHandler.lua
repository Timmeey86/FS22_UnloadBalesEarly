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
    print(("%s: Forcing early unload possibility for %s %s '%s'"):format(MOD_NAME, baler.typeName, baler.brand.title, baler.configFileNameClean))
	spec.canUnloadUnfinishedBale = true

	-- Remember the original threshold at which overloading is supposed to start for two-chamber balers
	if spec.buffer and spec.buffer.overloadingStartFillLevelPct then
		spec.originalOverloadPct = spec.buffer.overloadingStartFillLevelPct
	else
		spec.originalOverloadPct = 1
	end
	spec.overloadingThresholdIsOverridden = false
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

---Intercepts the action call in order to start overloading if necessary. 
---@param baler table @The baler instace
---@param superFunc function @The base game implementation
---@param param1 any @Unknown param (not needed, but forwarded to superFunc)
---@param param2 any @Unknown param (not needed, but forwarded to superFunc)
---@param param3 any @Unknown param (not needed, but forwarded to superFunc)
---@param param4 any @Unknown param (not needed, but forwarded to superFunc)
function EarlyUnloadHandler.onActionEventUnloading(baler, superFunc, param1, param2, param3, param4)
	local spec = baler.spec_baler
	if EarlyUnloadHandler.getCanOverloadBuffer(baler) then
		--Two-chamber vehicles: Reduce the overloading percentage so the baler starts unloading
		spec.buffer.overloadingStartFillLevelPct = g_currentMission.unloadBalesEarlySettings:getUnloadThresholdInPercent() / 100
		spec.overloadingThresholdIsOverridden = true
		-- Ignore the event in this case, don't forward it
	else
		-- Forward the event through base game mechanism in all other cases
		superFunc(baler, param1, param2, param3, param4)
	end
end

---Resets the overloading percentage threshold as soon as the baler has started overloading
---@param baler table  @The baler
---@param ... any @Any other unused parameters
function EarlyUnloadHandler.after_onUpdateTick(baler, ...)
	-- Reset the overloading percentage when unloading has started
	local spec = baler.spec_baler
	if spec.buffer.unloadingStarted and spec.overloadingThresholdIsOverridden then
		spec.buffer.overloadingStartFillLevelPct = spec.originalOverloadPct
		spec.overloadingThresholdIsOverridden = false
	end
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
		if EarlyUnloadHandler.getCanOverloadBuffer(baler) then
			-- Two-chamber balers like the JD Cotton Harvester or the modded Fendt Rotana 180 Xtra-V:
			-- Use the same action which will just trigger a different mechanism
			if spec.unloadingState == Baler.UNLOADING_CLOSED and not spec.platformReadyToDrop then
				g_inputBinding:setActionEventText(actionEvent.actionEventId, g_i18n:getText("ub_overload_early"))
				showAction = true
			end
		end
        if not showAction and baler:isUnloadingAllowed() and (spec.hasUnloadingAnimation or spec.allowsBaleUnloading) then
			-- Any other baler really
			if spec.unloadingState == Baler.UNLOADING_CLOSED then
				if baler:getCanUnloadUnfinishedBale() and not spec.platformReadyToDrop then
					g_inputBinding:setActionEventText(actionEvent.actionEventId, spec.texts.unloadUnfinishedBale)
					showAction = true
				end
			end
		end
		g_inputBinding:setActionEventActive(actionEvent.actionEventId, showAction)
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

	local spec = baler.spec_baler
	if baler.isClient and isActiveForInputIgnoreSelection then
		-- Add an "unload unfinished bale" function
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
    spec.unfinishedBaleThreshold = EarlyUnloadHandler.getUnfinishedBaleThreshold(baler, 1)
    -- Return the base game implementation now that we adjusted the threshold
    return superFunc(baler)
end

---Checks whether or not the buffer can be overloaded into the bale chamber for two-chamber balers.
---When the threshold is set to 0%, overloading will still require at least one liter as otherwise the option to unload would never show up
---@param baler table @The baler instance
---@return boolean @True if overloading is possible right now
function EarlyUnloadHandler.getCanOverloadBuffer(baler)
    local spec = baler.spec_baler
	-- Do not offer the option to overload if it's not a two chamber baler
	if spec.buffer.fillUnitIndex ~= 2 then
		return false
	end
	-- Göweil DLC (and maybe others): Do not offer the option if the baler always automatically overloads
	if spec.originalOverloadPct == 0 then
		return false
	end
	local requiredLiters = math.max(1, EarlyUnloadHandler.getUnfinishedBaleThreshold(baler, 2))
	return baler:getIsTurnedOn() and baler.spec_fillUnit.fillUnits[2].fillLevel >= requiredLiters
end

---Calculates the threshold for unloading bales for the given fill unit index
---@param baler table @The baler to be updated
---@param fillUnitIndex integer @The index of the relevant fill unit (either the bale chamber or the buffer chamber)
function EarlyUnloadHandler.getUnfinishedBaleThreshold(baler, fillUnitIndex)
	return baler:getFillUnitCapacity(fillUnitIndex) * g_currentMission.unloadBalesEarlySettings:getUnloadThresholdInPercent() / 100
end