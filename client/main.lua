-- ============================================
-- 🚪 RDE DOORS - CLIENT
-- ============================================
-- Version: 4.0.0 (ox_doorlock Feature Parity + Backward Compat)
-- Author: RDE | SerpentsByte
-- ============================================

local Ox, Config, L, json
local loadedDoors      = {}
local doorEntities     = {}  -- doorId → entity (single) or {a=entity, b=entity} (double)
local doorTargets      = {}
local doorGroups       = {}
local isSelectingDoor  = false
local selectionSphere  = nil
local playerLoaded     = false
local lastTargetUpdate = 0
local targetUpdateCooldown = 500
local activeTargets    = 0
local MAX_ACTIVE_TARGETS = 20
local DEBUG_MODE = true

-- v4: lockpick state tracking
local PickingLock     = false
local lastPickAttempt = 0

-- ============================================
-- 🎵 Sound Configuration
-- ============================================
local doorSounds = {
    lock   = { name = 'door_lock',          set = 'dlc_vinewood_casino_door_sounds' },
    unlock = { name = 'door_unlock',         set = 'dlc_vinewood_casino_door_sounds' },
    knock  = { name = 'knock_door',          set = 'dlc_vinewood_casino_door_sounds' },
    bell   = { name = 'apartment_doorbell',  set = 'dlc_vinewood_casino_door_sounds' },
}

-- ============================================
-- 🚪 v4: DOOR RATE & DISTANCE HELPERS
-- ============================================
local function GetDoorInteractDistance(door)
    if door and type(door.maxDistance) == 'number' and door.maxDistance > 0 then
        return door.maxDistance
    end
    return (Config and Config.UI and Config.UI.interactionDistance) or 2.5
end

local function GetDoorRate(door)
    if door.door_rate ~= nil and type(door.door_rate) == 'number' then
        return door.door_rate
    end
    if door.auto then
        return (Config and Config.Defaults and Config.Defaults.doorRateAuto) or 0.0
    end
    return (Config and Config.Defaults and Config.Defaults.doorRateSwing) or 10.0
end
local function debugPrint(...)
    if DEBUG_MODE then print('[RDE Doors | Client]', ...) end
end

local function GetPlayerCharId()
    if LocalPlayer.state.charId then return LocalPlayer.state.charId end
    if Ox then
        local player = Ox.GetPlayer()
        if player and player.charId then return player.charId end
    end
    return nil
end

local function WaitForPlayerLoad()
    local attempts = 0
    while attempts < 100 do
        if GetPlayerCharId() then
            playerLoaded = true
            debugPrint('Player loaded – CharID:', GetPlayerCharId())
            return true
        end
        Wait(200)
        attempts = attempts + 1
    end
    debugPrint('Player load timeout')
    return false
end

local function ShowNotification(title, description, type)
    lib.notify({
        title    = title,
        description = description,
        type     = type,
        icon     = type == 'success' and '✅' or (type == 'error' and '❌' or (type == 'warning' and '⚠️' or 'ℹ️')),
        iconAnimation = type == 'success' and 'beat' or nil,
    })
end

