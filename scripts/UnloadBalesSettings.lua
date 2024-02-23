---@class UnloadBalesSettings
---This class stores settings for the UnloadBalesEarly mod
UnloadBalesSettings = {
    -- Define possible unload thresholds in percent
    AVAILABLE_THRESHOLDS = {0, 10, 25, 33, 50, 66, 75, 90}
}
local UnloadBalesSettings_mt = Class(UnloadBalesSettings)

---Creates a new settings instance
---@return table @The new instance
function UnloadBalesSettings.new()
    local self = setmetatable({}, UnloadBalesSettings_mt)
    self.unloadThresholdIndex = 2 -- 10%
    return self
end

---Stores the new index (within AVAILABLE_THRESHOLDS)
---@param newState number @The new index
function UnloadBalesSettings:onUnloadThresholdChanged(newState)
    self.unloadThresholdIndex = newState
    self:publishNewSettings()
end

---Retrieves the index of the threshold to be displayed
---@return number @The current index
function UnloadBalesSettings:getUnloadThresholdIndex()
    return self.unloadThresholdIndex
end

---Retrieves the current unload threshold in percent
---@return number @The unload threshold in percent
function UnloadBalesSettings:getUnloadThresholdInPercent()
    return UnloadBalesSettings.AVAILABLE_THRESHOLDS[self.unloadThresholdIndex]
end

---Publishes new settings in case of multiplayer
function UnloadBalesSettings:publishNewSettings()
    if g_server ~= nil then
        -- Broadcast to other clients, if any are connected
        g_server:broadcastEvent(UnloadBalesSettingsChangeEvent.new())
    else
        -- Ask the server to broadcast the event
        g_client:getServerConnection():sendEvent(UnloadBalesSettingsChangeEvent.new())
    end
end

---Recevies the initial settings from the server when joining a multiplayer game
---@param streamId any @The ID of the stream to read from
---@param connection any @Unused
function UnloadBalesSettings:onReadStream(streamId, connection)
    print(MOD_NAME .. ": Receiving new settings")
    self.unloadThresholdIndex = streamReadInt8(streamId)
end

---Sends the current settings to a client which is connecting to a multiplayer game
---@param streamId any @The ID of the stream to write to
---@param connection any @Unused
function UnloadBalesSettings:onWriteStream(streamId, connection)
    print(MOD_NAME .. ": Sending new settings")
    streamWriteInt8(streamId, self.unloadThresholdIndex)
end