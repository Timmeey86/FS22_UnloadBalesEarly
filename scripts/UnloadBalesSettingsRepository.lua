---@class UnloadBalesSettingsRepository
---This class is responsible for reading and writing settings
UnloadBalesSettingsRepository = {
    MAIN_KEY = "UnloadBalesEarly",
    UNLOAD_THRESHOLD_KEY = "UnloadThresholdIndex"
}

---Creates and returns an XML schema for the settings
---@return table @The XML schema
function UnloadBalesSettingsRepository.createRepository()
    local xmlSchema = XMLSchema.new(UnloadBalesSettingsRepository.MAIN_KEY)

    xmlSchema.register(XmlValueType.INT, UnloadBalesSettingsRepository.getPathForStateAttribute(UnloadBalesSettingsRepository.UNLOAD_THRESHOLD_KEY))

    return xmlSchema
end

---Writes the settings to our own XML file
function UnloadBalesSettingsRepository.storeSettings()
    local xmlPath = UnloadBalesSettingsRepository.getXmlFilePath()
    local settings = g_currentMission.unloadBalesEarlySettings
    if xmlPath == nil or settings == nil then
        Logging.warning(MOD_NAME .. ": Could not store settings")
        return
    end

    -- Cretae an empty XML file in memory
    local xmlFileId = createXMLFile("UnloadBalesEarly", xmlPath, UnloadBalesSettingsRepository.MAIN_KEY)

    -- Add XML data in memory
    setXMLInt(xmlFileId, UnloadBalesSettingsRepository.getPathForStateAttribute(UnloadBalesSettingsRepository.UNLOAD_THRESHOLD_KEY), settings.unloadThresholdIndex)

    -- Write the XML file to disk
    saveXMLFile(xmlFileId)
end

---Reads settings from an existing XML file, if such a file exists
function UnloadBalesSettingsRepository.restoreSettings()
    local xmlPath = UnloadBalesSettingsRepository.getXmlFilePath()
    local settings = g_currentMission.unloadBalesEarlySettings
    if xmlPath == nil or settings == nil then
        Logging.warning(MOD_NAME .. ": Could not read settings")
        return
    end

    -- Abort if no settings have been saved yet
    if not fileExists(xmlPath) then
        print(MOD_NAME .. ": No settings found, using default settings")
        return
    end

    -- Load the XML if possible
    local xmlFileId = loadXMLFile("UnloadBalesEarly", xmlPath)
    if xmlFileId == 0 then
        Logging.warning(MOD_NAME .. ": Failed reading from XML file")
        return
    end

    -- Read the values from memory
    settings.unloadThresholdIndex = getXMLInt(xmlFileId, UnloadBalesSettingsRepository.getPathForStateAttribute(UnloadBalesSettingsRepository.UNLOAD_THRESHOLD_KEY))

    print(MOD_NAME .. ": Successfully restored settings")
end

---Builds an XML path for a "state" attribute like a true/false switch or a selection of predefined values, but not a custom text, for example
---@param property string @The name of the XML property.
---@param parentProprety string|nil @The name of the parent proprety
---@return string @The path to the XML attribute
function UnloadBalesSettingsRepository.getPathForStateAttribute(property, parentProprety)
    return ("%s.%s#%s"):format(parentProprety or UnloadBalesSettingsRepository.MAIN_KEY, property, "state")
end

---Builds a path to the XML file.
---@return string|nil @The path to the XML file
function UnloadBalesSettingsRepository.getXmlFilePath()
    if g_currentMission.missionInfo then
        local savegameDirectory = g_currentMission.missionInfo.savegameDirectory
        if savegameDirectory ~= nil then
            return ("%s/%s.xml"):format(savegameDirectory, MOD_NAME)
        end
    end
    return nil
end