-- ============================================
-- 🎨 3D TEXT
-- ============================================
local function Draw3DText(coords, text)
    if not coords or not Config or not Config.UI then return end
    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoord()
    local distance  = #(vector3(coords.x, coords.y, coords.z) - camCoords)
    if distance > (Config.UI.textDistance or 5.0) then return end
    local scale = math.max(0.2, math.min(((Config.UI.textScale or 0.35) / distance) * 2, 0.5))
    SetTextScale(scale, scale)
    SetTextFont(Config.UI.textFont or 4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    if Config.UI.textOutline then
        SetTextDropshadow(1, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextOutline()
    end
    if Config.UI.textShadow then SetTextDropShadow() end
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- ============================================
-- 🚪 DOOR SYSTEM HELPERS
-- ============================================

-- Calculates the center point for 3D text on a single entity
local function CalculateDoorCenter(doorEntity)
    if not DoesEntityExist(doorEntity) then return nil end
    local doorCoords = GetEntityCoords(doorEntity)
    local model      = GetEntityModel(doorEntity)
    local min, max   = GetModelDimensions(model)
    if not min or not max then
        return vector3(doorCoords.x, doorCoords.y, doorCoords.z + 1.0)
    end
    local offsetX   = (max.x + min.x) / 2.0
    local offsetY   = (max.y + min.y) / 2.0
    local offsetZ   = (max.z + min.z) / 2.0
    local heading   = GetEntityHeading(doorEntity)
    local rad       = math.rad(heading)
    local rotX      = offsetX * math.cos(rad) - offsetY * math.sin(rad)
    local rotY      = offsetX * math.sin(rad) + offsetY * math.cos(rad)
    return vector3(doorCoords.x + rotX, doorCoords.y + rotY, doorCoords.z + offsetZ)
end

-- Returns the 3D text anchor for a door (midpoint for double, center for single)
local function GetTextAnchor(doorId, door)
    if door.door_a and door.door_b then
        -- Double door: midpoint between the two entities (or fallback to stored coords midpoint)
        local ents = doorEntities[doorId]
        if ents and type(ents) == 'table' and ents.a and ents.b and DoesEntityExist(ents.a) and DoesEntityExist(ents.b) then
            local ca = GetEntityCoords(ents.a)
            local cb = GetEntityCoords(ents.b)
            -- Take average of the two entity world positions, keep original Z height offset
            local midX = (ca.x + cb.x) / 2.0
            local midY = (ca.y + cb.y) / 2.0
            -- Use the higher center-height of the two doors for text
            local minA, maxA = GetModelDimensions(GetEntityModel(ents.a))
            local minB, maxB = GetModelDimensions(GetEntityModel(ents.b))
            local heightA = maxA and ((maxA.z + (minA and minA.z or 0.0)) / 2.0) or 1.0
            local heightB = maxB and ((maxB.z + (minB and minB.z or 0.0)) / 2.0) or 1.0
            local midZ = (ca.z + cb.z) / 2.0 + math.max(heightA, heightB)
            return vector3(midX, midY, midZ)
        else
            -- Fallback: use stored coords midpoint (always computed on server)
            return vector3(door.coords.x, door.coords.y, door.coords.z + 1.2)
        end
    else
        -- Single door: use entity geometry center
        local ent = doorEntities[doorId]
        if ent and DoesEntityExist(ent) then
            return CalculateDoorCenter(ent)
        end
        return vector3(door.coords.x, door.coords.y, door.coords.z + 1.0)
    end
end

local function IsValidDoorEntity(entity)
    if not DoesEntityExist(entity) then return false end
    if GetEntityType(entity) ~= 3 then return false end
    local min, max = GetModelDimensions(GetEntityModel(entity))
    if not min or not max then return false end
    return math.abs(max.z - min.z) > 1.5 and (math.abs(max.x - min.x) < 3.0 or math.abs(max.y - min.y) < 3.0)
end

local function GetDoorEntity(coords, model)
    if not coords then return 0, nil end
    local cv = type(coords) == 'table' and vector3(coords.x, coords.y, coords.z) or coords
    if model then
        local hash   = type(model) == 'string' and GetHashKey(model) or model
        local entity = GetClosestObjectOfType(cv.x, cv.y, cv.z, 5.0, hash, false, false, false)
        if DoesEntityExist(entity) and IsValidDoorEntity(entity) then
            return entity, hash
        end
    end
    local best, bestHash, bestDist = 0, nil, 999999.0
    for _, entity in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(entity) and IsValidDoorEntity(entity) then
            local ec   = GetEntityCoords(entity)
            local dist = #(cv - ec)
            if dist < 5.0 and dist < bestDist then
                best = entity; bestHash = GetEntityModel(entity); bestDist = dist
            end
        end
    end
    return best, bestHash
end

-- Registers a door with GTA's door system (both single and double)
-- v4: also sets AutomaticRate for sliding/garage/auto doors and hold_open
local function RegisterDoorsWithSystem(doorId, door)
    local rate = GetDoorRate(door)

    -- Helper: resolve model hash for AddDoorToSystem.
    -- Priority: model column (integer from GetEntityModel) > model string > model_hash fallback.
    -- DB stores model = GetEntityModel() integer directly (correct for GTA door system).
    -- model_hash was calculated differently and should NOT be used as primary source.
    local function resolveModelHash(m, mhash)
        -- model column: integer stored as number or numeric string (from GetEntityModel)
        if type(m) == 'number' and m ~= 0 then return m end
        if type(m) == 'string' and m ~= '' then
            local asInt = tonumber(m)
            if asInt and asInt ~= 0 then return asInt end
            return GetHashKey(m)  -- actual model name string like "v_res_fa_door"
        end
        -- fallback: model_hash column (last resort, may be incorrect for old doors)
        if type(mhash) == 'number' and mhash ~= 0 then return mhash end
        if type(mhash) == 'string' and mhash ~= '' then
            local asInt = tonumber(mhash)
            if asInt and asInt ~= 0 then return asInt end
        end
        return 0
    end

    if door.door_a and door.door_b then
        -- Double door: two entries, one hash each
        local hashA = joaat(('rde_door_%s_a'):format(doorId))
        local hashB = joaat(('rde_door_%s_b'):format(doorId))
        local ca = door.door_a.coords
        local cb = door.door_b.coords
        local modelHashA = resolveModelHash(door.door_a.model, door.door_a.model_hash)
        local modelHashB = resolveModelHash(door.door_b.model, door.door_b.model_hash)

        AddDoorToSystem(hashA, modelHashA, ca.x, ca.y, ca.z, false, false, false)
        DoorSystemSetDoorState(hashA, 4, false, false) -- reset
        DoorSystemSetAutomaticRate(hashA, rate, false, false)
        DoorSystemSetDoorState(hashA, door.locked and 1 or 0, false, false)
        if door.hold_open then DoorSystemSetHoldOpen(hashA, not door.locked) end

        AddDoorToSystem(hashB, modelHashB, cb.x, cb.y, cb.z, false, false, false)
        DoorSystemSetDoorState(hashB, 4, false, false)
        DoorSystemSetAutomaticRate(hashB, rate, false, false)
        DoorSystemSetDoorState(hashB, door.locked and 1 or 0, false, false)
        if door.hold_open then DoorSystemSetHoldOpen(hashB, not door.locked) end

        door.door_a._hash = hashA
        door.door_b._hash = hashB
    else
        -- Single door
        local hash      = joaat(('rde_door_%s'):format(doorId))
        local modelHash = resolveModelHash(door.model, door.model_hash)
        local c         = door.coords

        AddDoorToSystem(hash, modelHash, c.x, c.y, c.z, false, false, false)
        DoorSystemSetDoorState(hash, 4, false, false)
        DoorSystemSetAutomaticRate(hash, rate, false, false)
        DoorSystemSetDoorState(hash, door.locked and 1 or 0, false, false)
        if door.hold_open then DoorSystemSetHoldOpen(hash, not door.locked) end

        door._hash = hash
    end
end

local function SetDoorLockState(door, locked)
    local rate = GetDoorRate(door)
    if door.door_a and door.door_b then
        if door.door_a._hash then
            DoorSystemSetAutomaticRate(door.door_a._hash, rate, false, false)
            DoorSystemSetDoorState(door.door_a._hash, locked and 1 or 0, false, false)
            if door.hold_open then DoorSystemSetHoldOpen(door.door_a._hash, not locked) end
        end
        if door.door_b._hash then
            DoorSystemSetAutomaticRate(door.door_b._hash, rate, false, false)
            DoorSystemSetDoorState(door.door_b._hash, locked and 1 or 0, false, false)
            if door.hold_open then DoorSystemSetHoldOpen(door.door_b._hash, not locked) end
        end
    else
        if door._hash then
            DoorSystemSetAutomaticRate(door._hash, rate, false, false)
            DoorSystemSetDoorState(door._hash, locked and 1 or 0, false, false)
            if door.hold_open then DoorSystemSetHoldOpen(door._hash, not locked) end
        end
    end
end

local function PlayDoorSound(doorId, door, locked)
    local coords = door.coords
    if not coords then return end
    local soundName, soundSet
    if locked then
        soundName = (door.lock_sound and door.lock_sound ~= '') and door.lock_sound
                    or (Config and Config.Sounds and Config.Sounds.lockDefault and Config.Sounds.lockDefault.name)
                    or doorSounds.lock.name
        soundSet  = (Config and Config.Sounds and Config.Sounds.lockDefault and Config.Sounds.lockDefault.set)
                    or doorSounds.lock.set
    else
        soundName = (door.unlock_sound and door.unlock_sound ~= '') and door.unlock_sound
                    or (Config and Config.Sounds and Config.Sounds.unlockDefault and Config.Sounds.unlockDefault.name)
                    or doorSounds.unlock.name
        soundSet  = (Config and Config.Sounds and Config.Sounds.unlockDefault and Config.Sounds.unlockDefault.set)
                    or doorSounds.unlock.set
    end
    PlaySoundFromCoord(-1, soundName, coords.x, coords.y, coords.z, soundSet, false, 10.0, false)
end

-- ============================================
-- 🛡️ ACCESS CHECK (client — informational, server is authoritative)
-- ============================================
local function IsPlayerAdmin()
    local groups = LocalPlayer.state.groups
    if groups and (groups.admin or groups.superadmin) then return true end
    if Ox then
        local player = Ox.GetPlayer()
        if player then
            local pg = player.getGroups and player.getGroups() or {}
            if pg.admin or pg.superadmin then return true end
        end
    end
    return false
end

local function HasAccess(door)
    if IsPlayerAdmin() then return true end
    if not Ox then return false end
    local player = Ox.GetPlayer()
    if not player or not player.charId then return false end
    local charId = tostring(player.charId)
    if door.owner_charid and tostring(door.owner_charid) == charId then return true end
    if door.access_list then
        for _, id in ipairs(door.access_list) do
            if tostring(id) == charId then return true end
        end
    end
    -- groups/items/passcode are server-validated
    return false
end

-- ============================================
-- 🔧 LOCKPICK SYSTEM (v4)
-- ============================================
local function HasLockpickItem()
    if not exports.ox_inventory then return false end
    for _, itemName in ipairs(Config and Config.Lockpick and Config.Lockpick.items or {'lockpick'}) do
        if exports.ox_inventory:GetItemCount(itemName) > 0 then
            return true, itemName
        end
    end
    return false
end

local function StartLockpick(doorId)
    local door = loadedDoors[doorId]
    if not door or not door.lockpick then return end
    if PickingLock then return end
    if not door.locked and not (Config and Config.Lockpick and Config.Lockpick.canPickUnlocked) then return end
    if GetGameTimer() - lastPickAttempt < (Config and Config.Lockpick and Config.Lockpick.cooldownMs or 1500) then return end
    if not HasLockpickItem() then return end

    PickingLock = true
    lastPickAttempt = GetGameTimer()

    local anchorCoords = door.coords
    TaskTurnPedToFaceCoord(cache.ped, anchorCoords.x, anchorCoords.y, anchorCoords.z, 4000)
    Wait(400)

    local animDict = (Config and Config.Lockpick and Config.Lockpick.animDict) or 'mp_common_heist'
    local animName = (Config and Config.Lockpick and Config.Lockpick.animName) or 'pick_door'
    lib.requestAnimDict(animDict, 5000)
    TaskPlayAnim(cache.ped, animDict, animName, 3.0, 1.0, -1, 49, 0, true, true, true)
    ShowNotification(L and L.info or 'ℹ️', L and L.lockpickStarted or 'Picking lock...', 'inform')

    local difficulty = door.lockpick_difficulty
    if not difficulty or (type(difficulty) == 'table' and #difficulty == 0) then
        difficulty = (Config and Config.Lockpick and Config.Lockpick.defaultDifficulty) or { 'easy', 'easy', 'medium' }
    end

    local success = lib.skillCheck(difficulty, { 'w', 'a', 's', 'd' })
    StopAnimTask(cache.ped, animDict, animName, 1.0)
    RemoveAnimDict(animDict)
    PickingLock = false

    if success then
        ShowNotification(L and L.success or '✅', L and L.lockpickSuccess or 'Lock picked!', 'success')
        TriggerServerEvent('rde_doors:attemptLockpick', doorId)
    else
        ShowNotification(L and L.error or '❌', L and L.lockpickFailed or 'Lockpick failed', 'error')
        TriggerServerEvent('rde_doors:lockpickFailed', doorId)
    end
end

-- ============================================
-- 🔐 PASSCODE PROMPT (v4)
-- ============================================
local function PromptPasscodeAndToggle(doorId)
    local input = lib.inputDialog(L and L.passcodePrompt or 'Enter Passcode', {
        { type='input', label=L and L.passcode or 'Passcode', password=true, required=true, min=1, max=100, icon='lock' },
    })
    if not input or not input[1] then return end
    TriggerServerEvent('rde_doors:toggleLock', doorId, input[1])
end

-- ============================================
-- 🎯 TARGET SYSTEM
-- ============================================
local function RemoveDoorTarget(doorId)
    if not doorTargets[doorId] then return end
    local ents = doorEntities[doorId]
    if exports.ox_target then
        if type(ents) == 'table' then
            if ents.a and DoesEntityExist(ents.a) then exports.ox_target:removeLocalEntity(ents.a) end
            if ents.b and DoesEntityExist(ents.b) then exports.ox_target:removeLocalEntity(ents.b) end
        elseif ents and DoesEntityExist(ents) then
            exports.ox_target:removeLocalEntity(ents)
        end
    end
    doorTargets[doorId] = nil
    activeTargets = math.max(0, activeTargets - 1)
end

local function BuildTargetOptions(doorId, door)
    if not L then return {} end
    local interactDist = GetDoorInteractDistance(door)

    local function smartToggle()
        if HasAccess(door) then
            TriggerServerEvent('rde_doors:toggleLock', doorId)
        elseif door.has_passcode then
            PromptPasscodeAndToggle(doorId)
        else
            TriggerServerEvent('rde_doors:toggleLock', doorId)
        end
    end

    local options = {
        {
            name     = 'door_toggle_' .. doorId,
            label    = door.locked and L.unlock or L.lock,
            icon     = door.locked and (Config and Config.Icons and Config.Icons.unlock or '🔓') or (Config and Config.Icons and Config.Icons.lock or '🔒'),
            distance = interactDist,
            onSelect = smartToggle,
        },
        {
            name     = 'door_ring_' .. doorId,
            label    = L.ringBell,
            icon     = Config and Config.Icons and Config.Icons.bell or '🔔',
            distance = interactDist,
            onSelect = function()
                TriggerServerEvent('rde_doors:ringBell', doorId)
                PlaySoundFromCoord(-1, doorSounds.bell.name, door.coords.x, door.coords.y, door.coords.z, doorSounds.bell.set, false, 10.0, false)
            end,
            canInteract = function() return door.owner_charid ~= nil end,
        },
        {
            name     = 'door_knock_' .. doorId,
            label    = L.knock,
            icon     = Config and Config.Icons and Config.Icons.knock or '👊',
            distance = interactDist,
            onSelect = function()
                lib.requestAnimDict('timetable@jimmy@doorknock@', 5000)
                TaskPlayAnim(cache.ped, 'timetable@jimmy@doorknock@', 'knockdoor_idle', 8.0, -8.0, 1500, 48, 0, false, false, false)
                TriggerServerEvent('rde_doors:knock', doorId)
                PlaySoundFromCoord(-1, doorSounds.knock.name, door.coords.x, door.coords.y, door.coords.z, doorSounds.knock.set, false, 10.0, false)
            end,
            canInteract = function() return door.owner_charid ~= nil end,
        },
        {
            name     = 'door_buy_' .. doorId,
            label    = (L.buy or 'Buy') .. ' ($' .. (door.price or 0) .. ')',
            icon     = Config and Config.Icons and Config.Icons.buy or '💰',
            distance = interactDist,
            onSelect = function()
                lib.callback('rde_doors:buyDoor', false, function(success, message)
                    if not success then ShowNotification(L.error, message, 'error') end
                end, doorId)
            end,
            canInteract = function() return door.price and door.price > 0 and not door.owner_charid end,
        },
    }

    -- v4: Lockpick option
    if door.lockpick then
        table.insert(options, {
            name     = 'door_lockpick_' .. doorId,
            label    = L.pickLock or '🔧 Pick Lock',
            icon     = Config and Config.Icons and Config.Icons.lockpick or '🔧',
            distance = interactDist,
            onSelect = function() StartLockpick(doorId) end,
            canInteract = function()
                if PickingLock then return false end
                if not door.locked and not (Config and Config.Lockpick and Config.Lockpick.canPickUnlocked) then return false end
                return HasLockpickItem()
            end,
        })
    end

    if HasAccess(door) then
        table.insert(options, {
            name     = 'door_owner_' .. doorId,
            label    = L.manage,
            icon     = Config and Config.Icons and Config.Icons.manage or '🔧',
            distance = interactDist,
            onSelect = function() OpenOwnerMenu(doorId) end,
        })
    end

    if IsPlayerAdmin() then
        table.insert(options, {
            name     = 'door_admin_' .. doorId,
            label    = 'Admin Menu',
            icon     = Config and Config.Icons and Config.Icons.admin or '👑',
            distance = interactDist,
            onSelect = function() OpenAdminMenu(doorId) end,
        })
        table.insert(options, {
            name     = 'door_teleport_' .. doorId,
            label    = L.teleport,
            icon     = Config and Config.Icons and Config.Icons.map_pin or '📍',
            distance = interactDist,
            onSelect = function()
                DoScreenFadeOut(500); Wait(500)
                SetEntityCoords(cache.ped, door.coords.x, door.coords.y, door.coords.z, false, false, false, false)
                DoScreenFadeIn(500)
                ShowNotification(L.success, L.teleported, 'success')
            end,
        })
    end

    if door.group_id then
        table.insert(options, {
            name     = 'door_group_' .. doorId,
            label    = '📁 ' .. (doorGroups[door.group_id] and doorGroups[door.group_id].name or 'Unknown'),
            icon     = Config and Config.Icons and Config.Icons.door_group or '📁',
            distance = interactDist,
            onSelect = function() OpenDoorGroupMenu(door.group_id) end,
        })
    end

    if door.items and #door.items > 0 then
        for _, item in ipairs(door.items) do
            table.insert(options, {
                name     = 'door_item_' .. doorId .. '_' .. item,
                label    = string.format(L.itemRequired, item),
                icon     = '📦',
                distance = interactDist,
                onSelect = function()
                    lib.callback('rde_doors:useItem', false, function(success, message)
                        if success then ShowNotification(L.success, string.format(L.itemConsumed, item), 'success')
                        else ShowNotification(L.error, message, 'error') end
                    end, doorId, item)
                end,
                canInteract = function()
                    return exports.ox_inventory and exports.ox_inventory:GetItemCount(item) > 0
                end,
            })
        end
    end

    return options
end

local function CreateDoorTarget(doorId, door)
    if not doorId or not door or not door.coords or not L then return false end
    if doorTargets[doorId] then RemoveDoorTarget(doorId) end
    if activeTargets >= MAX_ACTIVE_TARGETS then return false end

    local options = BuildTargetOptions(doorId, door)

    if door.door_a and door.door_b then
        -- Double door: register both entities
        local entA = GetDoorEntity(door.door_a.coords, door.door_a.model)
        local entB = GetDoorEntity(door.door_b.coords, door.door_b.model)
        if not DoesEntityExist(entA) or not DoesEntityExist(entB) then return false end

        RegisterDoorsWithSystem(doorId, door)
        doorEntities[doorId] = { a = entA, b = entB }

        local ok = pcall(function()
            if exports.ox_target then
                -- Register same options on both door entities
                exports.ox_target:addLocalEntity(entA, options)
                exports.ox_target:addLocalEntity(entB, options)
            end
        end)
        if ok then
            doorTargets[doorId] = true
            activeTargets = activeTargets + 1
            return true
        end
    else
        -- Single door
        local entity = GetDoorEntity(door.coords, door.model)
        if not DoesEntityExist(entity) then return false end

        RegisterDoorsWithSystem(doorId, door)
        doorEntities[doorId] = entity

        local ok = pcall(function()
            if exports.ox_target then
                exports.ox_target:addLocalEntity(entity, options)
            end
        end)
        if ok then
            doorTargets[doorId] = true
            activeTargets = activeTargets + 1
            return true
        end
    end
    return false
end

-- ============================================
-- 📋 MENU FUNCTIONS
-- ============================================
function OpenOwnerMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    lib.registerContext({
        id    = 'door_owner_menu_' .. doorId,
        title = door.name or L.door,
        options = {
            {
                title = L.setPrice,
                description = door.price and door.price > 0 and ('Current: $' .. door.price) or L.notForSale,
                icon = Config and Config.Icons and Config.Icons.dollar_sign or '💲',
                onSelect = function()
                    local input = lib.inputDialog(L.setPrice, {{ type='number', label=L.price, default=door.price or 0, min=0, max=999999 }})
                    if input then TriggerServerEvent('rde_doors:setPrice', doorId, input[1]) end
                end,
            },
            {
                title = L.manageAccess,
                description = L.manageAccessDesc,
                icon = Config and Config.Icons and Config.Icons.user or '👤',
                onSelect = function() OpenAccessMenu(doorId) end,
            },
            {
                title = L.rename,
                description = 'Current: ' .. (door.name or 'Unnamed'),
                icon = Config and Config.Icons and Config.Icons.pen or '✏️',
                onSelect = function()
                    local input = lib.inputDialog(L.rename, {{ type='input', label=L.name, default=door.name, required=true, min=3, max=50 }})
                    if input then TriggerServerEvent('rde_doors:rename', doorId, input[1]) end
                end,
            },
            {
                title = door.locked and L.unlock or L.lock,
                description = L.toggleLock,
                icon = door.locked and (Config and Config.Icons and Config.Icons.lock or '🔒') or (Config and Config.Icons and Config.Icons.unlock or '🔓'),
                onSelect = function() TriggerServerEvent('rde_doors:toggleLock', doorId) end,
            },
            {
                title = L.teleport,
                description = L.teleportDesc,
                icon = Config and Config.Icons and Config.Icons.map_pin or '📍',
                onSelect = function()
                    DoScreenFadeOut(500); Wait(500)
                    SetEntityCoords(cache.ped, door.coords.x, door.coords.y, door.coords.z, false, false, false, false)
                    DoScreenFadeIn(500)
                    ShowNotification(L.success, L.teleported, 'success')
                end,
            },
        }
    })
    lib.showContext('door_owner_menu_' .. doorId)
end

function OpenAccessMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    local options = {
        {
            title = L.addPlayer,
            description = L.addPlayerDesc,
            icon = Config and Config.Icons and Config.Icons.user_plus or '👤➕',
            onSelect = function()
                local nearby = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), 10.0, true)
                if #nearby == 0 then ShowNotification(L.error, L.noPlayersNearby, 'error'); return end
                local playerOpts = {}
                for _, p in ipairs(nearby) do
                    table.insert(playerOpts, {
                        title = GetPlayerName(p.id) or 'Unknown',
                        description = 'ID: ' .. GetPlayerServerId(p.id),
                        icon = Config and Config.Icons and Config.Icons.user or '👤',
                        onSelect = function()
                            TriggerServerEvent('rde_doors:manageAccess', doorId, GetPlayerServerId(p.id), true)
                        end,
                    })
                end
                lib.registerContext({ id='add_player_menu_'..doorId, title=L.selectPlayer, options=playerOpts })
                lib.showContext('add_player_menu_' .. doorId)
            end,
        }
    }
    if door.access_list and #door.access_list > 0 then
        table.insert(options, {
            title = L.removePlayer,
            description = #door.access_list .. ' ' .. L.playersWithAccess,
            icon = Config and Config.Icons and Config.Icons.user_minus or '👤➖',
            onSelect = function()
                local removeOpts = {}
                for _, charId in ipairs(door.access_list) do
                    table.insert(removeOpts, {
                        title = 'CharID: ' .. charId,
                        description = L.revokeAccess,
                        icon = Config and Config.Icons and Config.Icons.user_xmark or '👤❌',
                        onSelect = function()
                            TriggerServerEvent('rde_doors:manageAccess', doorId, charId, false)
                        end,
                    })
                end
                lib.registerContext({ id='remove_player_menu_'..doorId, title=L.removeAccess, options=removeOpts })
                lib.showContext('remove_player_menu_' .. doorId)
            end,
        })
    end
    lib.registerContext({ id='access_menu_'..doorId, title=L.accessManagement, options=options })
    lib.showContext('access_menu_' .. doorId)
end

function OpenAdminMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    local typeOptions = {}
    for typeKey, typeData in pairs(Config and Config.DoorTypes or {}) do
        table.insert(typeOptions, { value = typeKey, label = typeData.name })
    end
    lib.registerContext({
        id    = 'door_admin_menu_' .. doorId,
        title = 'Admin – ' .. (door.name or L.door),
        options = {
            {
                title = L.editDoor,
                description = L.editDoorDesc,
                icon = Config and Config.Icons and Config.Icons.pen_square or '✏️',
                onSelect = function()
                    local input = lib.inputDialog(L.editDoor, {
                        { type='input',  label=L.name,  default=door.name, required=true },
                        { type='number', label=L.price, default=door.price or 0, min=0, max=999999 },
                        { type='select', label=L.type,  options=typeOptions, default=door.type },
                    })
                    if input then
                        TriggerServerEvent('rde_doors:updateDoor', doorId, { name=input[1], price=input[2], type=input[3] })
                    end
                end,
            },
            {
                title = L.advancedSettings or '⚙️ Advanced Settings',
                description = 'Lockpick, passcode, autolock, sounds, auto-rate, hide UI, hold open',
                icon = '⚙️',
                onSelect = function()
                    lib.registerContext({
                        id = 'door_advanced_menu_' .. doorId,
                        title = '⚙️ Advanced – ' .. (door.name or 'Door'),
                        options = {
                            {
                                title = (door.lockpick and '✅ ' or '❌ ') .. (L.lockpick or 'Lockpickable'),
                                icon = '🔧',
                                onSelect = function() TriggerServerEvent('rde_doors:updateDoor', doorId, { lockpick = not door.lockpick }) end,
                            },
                            {
                                title = 'Set Lockpick Difficulty',
                                description = door.lockpick_difficulty and table.concat(door.lockpick_difficulty, ',') or 'easy,easy,medium',
                                icon = '🎯',
                                onSelect = function()
                                    local input = lib.inputDialog('Lockpick Difficulty', {
                                        { type='input', label='Difficulty (e.g. easy,medium,hard)', default=door.lockpick_difficulty and table.concat(door.lockpick_difficulty,',') or 'easy,easy,medium' }
                                    })
                                    if input and input[1] then
                                        local parts = {}
                                        for p in input[1]:gmatch('[^,]+') do parts[#parts+1] = p:match('^%s*(.-)%s*$') end
                                        TriggerServerEvent('rde_doors:updateDoor', doorId, { lockpick_difficulty = parts })
                                    end
                                end,
                            },
                            {
                                title = door.has_passcode and '🔢 Change Passcode' or '🔢 Set Passcode',
                                icon = '🔢',
                                onSelect = function()
                                    local input = lib.inputDialog('Passcode', {
                                        { type='input', label='Passcode (empty to remove)', password=true }
                                    })
                                    if input then TriggerServerEvent('rde_doors:updateDoor', doorId, { passcode = input[1] or '' }) end
                                end,
                            },
                            {
                                title = 'Autolock Timer',
                                description = door.autolock and door.autolock > 0 and (door.autolock .. 's') or 'Off',
                                icon = '⏱️',
                                onSelect = function()
                                    local input = lib.inputDialog('Autolock', {
                                        { type='number', label='Seconds (0 = off)', default=door.autolock or 0, min=0, max=3600 }
                                    })
                                    if input then TriggerServerEvent('rde_doors:updateDoor', doorId, { autolock = input[1] }) end
                                end,
                            },
                            {
                                title = (door.auto and '✅ ' or '❌ ') .. 'Automatic Door (Sliding/Garage)',
                                icon = '🤖',
                                onSelect = function() TriggerServerEvent('rde_doors:updateDoor', doorId, { auto = not door.auto }) end,
                            },
                            {
                                title = 'Door Rate',
                                description = door.door_rate and ('Rate: ' .. door.door_rate) or 'Auto (0.0 if automatic, else 10.0)',
                                icon = '⚡',
                                onSelect = function()
                                    local input = lib.inputDialog('Door Rate', {
                                        { type='input', label='Rate (empty = auto)', default=door.door_rate and tostring(door.door_rate) or '' }
                                    })
                                    if input then
                                        local v = tonumber(input[1])
                                        TriggerServerEvent('rde_doors:updateDoor', doorId, { door_rate = v })
                                    end
                                end,
                            },
                            {
                                title = (door.hide_ui and '✅ ' or '❌ ') .. 'Hide UI',
                                icon = '🙈',
                                onSelect = function() TriggerServerEvent('rde_doors:updateDoor', doorId, { hide_ui = not door.hide_ui }) end,
                            },
                            {
                                title = (door.hold_open and '✅ ' or '❌ ') .. 'Hold Open When Unlocked',
                                icon = '🚪',
                                onSelect = function() TriggerServerEvent('rde_doors:updateDoor', doorId, { hold_open = not door.hold_open }) end,
                            },
                            {
                                title = 'Lock Sound',
                                description = door.lock_sound or 'Default',
                                icon = '🔊',
                                onSelect = function()
                                    local input = lib.inputDialog('Lock Sound', {
                                        { type='input', label='Sound name (empty = default)', default=door.lock_sound or '' }
                                    })
                                    if input then TriggerServerEvent('rde_doors:updateDoor', doorId, { lock_sound = input[1] or '' }) end
                                end,
                            },
                            {
                                title = 'Unlock Sound',
                                description = door.unlock_sound or 'Default',
                                icon = '🔊',
                                onSelect = function()
                                    local input = lib.inputDialog('Unlock Sound', {
                                        { type='input', label='Sound name (empty = default)', default=door.unlock_sound or '' }
                                    })
                                    if input then TriggerServerEvent('rde_doors:updateDoor', doorId, { unlock_sound = input[1] or '' }) end
                                end,
                            },
                            {
                                title = 'Interact Distance',
                                description = 'Current: ' .. (door.maxDistance or 2.5),
                                icon = '📏',
                                onSelect = function()
                                    local input = lib.inputDialog('Interact Distance', {
                                        { type='number', label='Distance (meters)', default=door.maxDistance or 2.5, min=0.5, max=10.0 }
                                    })
                                    if input then TriggerServerEvent('rde_doors:updateDoor', doorId, { maxDistance = input[1] }) end
                                end,
                            },
                        }
                    })
                    lib.showContext('door_advanced_menu_' .. doorId)
                end,
            },
            {
                title = L.deleteDoor,
                description = L.deleteDoorDesc,
                icon = Config and Config.Icons and Config.Icons.trash or '🗑️',
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header  = L.deleteDoor,
                        content = (L.deleteConfirm or 'Are you sure?') .. '\n\n' .. (door.name or 'Unnamed'),
                        centered = true, cancel = true,
                    })
                    if confirm == 'confirm' then TriggerServerEvent('rde_doors:deleteDoor', doorId) end
                end,
            },
            {
                title = L.teleport,
                description = L.teleportDesc,
                icon = Config and Config.Icons and Config.Icons.map_pin or '📍',
                onSelect = function()
                    DoScreenFadeOut(500); Wait(500)
                    SetEntityCoords(cache.ped, door.coords.x, door.coords.y, door.coords.z, false, false, false, false)
                    DoScreenFadeIn(500)
                    ShowNotification(L.success, L.teleported, 'success')
                end,
            },
            {
                title = 'Door Group Management',
                description = 'Add or remove from groups',
                icon = Config and Config.Icons and Config.Icons.door_group or '📁',
                onSelect = function() OpenDoorGroupAdminMenu(doorId) end,
            },
            {
                title = 'Set Required Items',
                description = 'Manage items required to open this door',
                icon = '📦',
                onSelect = function() OpenDoorItemsMenu(doorId) end,
            },
        }
    })
    lib.showContext('door_admin_menu_' .. doorId)
