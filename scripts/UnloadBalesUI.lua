UnloadBalesUI = {
    I18N_IDS = {
        GROUP_TITLE = 'ub_group_title',
        UNLOAD_THRESHOLD_LABEL = 'ub_unload_threshold_label',
        UNLOAD_THRESHOLD_DESC = 'ub_unload_threshold_desc'
    }
}

---Creates an element which allows choosing one out of several text values
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nLabelId           string      @The key used for looking up the translation of the label
---@param i18nDescriptionId     string      @The key used for looking up the translation of the description
---@param values                table       @A list of values
---@param callbackFunc          string      @The name of the function to call when the value changes
---@param isPercentage          boolean     @True if this is a percentage value
---@return                      table       @The created object
function UnloadBalesUI.createChoiceElement(generalSettingsPage, id, i18nLabelId, i18nDescriptionId, values, callbackFunc, isPercentage)
    -- Clone an existing element and adjust it, that's way easier than setting it up properly from scratch
    local element = generalSettingsPage.checkUseEasyArmControl:clone()

    -- Make sure our settings object receives events
    element.target = g_currentMission.unloadBalesEarlySettings
    -- Change ID, label, description and the function which shall be called on change
    element.id = id
    element:setLabel(g_i18n:getText(i18nLabelId))
    element.elements[6]:setText(g_i18n:getText(i18nDescriptionId))
    element:setCallback("onClickCallback", callbackFunc)
    -- Change the values
    local texts = {}
    for _, valueEntry in pairs(values) do
        local text = tostring(valueEntry)
        if isPercentage then
            text = text .. "%"
        end
        table.insert(texts, text)
    end
    element:setTexts(texts)

    -- Add the element to the settings page
    generalSettingsPage.boxLayout:addElement(element)

    return element
end

---This gets called every time the settings page gets opened
---@param   generalSettingsPage     table   @The instance of the base game's general settings page
function UnloadBalesUI.onFrameOpen(generalSettingsPage)
    -- Initialize on demand, and only update on each subsequent frame open
    if generalSettingsPage.unloadBalesEarlyInitialized then
        UnloadBalesUI.updateUiElements(generalSettingsPage)
        return
    end

    -- Create a section for our settings
    local groupTitle = TextElement.new()
    groupTitle:applyProfile("settingsMenuSubtitle", true)
    groupTitle:setText(g_i18n:getText(UnloadBalesUI.I18N_IDS.GROUP_TITLE))
    generalSettingsPage.boxLayout:addElement(groupTitle)

    -- Create elements for the actual settings
    generalSettingsPage.ub_unloadThresholdElement = UnloadBalesUI.createChoiceElement(
        generalSettingsPage, "ub_unloadThresholdElement", UnloadBalesUI.I18N_IDS.UNLOAD_THRESHOLD_LABEL, UnloadBalesUI.I18N_IDS.UNLOAD_THRESHOLD_DESC,
        UnloadBalesSettings.AVAILABLE_THRESHOLDS, "onUnloadThresholdChanged", true
    )

    -- Apply the initial values
    UnloadBalesUI.updateUiElements(generalSettingsPage)

    generalSettingsPage.unloadBalesEarlyInitialized = true
end

---Updates the UI elements to the current settings
---@param   generalSettingsPage     table   @The instance of the base game's general settings page
function UnloadBalesUI.updateUiElements(generalSettingsPage)
    local settings = g_currentMission.unloadBalesEarlySettings
    if settings == nil then
        Logging.warning(MOD_NAME .. ": Failed updating settings UI: global settings object not found")
        return
    end

    -- Reflect the current settings in the UI
    generalSettingsPage.ub_unloadThresholdElement:setState(settings:getUnloadThresholdIndex())

    -- Disable if multiplayer and player is not an admin
    local isAdmin = g_currentMission:getIsServer() or g_currentMission.isMasterUser
    generalSettingsPage.ub_unloadThresholdElement:setDisabled(not isAdmin)
end

-- Register overrides/extensions
InGameMenuGeneralSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGeneralSettingsFrame.onFrameOpen, UnloadBalesUI.onFrameOpen)
