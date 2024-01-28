local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

UnloadBalesEarly = {}
function UnloadBalesEarly.onBalerLoad(baler, superFunc, savegame)
    local spec = baler.spec_baler

    superFunc(baler, savegame)

    print(("%s: Forcing early unload possibility for %s %s '%s' at '%d' liters"):format(MOD_NAME, baler.typeName, baler.brand.title, baler.configFileNameClean, spec.unfinishedBaleThreshold))
    spec.canUnloadUnfinishedBale = true
end
Baler.onLoad = Utils.overwrittenFunction(Baler.onLoad, UnloadBalesEarly.onBalerLoad)