end

function OpenDoorGroupMenu(groupId)
    local group = doorGroups[groupId]
    if not group or not L then return end
    lib.registerContext({
        id    = 'door_group_menu_' .. groupId,
        title = '📁 ' .. group.name,
        options = {
            {
                title = 'Rename Group',
                icon  = Config and Config.Icons and Config.Icons.pen or '✏️',
                onSelect = function()
                    local input = lib.inputDialog('Rename Group', {{ type='input', label='Name', default=group.name, required=true, min=3, max=50 }})
                    if input then TriggerServerEvent('rde_doors:renameGroup', groupId, input[1]) end
                end,
            },
            {
                title = 'Delete Group',
                icon  = Config and Config.Icons and Config.Icons.trash or '🗑️',
                onSelect = function()
                    local confirm = lib.alertDialog({ header='Delete Group', content='Are you sure?\n\n'..group.name, centered=true, cancel=true })
                    if confirm == 'confirm' then TriggerServerEvent('rde_doors:deleteGroup', groupId) end
                end,
            },
            {
                title = 'Manage Group Doors',
                icon  = Config and Config.Icons and Config.Icons.door_group or '📁',
                onSelect = function() OpenGroupDoorsMenu(groupId) end,
            },
        }
    })
    lib.showContext('door_group_menu_' .. groupId)
