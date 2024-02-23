---@class UnloadBalesSettingsChangeEvent
---This event is setn between client and server when an admin changes any setting in multiplayer
---It is also sent once when a client joins the server
UnloadBalesSettingsChangeEvent = {}
local UnloadBalesSettingsChangeEvent_mt = Class(UnloadBalesSettingsChangeEvent, Event)

InitEventClass(UnloadBalesSettingsChangeEvent, "UnloadBalesSettingsChangeEvent")

---Creates a new empty event
---@return table @The new instance
function UnloadBalesSettingsChangeEvent.emptyNew()
    return Event.new(UnloadBalesSettingsChangeEvent_mt)
end

---Creates a new event
---@return table @The new instance
function UnloadBalesSettingsChangeEvent.new()
    return UnloadBalesSettingsChangeEvent.emptyNew()
end

---Reads settings which were sent by another network participant and then applies them locally
---@param streamId any @The ID of the stream to read from.
---@param connection any @The connection which sent the event.
function UnloadBalesSettingsChangeEvent:readStream(streamId, connection)
    if g_currentMission and g_currentMission.unloadBalesEarlySettings then
        g_currentMission.unloadBalesEarlySettings:onReadStream(streamId, connection)

        local eventWasSentByServer = connection:getIsServer()
        if not eventWasSentByServer then
            -- We are the server. Boradcast the event to all other clients (except for the one which sent them)
            g_server:broadcastEvent(UnloadBalesSettingsChangeEvent.new(), nil, connection, nil)
        end
    else
        Logging.warning(MOD_NAME .. ": No settings object defined, ignoring settings sent by server")
    end
end

---Sends event data to another network participant
---@param streamId any @The stream ID.
---@param connection any @The connection to use.
function UnloadBalesSettingsChangeEvent:writeStream(streamId, connection)
    if g_currentMission and g_currentMission.unloadBalesEarlySettings then
        g_currentMission.unloadBalesEarlySettings:onWriteStream(streamId, connection)
    else
        Logging.warning(MOD_NAME .. ": No settings object defined, could not send settings update to client")
    end
end