end

function OpenDoorGroupAdminMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    local opts = {}
    for groupId, group in pairs(doorGroups) do
        table.insert(opts, {
            title = '📁 ' .. group.name,
            description = door.group_id == groupId and '✓ Currently in this group' or 'Click to add/remove',
            icon = Config and Config.Icons and Config.Icons.door_group or '📁',
            onSelect = function()
                if door.group_id == groupId then
                    TriggerServerEvent('rde_doors:removeFromGroup', doorId, groupId)
                else
                    TriggerServerEvent('rde_doors:addToGroup', doorId, groupId)
                end
            end,
        })
    end
    table.insert(opts, {
        title = 'Create New Group',
        icon  = Config and Config.Icons and Config.Icons.plus or '➕',
        onSelect = function()
            local input = lib.inputDialog('Create Door Group', {{ type='input', label='Name', required=true, min=3, max=50 }})
            if input then TriggerServerEvent('rde_doors:createGroup', input[1]) end
        end,
    })
    lib.registerContext({ id='door_group_admin_menu_'..doorId, title='Door Group Management', options=opts })
    lib.showContext('door_group_admin_menu_' .. doorId)
end

function OpenGroupDoorsMenu(groupId)
    local group = doorGroups[groupId]
    if not group or not L then return end
    local opts = {}
    for _, doorId in ipairs(group.doors) do
        local door = loadedDoors[doorId]
        if door then
            table.insert(opts, {
                title = (door.locked and '🔒 ' or '🔓 ') .. (door.name or 'Unnamed'),
                description = 'ID: ' .. doorId .. (door.door_a and ' [DOUBLE]' or ''),
                icon = door.locked and (Config and Config.Icons and Config.Icons.lock or '🔒') or (Config and Config.Icons and Config.Icons.unlock or '🔓'),
                onSelect = function() OpenAdminMenu(doorId) end,
            })
        end
    end
    lib.registerContext({ id='group_doors_menu_'..groupId, title='Doors in ' .. group.name, options=opts })
    lib.showContext('group_doors_menu_' .. groupId)
end

function OpenDoorItemsMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    local opts = {
        {
            title = 'Add Required Item',
            icon  = '📦',
            onSelect = function()
                local input = lib.inputDialog('Add Required Item', {{ type='input', label='Item Name', required=true }})
                if input then TriggerServerEvent('rde_doors:addDoorItem', doorId, input[1]) end
            end,
        }
    }
    if door.items and #door.items > 0 then
        for _, item in ipairs(door.items) do
            table.insert(opts, {
                title = item,
                description = 'Click to remove',
                icon  = '🗑️',
                onSelect = function() TriggerServerEvent('rde_doors:removeDoorItem', doorId, item) end,
            })
        end
    end
    lib.registerContext({ id='door_items_menu_'..doorId, title='Required Items – ' .. (door.name or 'Door'), options=opts })
    lib.showContext('door_items_menu_' .. doorId)
end

function OpenDoorManagerMenu()
    if not L then return end
    local opts = {
        {
            title = L.createDoor,
            description = L.createDoorDesc,
            icon  = Config and Config.Icons and Config.Icons.plus or '➕',
            onSelect = function() TriggerEvent('rde_doors:startDoorSelection') end,
        },
        {
            title = L.refreshDoors,
            description = L.refreshDoorsDesc,
            icon  = Config and Config.Icons and Config.Icons.rotate or '🔄',
            onSelect = function()
                TriggerServerEvent('rde_doors:requestSync')
                ShowNotification(L.success, L.doorsRefreshed, 'success')
            end,
        },
        {
            title = 'Door Group Manager',
            description = 'Manage door groups',
            icon  = Config and Config.Icons and Config.Icons.door_group or '📁',
            onSelect = function() OpenDoorGroupManagerMenu() end,
        },
    }
    local doorCount = 0
    for doorId, door in pairs(loadedDoors) do
        doorCount = doorCount + 1
        local typeData = Config and Config.DoorTypes and Config.DoorTypes[door.type]
        local typeName = typeData and typeData.name or (door.door_a and 'Double Door' or 'Single Door')
        table.insert(opts, {
            title = (door.locked and '🔒 ' or '🔓 ') .. (door.name or L.door),
            description = typeName .. ' | ' .. (door.owner_name or 'No Owner') .. ' | $' .. (door.price or 0),
            icon  = door.locked and (Config and Config.Icons and Config.Icons.lock or '🔒') or (Config and Config.Icons and Config.Icons.unlock or '🔓'),
            onSelect = function() OpenAdminMenu(doorId) end,
        })
    end
    lib.registerContext({ id='door_manager_menu', title='Door Manager (' .. doorCount .. ')', options=opts })
    lib.showContext('door_manager_menu')
end

function OpenDoorGroupManagerMenu()
    if not L then return end
    local opts = {
        {
            title = 'Create New Group',
            icon  = Config and Config.Icons and Config.Icons.plus or '➕',
            onSelect = function()
                local input = lib.inputDialog('Create Door Group', {{ type='input', label='Name', required=true, min=3, max=50 }})
                if input then TriggerServerEvent('rde_doors:createGroup', input[1]) end
            end,
        }
    }
    for groupId, group in pairs(doorGroups) do
        table.insert(opts, {
            title = '📁 ' .. group.name,
            description = #group.doors .. ' doors in group',
            icon  = Config and Config.Icons and Config.Icons.door_group or '📁',
            onSelect = function() OpenDoorGroupMenu(groupId) end,
        })
    end
    lib.registerContext({ id='door_group_manager_menu', title='Door Group Manager', options=opts })
    lib.showContext('door_group_manager_menu')
end

-- ============================================
-- 🎯 DOOR SELECTION (Single + Double)
-- ============================================
local function RotationToDirection(rotation)
    local z   = math.rad(rotation.z)
    local x   = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- Shared selection loop — lets admin pick one or two entities from the world
-- Returns either { entity } or { entityA, entityB } depending on doorCount
local function RunEntitySelectionLoop(doorCount, promptText)
    local selected = {}
    local sphere   = CreateObject(GetHashKey('prop_tennis_ball'), 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(sphere, 100, false)
    SetEntityCollision(sphere, false, false)
    FreezeEntityPosition(sphere, true)
    ShowNotification(L.selectingDoor, promptText or L.confirmSelection, 'inform')

    local cancelled = false
    CreateThread(function()
        while #selected < doorCount and not cancelled do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            local camCoords = GetGameplayCamCoord()
            local camRot    = GetGameplayCamRot(2)
            local dir       = RotationToDirection(camRot)
            local dest      = camCoords + (dir * 10.0)
            local ray       = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, dest.x, dest.y, dest.z, -1, -1, 0)
            local _, hit, endCoords, _, entityHit = GetShapeTestResult(ray)

            if DoesEntityExist(sphere) then
                SetEntityCoords(sphere, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
            end

            -- Highlight already selected entities
            for _, selEnt in ipairs(selected) do
                SetEntityDrawOutline(selEnt, true)
            end

            if IsDisabledControlJustPressed(0, 24) and hit and DoesEntityExist(entityHit) then
                if not IsValidDoorEntity(entityHit) then
                    ShowNotification(L.error, L.invalidDoor, 'error')
                else
                    -- Check not already selected
                    local alreadySel = false
                    for _, e in ipairs(selected) do if e == entityHit then alreadySel = true; break end end
                    if not alreadySel then
                        table.insert(selected, entityHit)
                        SetEntityDrawOutline(entityHit, true)
                        if #selected < doorCount then
                            ShowNotification(L.info or 'ℹ️ Info', ('Door %d/%d selected. Select door %d now.'):format(#selected, doorCount, #selected + 1), 'inform')
                        end
                    end
                end
            end

            if IsControlJustPressed(0, 25) then
                cancelled = true
            end
        end

        if DoesEntityExist(sphere) then DeleteEntity(sphere) end
        for _, e in ipairs(selected) do SetEntityDrawOutline(e, false) end
    end)

    -- Wait for the thread to finish
    while #selected < doorCount and not cancelled do Wait(100) end

    if cancelled then return nil end
    return selected
end

RegisterNetEvent('rde_doors:startDoorSelection', function()
    if isSelectingDoor or not L then return end
    isSelectingDoor = true

    -- Ask single or double via proper input select (alertDialog hat nur einen Button = verwirrend)
    local typeInput = lib.inputDialog(L.selectDoorType or 'Select Door Type', {
        {
            type    = 'select',
            label   = 'Door Type',
            options = {
                { value = 'single', label = '🚪  Single Door  —  one entity' },
                { value = 'double', label = '🚪🚪  Double Door  —  two entities that open together' },
            },
            default = 'single',
        },
    })

    if not typeInput then
        isSelectingDoor = false
        ShowNotification(L.cancelled, L.doorSelectionCancelled, 'inform')
        return
    end

    local isDouble = (typeInput[1] == 'double')

    if isDouble then
        -- Double door: select two entities
        ShowNotification(L.info or 'Info', 'Select the FIRST door entity (Left Click)', 'inform')
        local entities = RunEntitySelectionLoop(2, 'Select FIRST door → then SECOND door')
        if not entities or #entities < 2 then
            isSelectingDoor = false
            ShowNotification(L.cancelled, L.doorSelectionCancelled, 'inform')
            return
        end
        local entA, entB = entities[1], entities[2]
        local coordsA    = GetEntityCoords(entA)
        local coordsB    = GetEntityCoords(entB)
        local modelA     = GetEntityModel(entA)
        local modelB     = GetEntityModel(entB)
        local headingA   = GetEntityHeading(entA)
        local headingB   = GetEntityHeading(entB)

        -- Midpoint for display coords
        local midCoords = {
            x = (coordsA.x + coordsB.x) / 2.0,
            y = (coordsA.y + coordsB.y) / 2.0,
            z = (coordsA.z + coordsB.z) / 2.0,
        }

        local input = lib.inputDialog(L.createDoor, {
            { type='input',  label=L.name,  default=L.newDoor, required=true, min=3, max=50 },
            { type='number', label=L.price, default=0, min=0, max=999999 },
        })
        if input then
            TriggerServerEvent('rde_doors:createDoor', {
                name   = input[1],
                type   = 'double',
                coords = midCoords,
                model  = '',    -- no single model for double doors
                locked = true,
                price  = input[2],
                door_a = {
                    model   = GetHashKey and modelA or modelA,
                    coords  = { x = coordsA.x, y = coordsA.y, z = coordsA.z },
                    heading = headingA,
                },
                door_b = {
                    model   = modelB,
                    coords  = { x = coordsB.x, y = coordsB.y, z = coordsB.z },
                    heading = headingB,
                },
            })
        end
    else
        -- Single door
        local entities = RunEntitySelectionLoop(1, L.confirmSelection)
        if not entities or #entities < 1 then
            isSelectingDoor = false
            ShowNotification(L.cancelled, L.doorSelectionCancelled, 'inform')
            return
        end
        local entity    = entities[1]
        local doorCoords = GetEntityCoords(entity)
        local model      = GetEntityModel(entity)
        local heading    = GetEntityHeading(entity)

        local input = lib.inputDialog(L.createDoor, {
            { type='input',  label=L.name,  default=L.newDoor, required=true, min=3, max=50 },
            { type='number', label=L.price, default=0, min=0, max=999999 },
        })
        if input then
            TriggerServerEvent('rde_doors:createDoor', {
                name       = input[1],
                model      = '',          -- integer hash goes in model_hash, not model string
                model_hash = model,       -- GetEntityModel returns integer hash
                coords     = { x = doorCoords.x, y = doorCoords.y, z = doorCoords.z },
                heading    = heading,
                locked     = true,
                price      = input[2],
            })
        end
    end

    isSelectingDoor = false
end)

-- ============================================
-- 📡 NETWORK EVENTS
-- ============================================
RegisterNetEvent('rde_doors:syncDoors', function(serverDoors, serverGroups)
    if not serverDoors then return end
    for doorId in pairs(doorTargets) do RemoveDoorTarget(doorId) end
    doorTargets  = {}
    loadedDoors  = {}
    doorEntities = {}
    doorGroups   = serverGroups or {}
    activeTargets = 0
    for _, door in ipairs(serverDoors) do
        if door and door.id and door.coords then
            loadedDoors[door.id] = door
        end
    end
    if Config and Config.UI then
        local playerCoords = GetEntityCoords(PlayerPedId())
        for doorId, door in pairs(loadedDoors) do
            local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
            if dist <= (Config.UI.proximityLoadDistance or 30.0) then
                CreateDoorTarget(doorId, door)
            end
        end
    end
    debugPrint('Synced', #serverDoors, 'doors and', #serverGroups or 0, 'groups')
end)

RegisterNetEvent('rde_doors:doorUpdate', function(doorId, door)
    if not doorId or not door then return end
    local prev = loadedDoors[doorId]
    loadedDoors[doorId] = door
    -- v4: play sound if lock state changed
    if prev and prev.locked ~= door.locked then
        PlayDoorSound(doorId, door, door.locked)
    end
    -- Update lock state in GTA door system without full re-registration
    local ents = doorEntities[doorId]
    if ents then
        SetDoorLockState(door, door.locked)
    end
    -- Refresh target (re-registers + updated lock label)
    if Config and Config.UI then
        local playerCoords = GetEntityCoords(PlayerPedId())
        local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
        if dist <= (Config.UI.proximityLoadDistance or 30.0) then
            if doorTargets[doorId] then RemoveDoorTarget(doorId) end
            CreateDoorTarget(doorId, door)
        else
            RemoveDoorTarget(doorId)
        end
    end
end)

RegisterNetEvent('rde_doors:doorDeleted', function(doorId)
    RemoveDoorTarget(doorId)
    loadedDoors[doorId]  = nil
    doorEntities[doorId] = nil
end)

RegisterNetEvent('rde_doors:actionFeedback', function(success, message, doorId, action)
    if not L then return end
    if success then
        if action == 'create'             then ShowNotification(L.success, L.doorCreated, 'success')
        elseif action == 'update'         then ShowNotification(L.success, L.doorUpdated, 'success')
        elseif action == 'delete'         then ShowNotification(L.success, L.doorDeleted, 'success')
        elseif action == 'group_create'   then ShowNotification(L.success, L.doorGroupCreated, 'success')
        elseif action == 'group_delete'   then ShowNotification(L.success, L.doorGroupDeleted, 'success')
        elseif action == 'add_to_group'   then ShowNotification(L.success, L.doorAddedToGroup, 'success')
        elseif action == 'remove_from_group' then ShowNotification(L.success, L.doorRemovedFromGroup, 'success')
        end
    else
        ShowNotification(L.error, message or 'Error', 'error')
    end
end)

-- ============================================
-- 🔄 PROXIMITY MANAGEMENT
-- ============================================
CreateThread(function()
    while true do
        Wait(Config and Config.UI and Config.UI.proximityCheckInterval or 1000)
        if not playerLoaded or not Config or not Config.UI then goto continue end
        local playerCoords = GetEntityCoords(PlayerPedId())
        local t = GetGameTimer()
        if t - lastTargetUpdate < targetUpdateCooldown then goto continue end
        lastTargetUpdate = t
        for doorId, door in pairs(loadedDoors) do
            if door.coords then
                local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
                if not doorTargets[doorId] and dist <= (Config.UI.proximityLoadDistance or 30.0) then
                    CreateDoorTarget(doorId, door)
                elseif doorTargets[doorId] and dist > (Config.UI.proximityUnloadDistance or 35.0) then
                    RemoveDoorTarget(doorId)
                end
            end
        end
        ::continue::
    end
end)

-- Entity existence check (reload if disappeared)
CreateThread(function()
    while true do
        Wait(Config and Config.Performance and Config.Performance.entityCheckInterval or 5000)
        if not playerLoaded then goto continue end
        for doorId, ents in pairs(doorEntities) do
            local missing = false
            if type(ents) == 'table' then
                if (ents.a and not DoesEntityExist(ents.a)) or (ents.b and not DoesEntityExist(ents.b)) then
                    missing = true
                end
            elseif not DoesEntityExist(ents) then
                missing = true
            end
            if missing then
                local door = loadedDoors[doorId]
                if door then
                    RemoveDoorTarget(doorId)
                    CreateDoorTarget(doorId, door)
                end
            end
        end
        ::continue::
    end
end)

-- ============================================
-- 🎨 3D TEXT RENDERING
-- ============================================
CreateThread(function()
    while true do
        Wait(0)
        if not playerLoaded or not Config or not Config.UI or not Config.UI.use3DText or not L then
            Wait(1000)
            goto continue
        end
        local playerCoords = GetEntityCoords(PlayerPedId())
        local rendered     = false
        for doorId, door in pairs(loadedDoors) do
            if door.coords then
                local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
                if dist < (Config.UI.textDistance or 5.0) then
                    -- Get text anchor (midpoint for double, geometry center for single)
                    local anchor = GetTextAnchor(doorId, door)
                    if anchor then
                        local text = string.format('%s\n%s\n%s',
                            door.name or (L.door or 'Door'),
                            door.locked and ('🔒 ' .. (L.locked or 'Locked')) or ('🔓 ' .. (L.unlocked or 'Unlocked')),
                            door.owner_name or (L.noOwner or 'No Owner')
                        )
                        if door.price and door.price > 0 then
                            text = text .. '\n' .. (L.price or 'Price: $') .. tostring(door.price)
                        end
                        if door.group_id then
                            text = text .. '\n📁 ' .. (doorGroups[door.group_id] and doorGroups[door.group_id].name or 'Group')
                        end
                        if door.door_a then
                            text = text .. '\n🚪🚪 Double Door'
                        end
                        if door.items and #door.items > 0 then
                            text = text .. '\n📦 ' .. table.concat(door.items, ', ')
                        end
                        Draw3DText(anchor, text)
                        rendered = true
                    end
                end
            end
        end
        if not rendered then Wait(500) end
        ::continue::
    end
end)

-- ============================================
-- 🚀 INITIALIZATION
-- ============================================
CreateThread(function()
    json = json or require('json')
    while GetResourceState('ox_core') ~= 'started' do Wait(100) end
    local ok, result = pcall(require, '@ox_core/lib/init')
    if ok and result then
        Ox = result
        debugPrint('ox_core loaded successfully')
    else
        debugPrint('ox_core load failed, using fallback')
    end
    ok, result = pcall(require, 'shared.config')
    if ok and result then
        Config = result
        L = Config.Lang[Config.DefaultLanguage or 'en']
        MAX_ACTIVE_TARGETS    = Config.Performance and Config.Performance.maxActiveTargets or 20
        targetUpdateCooldown  = Config.UI and Config.UI.targetUpdateCooldown or 500
        DEBUG_MODE            = Config.Debug or true
        debugPrint('Config loaded')
    else
        debugPrint('Config load failed')
    end
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    while GetResourceState('ox_core') ~= 'started' do Wait(100) end
    if WaitForPlayerLoad() then
        Wait(1000)
        TriggerServerEvent('rde_doors:requestSync')
        debugPrint('Player initialized, requesting door sync')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    debugPrint('Cleaning up...')
    for doorId in pairs(doorTargets) do RemoveDoorTarget(doorId) end
    if selectionSphere and DoesEntityExist(selectionSphere) then DeleteEntity(selectionSphere) end
    debugPrint('Cleanup complete')
end)

AddEventHandler('ox:playerLoaded', function()
    debugPrint('Player loaded event triggered')
    if not playerLoaded then WaitForPlayerLoad() end
    Wait(500)
    TriggerServerEvent('rde_doors:requestSync')
end)

AddEventHandler('ox:playerLogout', function()
    debugPrint('Player logout event triggered')
    playerLoaded = false
    for doorId in pairs(doorTargets) do RemoveDoorTarget(doorId) end
end)

-- ============================================
-- 💬 COMMANDS
-- ============================================
RegisterCommand('createdoor', function()
    if not playerLoaded then ShowNotification('Error', 'Please wait for game to fully load', 'error'); return end
    lib.callback('rde_doors:checkAdmin', false, function(isAdmin)
        if isAdmin then
            TriggerEvent('rde_doors:startDoorSelection')
        else
            ShowNotification(L and L.error or 'Error', L and L.noPermission or 'No permission', 'error')
        end
    end)
end, false)

RegisterCommand('doormanager', function()
    if not playerLoaded then ShowNotification('Error', 'Please wait for game to fully load', 'error'); return end
    lib.callback('rde_doors:checkAdmin', false, function(isAdmin)
        if isAdmin then
            OpenDoorManagerMenu()
        else
            ShowNotification(L and L.error or 'Error', L and L.noPermission or 'No permission', 'error')
        end
    end)
end, false)

if DEBUG_MODE then
    RegisterCommand('doordebug', function()
        debugPrint('=== DOOR DEBUG INFO ===')
        debugPrint('Player Loaded:', playerLoaded)
        debugPrint('CharID:', GetPlayerCharId())
        local doorCount = 0
        local doubleCount = 0
        for _, door in pairs(loadedDoors) do
            doorCount = doorCount + 1
            if door.door_a then doubleCount = doubleCount + 1 end
        end
        debugPrint('Loaded Doors:', doorCount, '| Double Doors:', doubleCount)
        debugPrint('Active Targets:', activeTargets)
        debugPrint('========================')
        ShowNotification('Debug', 'Check F8 console for details', 'info')
    end, false)
end

-- ============================================
-- 🔧 v4: LOCKPICK RESULT EVENTS
-- ============================================
RegisterNetEvent('rde_doors:lockpickResult', function(success, doorId, broken)
    if not L then return end
    if success then
        ShowNotification(L.success, L.lockpickSuccess or 'Lock picked!', 'success')
    else
        ShowNotification(L.error, L.lockpickFailed or 'Lockpick failed', 'error')
    end
    if broken then
        ShowNotification(L.warning or '⚠️', L.lockpickBroken or 'Your lockpick broke!', 'warning')
    end
end)

-- ============================================
-- 🧩 v4: CLIENT EXPORTS (ox_doorlock-compatible)
-- ============================================
exports('getClosestDoor', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closest, closestDist = nil, 999999
    for _, door in pairs(loadedDoors) do
        if door.coords then
            local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
            if dist < closestDist then
                closestDist = dist
                closest = door
            end
        end
    end
    return closest
end)

exports('useClosestDoor', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestId, closestDist = nil, 999999
    for doorId, door in pairs(loadedDoors) do
        if door.coords then
            local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
            if dist < closestDist then
                closestDist = dist
                closestId = doorId
            end
        end
    end
    if closestId then TriggerServerEvent('rde_doors:toggleLock', closestId) end
end)

exports('pickClosestDoor', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestId, closestDist = nil, 999999
    for doorId, door in pairs(loadedDoors) do
        if door.coords and door.lockpick then
            local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
            if dist < closestDist then
                closestDist = dist
                closestId = doorId
            end
        end
    end
    if closestId then StartLockpick(closestId) end
end)


