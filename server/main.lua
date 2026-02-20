-- ============================================
-- 🚪 RDE DOORS - SERVER (Next-Level)
-- ============================================
-- Version: 1.0.0 (Full ox_doorlock Integration + Next-Level Features)
-- Author: RDE | SerpentsByte
-- Features: Door Groups, Item Support, Admin System, Realism, Performance, Localization, Statebag-Sync, ox_inventory, Triple Admin Verification
-- ============================================

-- ============================================
-- 🔧 GLOBAL VARIABLES
-- ============================================
local Ox, Config, L
local doors = {}
local doorGroups = {}
local initialized = false
local resourceName = GetCurrentResourceName()
local doorStateBags = {}
local lastBroadcast = {}
local broadcastCooldown = 100

-- Load json immediately
local json = json or require('json')

-- ============================================
-- 📝 UTILITY FUNCTIONS (Defined First!)
-- ============================================
local function debugPrint(level, ...)
    local levelColors = {
        [1] = '^1[ERROR]^7',
        [2] = '^3[WARNING]^7',
        [3] = '^2[INFO]^7',
        [4] = '^5[VERBOSE]^7'
    }
    print('[RDE | Doors | Server]', levelColors[level] or '', ...)
end

local function GenerateUniqueId()
    return string.format('door_%s_%s', os.time(), math.random(100000, 999999))
end

local function GenerateGroupId()
    return string.format('group_%s_%s', os.time(), math.random(100000, 999999))
end

local function ValidateDoorData(data)
    if not data then
        return false, "No data provided"
    end
    if not data.name or data.name == "" then
        return false, "Name is required"
    end
    if not data.coords or type(data.coords) ~= 'table' then
        return false, "Valid coordinates required"
    end
    if not data.coords.x or not data.coords.y or not data.coords.z then
        return false, "Invalid coordinate format"
    end
    if type(data.coords.x) ~= 'number' or type(data.coords.y) ~= 'number' or type(data.coords.z) ~= 'number' then
        return false, "Coordinates must be numbers"
    end
    if not data.model then
        return false, "Model is required"
    end
    return true, "Valid"
end

local function SerializeCoords(coords)
    if type(coords) == 'table' then
        local x = type(coords.x) == 'number' and coords.x or 0.0
        local y = type(coords.y) == 'number' and coords.y or 0.0
        local z = type(coords.z) == 'number' and coords.z or 0.0
        return json.encode({x = x, y = y, z = z})
    end
    return coords
end

local function DeserializeCoords(coords)
    if type(coords) == 'string' then
        local success, result = pcall(json.decode, coords)
        if success and result then
            local x = type(result.x) == 'number' and result.x or 0.0
            local y = type(result.y) == 'number' and result.y or 0.0
            local z = type(result.z) == 'number' and result.z or 0.0
            return {x = x, y = y, z = z}
        end
    elseif type(coords) == 'table' then
        local x = type(coords.x) == 'number' and coords.x or 0.0
        local y = type(coords.y) == 'number' and coords.y or 0.0
        local z = type(coords.z) == 'number' and coords.z or 0.0
        return {x = x, y = y, z = z}
    end
    return nil
end

local function DoesDoorExistAtPosition(coords, excludeId)
    if not coords then return false end
    for doorId, door in pairs(doors) do
        if doorId ~= excludeId and door.coords then
            local dx = coords.x - door.coords.x
            local dy = coords.y - door.coords.y
            local dz = coords.z - door.coords.z
            local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
            if distance < 1.0 then
                return true, doorId
            end
        end
    end
    return false
end

local function SendActionFeedback(source, success, message, doorId, action)
    TriggerClientEvent('rde_doors:actionFeedback', source, success, message, doorId, action)
end

-- ============================================
-- 📡 NOSTR LOGGER
-- ============================================
-- API: exports['rde_nostr_log']:postLog(message, tags)
--   message : string  – human-readable log line (shown in Nostr feed)
--   tags    : table   – array of {key, value} pairs for filtering
-- See: https://github.com/RedDragonElite/rde_nostr_log
local function NostrLog(message, tags)
    if GetResourceState('rde_nostr_log') ~= 'started' then return end
    local ok, err = pcall(function()
        exports['rde_nostr_log']:postLog(message, tags or {})
    end)
    if not ok then
        debugPrint(2, '⚠️ NostrLog failed:', tostring(err))
    end
end

-- ============================================
-- 🛡️ ADMIN & ACCESS CONTROL
-- ============================================
local function IsPlayerAdmin(source)
    if not source or source == 0 then return false end
    -- Check ACE
    if IsPlayerAceAllowed(source, 'rde.doors.admin') then
        debugPrint(3, 'Admin verified (ACE):', GetPlayerName(source))
        return true
    end
    -- Check ox_core groups
    if Ox then
        local player = Ox.GetPlayer(source)
        if player and player.charId then
            local groups = player.getGroups and player.getGroups() or {}
            if groups.admin or groups.superadmin or groups.management then
                debugPrint(3, 'Admin verified (ox_core):', GetPlayerName(source))
                return true
            end
        end
    end
    return false
end

local function HasAccess(door, source)
    if not door or not source then return false end
    if IsPlayerAdmin(source) then return true end
    if not Ox then return false end
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then
        return false
    end
    local charId = tostring(player.charId)
    if door.owner_charid and tostring(door.owner_charid) == charId then
        return true
    end
    if door.access_list and type(door.access_list) == 'table' then
        for _, accessCharId in ipairs(door.access_list) do
            if tostring(accessCharId) == charId then
                return true
            end
        end
    end
    if door.auth and type(door.auth) == 'table' then
        local groups = player.getGroups and player.getGroups() or {}
        for groupName, _ in pairs(groups) do
            for _, authGroup in ipairs(door.auth) do
                if groupName == authGroup then
                    return true
                end
            end
        end
    end
    if door.items and type(door.items) == 'table' and exports.ox_inventory then
        for _, item in ipairs(door.items) do
            local itemCount = exports.ox_inventory:GetItemCount(source, item)
            if itemCount and itemCount > 0 then
                return true
            end
        end
    end
    return false
end

-- ============================================
-- 💾 DATABASE OPERATIONS
-- ============================================
local function InitializeDatabase()
    if not MySQL then
        debugPrint(1, '❌ MySQL not available')
        return false
    end
    local success = pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS rde_owned_doors (
                id VARCHAR(50) PRIMARY KEY,
                type VARCHAR(20) DEFAULT 'single',
                name VARCHAR(100) NOT NULL,
                coords LONGTEXT NOT NULL,
                model VARCHAR(100) NOT NULL,
                model_hash VARCHAR(50),
                locked TINYINT(1) DEFAULT 1,
                auth LONGTEXT DEFAULT '[]',
                autolock INT DEFAULT 0,
                items LONGTEXT DEFAULT '[]',
                heading FLOAT DEFAULT 0.0,
                maxDistance FLOAT DEFAULT 2.5,
                owner_charid VARCHAR(50),
                owner_name VARCHAR(100),
                price INT DEFAULT 0,
                access_list LONGTEXT DEFAULT '[]',
                group_id VARCHAR(50),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]])
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS rde_door_groups (
                id VARCHAR(50) PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                doors LONGTEXT DEFAULT '[]',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]])
    end)
    if success then
        debugPrint(3, '✅ Database initialized')
        return true
    else
        debugPrint(1, '❌ Database initialization failed')
        return false
    end
end

local function LoadDoors()
    if not MySQL then
        debugPrint(1, '❌ MySQL not available')
        return false
    end
    local success, result = pcall(function()
        return MySQL.query.await('SELECT * FROM rde_owned_doors')
    end)
    if not success then
        debugPrint(1, '❌ Failed to load doors')
        return false
    end
    doors = {}
    local count = 0
    local invalidCount = 0
    if result and type(result) == 'table' then
        for _, dbDoor in ipairs(result) do
            if dbDoor and dbDoor.id then
                local doorId = dbDoor.id
                local coords = DeserializeCoords(dbDoor.coords)
                if coords then
                    doors[doorId] = {
                        id = doorId,
                        type = dbDoor.type or 'single',
                        name = dbDoor.name,
                        coords = coords,
                        model = dbDoor.model,
                        model_hash = dbDoor.model_hash or GetHashKey(dbDoor.model),
                        locked = (dbDoor.locked == 1 or dbDoor.locked == true),
                        auth = type(dbDoor.auth) == 'string' and json.decode(dbDoor.auth) or {},
                        autolock = dbDoor.autolock or 0,
                        items = type(dbDoor.items) == 'string' and json.decode(dbDoor.items) or {},
                        heading = dbDoor.heading or 0.0,
                        maxDistance = dbDoor.maxDistance or 2.5,
                        owner_charid = dbDoor.owner_charid,
                        owner_name = dbDoor.owner_name,
                        price = dbDoor.price or 0,
                        access_list = type(dbDoor.access_list) == 'string' and json.decode(dbDoor.access_list) or {},
                        group_id = dbDoor.group_id
                    }
                    count = count + 1
                    doorStateBags[doorId] = true
                else
                    debugPrint(2, '⚠️ Invalid coordinates for door:', doorId)
                    invalidCount = invalidCount + 1
                end
            end
        end
    end
    initialized = true
    debugPrint(3, '✅ Loaded', count, 'doors (', invalidCount, 'invalid skipped)')
    return true
end

local function LoadDoorGroups()
    if not MySQL then
        debugPrint(1, '❌ MySQL not available')
        return false
    end
    local success, result = pcall(function()
        return MySQL.query.await('SELECT * FROM rde_door_groups')
    end)
    if not success then
        debugPrint(1, '❌ Failed to load door groups')
        return false
    end
    doorGroups = {}
    local count = 0
    if result and type(result) == 'table' then
        for _, dbGroup in ipairs(result) do
            if dbGroup and dbGroup.id then
                local groupId = dbGroup.id
                doorGroups[groupId] = {
                    id = groupId,
                    name = dbGroup.name,
                    doors = type(dbGroup.doors) == 'string' and json.decode(dbGroup.doors) or {}
                }
                count = count + 1
            end
        end
    end
    debugPrint(3, '✅ Loaded', count, 'door groups')
    return true
end

local function SaveDoor(doorId, doorData)
    if not MySQL or not doorId or not doorData then return false end
    if not doorData.coords or type(doorData.coords.x) ~= 'number' or type(doorData.coords.y) ~= 'number' or type(doorData.coords.z) ~= 'number' then
        debugPrint(1, '❌ Invalid coordinates for door:', doorId)
        return false
    end
    local success = pcall(function()
        MySQL.update.await([[
            UPDATE rde_owned_doors
            SET type = ?, name = ?, coords = ?, model = ?, model_hash = ?,
                locked = ?, auth = ?, autolock = ?, items = ?, heading = ?,
                maxDistance = ?, owner_charid = ?, owner_name = ?, price = ?, access_list = ?, group_id = ?
            WHERE id = ?
        ]], {
            doorData.type,
            doorData.name,
            SerializeCoords(doorData.coords),
            doorData.model,
            doorData.model_hash,
            doorData.locked and 1 or 0,
            json.encode(doorData.auth or {}),
            doorData.autolock,
            json.encode(doorData.items or {}),
            doorData.heading,
            doorData.maxDistance,
            doorData.owner_charid,
            doorData.owner_name,
            doorData.price,
            json.encode(doorData.access_list or {}),
            doorData.group_id,
            doorId
        })
    end)
    return success
end

local function CreateDoor(doorId, doorData)
    if not MySQL or not doorId or not doorData then return false end
    if not doorData.coords or type(doorData.coords.x) ~= 'number' or type(doorData.coords.y) ~= 'number' or type(doorData.coords.z) ~= 'number' then
        debugPrint(1, '❌ Invalid coordinates for new door:', doorId)
        return false
    end
    local exists, existingDoorId = DoesDoorExistAtPosition(doorData.coords, doorId)
    if exists then
        debugPrint(2, '⚠️ Door already exists at this position - Existing ID:', existingDoorId)
        return false
    end
    local success = pcall(function()
        MySQL.insert.await([[
            INSERT INTO rde_owned_doors
            (id, type, name, coords, model, model_hash, locked, auth, autolock, items, heading, maxDistance, owner_charid, owner_name, price, access_list, group_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            doorId,
            doorData.type or 'single',
            doorData.name,
            SerializeCoords(doorData.coords),
            doorData.model,
            doorData.model_hash or GetHashKey(doorData.model),
            doorData.locked and 1 or 0,
            json.encode(doorData.auth or {}),
            doorData.autolock or 0,
            json.encode(doorData.items or {}),
            doorData.heading or 0.0,
            doorData.maxDistance or 2.5,
            doorData.owner_charid,
            doorData.owner_name,
            doorData.price or 0,
            json.encode(doorData.access_list or {}),
            doorData.group_id
        })
    end)
    return success
end

local function DeleteDoor(doorId)
    if not MySQL or not doorId then return false end
    local success = pcall(function()
        MySQL.query.await('DELETE FROM rde_owned_doors WHERE id = ?', {doorId})
    end)
    return success
end

local function SaveDoorGroup(groupId, groupData)
    if not MySQL or not groupId or not groupData then return false end
    local success = pcall(function()
        MySQL.update.await([[
            UPDATE rde_door_groups
            SET name = ?, doors = ?
            WHERE id = ?
        ]], {
            groupData.name,
            json.encode(groupData.doors or {}),
            groupId
        })
    end)
    return success
end

local function CreateDoorGroup(groupId, groupData)
    if not MySQL or not groupId or not groupData then return false end
    local success = pcall(function()
        MySQL.insert.await([[
            INSERT INTO rde_door_groups
            (id, name, doors)
            VALUES (?, ?, ?)
        ]], {
            groupId,
            groupData.name,
            json.encode(groupData.doors or {})
        })
    end)
    return success
end

local function DeleteDoorGroup(groupId)
    if not MySQL or not groupId then return false end
    local success = pcall(function()
        MySQL.query.await('DELETE FROM rde_door_groups WHERE id = ?', {groupId})
    end)
    return success
end

-- ============================================
-- 📡 SYNCHRONIZATION
-- ============================================
local function BroadcastDoorUpdate(doorId, doorData)
    if not doorId or not doorData then return end
    if not doorData.coords or type(doorData.coords.x) ~= 'number' or type(doorData.coords.y) ~= 'number' or type(doorData.coords.z) ~= 'number' then
        debugPrint(1, '❌ Invalid coordinates in door update broadcast:', doorId)
        return
    end
    local currentTime = GetGameTimer()
    if lastBroadcast[doorId] and (currentTime - lastBroadcast[doorId] < broadcastCooldown) then
        return
    end
    lastBroadcast[doorId] = currentTime
    TriggerClientEvent('rde_doors:doorUpdate', -1, doorId, doorData)
    debugPrint(4, '📢 Broadcast update:', doorId, '| Locked:', doorData.locked)
end

local function BroadcastDoorDelete(doorId)
    if not doorId then return end
    TriggerClientEvent('rde_doors:doorDeleted', -1, doorId)
    debugPrint(4, '📢 Broadcast delete:', doorId)
end

local function BroadcastDoorGroupUpdate(groupId, groupData)
    if not groupId or not groupData then return end
    TriggerClientEvent('rde_doors:doorGroupUpdate', -1, groupId, groupData)
    debugPrint(4, '📢 Broadcast group update:', groupId, '| Name:', groupData.name)
end

local function BroadcastDoorGroupDelete(groupId)
    if not groupId then return end
    TriggerClientEvent('rde_doors:doorGroupDeleted', -1, groupId)
    debugPrint(4, '📢 Broadcast group delete:', groupId)
end

local function SyncAllDoors(source)
    if not source then return end
    local attempts = 0
    while not initialized and attempts < 20 do
        Wait(100)
        attempts = attempts + 1
    end
    if not initialized then
        debugPrint(2, '⚠️ Sync requested but doors not initialized')
        return
    end
    local doorArray = {}
    for _, door in pairs(doors) do
        if door.coords and type(door.coords.x) == 'number' and type(door.coords.y) == 'number' and type(door.coords.z) == 'number' then
            table.insert(doorArray, door)
        end
    end
    TriggerClientEvent('rde_doors:syncDoors', source, doorArray, doorGroups)
    debugPrint(3, '📤 Synced', #doorArray, 'doors and', #doorGroups or 0, 'groups to', GetPlayerName(source))
end

-- ============================================
-- 🔄 CALLBACKS
-- ============================================
lib.callback.register('rde_doors:checkAdmin', function(source)
    return IsPlayerAdmin(source)
end)

lib.callback.register('rde_doors:checkAccess', function(source, doorId)
    local door = doors[doorId]
    if not door then return false end
    return HasAccess(door, source)
end)

lib.callback.register('rde_doors:buyDoor', function(source, doorId)
    local door = doors[doorId]
    if not door or door.price <= 0 or door.owner_charid then
        return false, 'Door not available'
    end
    if not Ox then
        return false, 'Framework error'
    end
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then
        return false, 'Player data error'
    end
    if not exports.ox_inventory then
        return false, 'Inventory system not available'
    end
    local moneyCount = exports.ox_inventory:GetItemCount(source, 'money')
    if moneyCount < door.price then
        return false, 'Not enough money'
    end
    local transactionSuccess = exports.ox_inventory:RemoveItem(source, 'money', door.price)
    if not transactionSuccess then
        return false, 'Transaction failed'
    end
    door.owner_charid = tostring(player.charId)
    door.owner_name = (player.get('firstName') or 'Unknown') .. ' ' .. (player.get('lastName') or 'Player')
    door.price = 0
    if not SaveDoor(doorId, door) then
        exports.ox_inventory:AddItem(source, 'money', door.price)
        return false, 'Failed to save door'
    end
    doors[doorId] = door
    BroadcastDoorUpdate(doorId, door)
    NostrLog(
        string.format('💳 Door purchased: %s | By: %s (CharID: %s)', door.name, GetPlayerName(source), tostring(player.charId)),
        {{'event', 'door_purchased'}, {'doorId', doorId}, {'doorName', door.name}, {'charId', tostring(player.charId)}, {'player', GetPlayerName(source)}}
    )
    return true, 'Purchase successful'
end)

lib.callback.register('rde_doors:useItem', function(source, doorId, item)
    local door = doors[doorId]
    if not door or not door.items or not exports.ox_inventory then
        return false, 'Invalid door or item'
    end
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then
        return false, 'Player data error'
    end
    local itemCount = exports.ox_inventory:GetItemCount(source, item)
    if itemCount <= 0 then
        return false, 'Missing required item'
    end
    if not exports.ox_inventory:RemoveItem(source, item, 1) then
        return false, 'Failed to use item'
    end
    if door.locked then
        door.locked = false
        doors[doorId] = door
        SaveDoor(doorId, door)
        BroadcastDoorUpdate(doorId, door)
    end
    return true, 'Item used successfully'
end)

-- ============================================
-- 🎮 EVENT HANDLERS
-- ============================================
RegisterNetEvent('rde_doors:requestSync', function()
    local src = source
    if not src then return end
    debugPrint(4, '📥 Sync requested by:', GetPlayerName(src))
    CreateThread(function()
        SyncAllDoors(src)
    end)
end)

RegisterNetEvent('rde_doors:toggleLock', function(doorId)
    local src = source
    local door = doors[doorId]
    if not door then
        SendActionFeedback(src, false, 'Door not found', doorId, 'toggle')
        return
    end
    if not HasAccess(door, src) then
        SendActionFeedback(src, false, 'Access denied', doorId, 'toggle')
        return
    end
    door.locked = not door.locked
    doors[doorId] = door
    CreateThread(function()
        SaveDoor(doorId, door)
    end)
    BroadcastDoorUpdate(doorId, door)
    local statusText = door.locked and 'Locked' or 'Unlocked'
    SendActionFeedback(src, true, statusText, doorId, 'toggle')
    debugPrint(3, '🔒 Door', statusText, '| ID:', doorId, '| Player:', GetPlayerName(src))
    NostrLog(
        string.format('🔒 Door %s | %s | By: %s', statusText, door.name, GetPlayerName(src)),
        {{'event', 'door_toggle'}, {'doorId', doorId}, {'status', statusText}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:createDoor', function(doorData)
    local src = source
    if not IsPlayerAdmin(src) then
        SendActionFeedback(src, false, 'No permission', nil, 'create')
        return
    end
    local valid, message = ValidateDoorData(doorData)
    if not valid then
        SendActionFeedback(src, false, message, nil, 'create')
        return
    end
    local doorId = GenerateUniqueId()
    local exists, existingDoorId = DoesDoorExistAtPosition(doorData.coords)
    if exists then
        SendActionFeedback(src, false, 'Door already exists', existingDoorId, 'create')
        return
    end
    doorData.coords = {
        x = type(doorData.coords.x) == 'number' and doorData.coords.x or 0.0,
        y = type(doorData.coords.y) == 'number' and doorData.coords.y or 0.0,
        z = type(doorData.coords.z) == 'number' and doorData.coords.z or 0.0
    }
    doorData.model_hash = doorData.model_hash or GetHashKey(doorData.model)
    doorData.locked = doorData.locked == nil and true or doorData.locked
    doorData.auth = doorData.auth or {}
    doorData.items = doorData.items or {}
    doorData.access_list = doorData.access_list or {}
    if not CreateDoor(doorId, doorData) then
        SendActionFeedback(src, false, 'Door creation failed', doorId, 'create')
        return
    end
    doors[doorId] = {
        id = doorId,
        type = doorData.type or 'single',
        name = doorData.name,
        coords = doorData.coords,
        model = doorData.model,
        model_hash = doorData.model_hash,
        locked = doorData.locked,
        auth = doorData.auth,
        autolock = doorData.autolock or 0,
        items = doorData.items,
        heading = doorData.heading or 0.0,
        maxDistance = doorData.maxDistance or 2.5,
        owner_charid = doorData.owner_charid,
        owner_name = doorData.owner_name,
        price = doorData.price or 0,
        access_list = doorData.access_list,
        group_id = doorData.group_id
    }
    BroadcastDoorUpdate(doorId, doors[doorId])
    SendActionFeedback(src, true, 'Door created', doorId, 'create')
    debugPrint(3, '✅ Created door:', doorId, '| Name:', doorData.name, '| By:', GetPlayerName(src))
    NostrLog(
        string.format('✅ Door created: %s | By: %s', doorData.name, GetPlayerName(src)),
        {{'event', 'door_created'}, {'doorId', doorId}, {'doorName', doorData.name}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:updateDoor', function(doorId, updates)
    local src = source
    local door = doors[doorId]
    if not door then
        SendActionFeedback(src, false, 'Door not found', doorId, 'update')
        return
    end
    if not (IsPlayerAdmin(src) or HasAccess(door, src)) then
        SendActionFeedback(src, false, 'No permission', doorId, 'update')
        return
    end
    if updates.name then door.name = updates.name end
    if updates.type then door.type = updates.type end
    if updates.price ~= nil then door.price = updates.price end
    if updates.auth then door.auth = updates.auth end
    if updates.group_id then door.group_id = updates.group_id end
    if updates.coords then
        if not updates.coords.x or not updates.coords.y or not updates.coords.z or
           type(updates.coords.x) ~= 'number' or type(updates.coords.y) ~= 'number' or type(updates.coords.z) ~= 'number' then
            SendActionFeedback(src, false, 'Invalid coordinates provided', doorId, 'update')
            return
        end
        door.coords = updates.coords
    end
    CreateThread(function()
        SaveDoor(doorId, door)
    end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Door updated', doorId, 'update')
    debugPrint(3, '🔄 Updated door:', doorId, '| Name:', door.name, '| By:', GetPlayerName(src))
    NostrLog(
        string.format('🔄 Door updated: %s | By: %s', door.name, GetPlayerName(src)),
        {{'event', 'door_updated'}, {'doorId', doorId}, {'doorName', door.name}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:deleteDoor', function(doorId)
    local src = source
    if not IsPlayerAdmin(src) then
        SendActionFeedback(src, false, 'No permission', doorId, 'delete')
        return
    end
    local door = doors[doorId]
    if not door then
        SendActionFeedback(src, false, 'Door not found', doorId, 'delete')
        return
    end
    if not DeleteDoor(doorId) then
        SendActionFeedback(src, false, 'Save error', doorId, 'delete')
        return
    end
    doors[doorId] = nil
    doorStateBags[doorId] = nil
    lastBroadcast[doorId] = nil
    BroadcastDoorDelete(doorId)
    SendActionFeedback(src, true, 'Door deleted', doorId, 'delete')
    debugPrint(3, '🗑️ Deleted door:', doorId, '| By:', GetPlayerName(src))
    NostrLog(
        string.format('🗑️ Door deleted: %s | By: %s', doorId, GetPlayerName(src)),
        {{'event', 'door_deleted'}, {'doorId', doorId}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:setPrice', function(doorId, price)
    local src = source
    local door = doors[doorId]
    if not door then
        SendActionFeedback(src, false, 'Door not found', doorId, 'price')
        return
    end
    if not Ox then
        SendActionFeedback(src, false, 'Framework error', doorId, 'price')
        return
    end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then
        SendActionFeedback(src, false, 'Player data error', doorId, 'price')
        return
    end
    if not (IsPlayerAdmin(src) or (door.owner_charid and tostring(door.owner_charid) == tostring(player.charId))) then
        SendActionFeedback(src, false, 'No permission', doorId, 'price')
        return
    end
    door.price = math.max(0, tonumber(price) or 0)
    doors[doorId] = door
    CreateThread(function()
        SaveDoor(doorId, door)
    end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Price updated', doorId, 'price')
    debugPrint(3, '💰 Price updated for door:', doorId, '| New price:', door.price, '| By:', GetPlayerName(src))
    NostrLog(
        string.format('💰 Price set: %s → $%d | By: %s', door.name, door.price, GetPlayerName(src)),
        {{'event', 'door_price_set'}, {'doorId', doorId}, {'price', tostring(door.price)}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:rename', function(doorId, name)
    local src = source
    local door = doors[doorId]
    if not door or not name or name == "" then
        SendActionFeedback(src, false, 'Invalid name provided', doorId, 'rename')
        return
    end
    if not Ox then
        SendActionFeedback(src, false, 'Framework error', doorId, 'rename')
        return
    end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then
        SendActionFeedback(src, false, 'Player data error', doorId, 'rename')
        return
    end
    if not (IsPlayerAdmin(src) or (door.owner_charid and tostring(door.owner_charid) == tostring(player.charId))) then
        SendActionFeedback(src, false, 'No permission', doorId, 'rename')
        return
    end
    door.name = name
    doors[doorId] = door
    CreateThread(function()
        SaveDoor(doorId, door)
    end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Door renamed', doorId, 'rename')
    debugPrint(3, '✏️ Renamed door:', doorId, '| New name:', name, '| By:', GetPlayerName(src))
    NostrLog(
        string.format('✏️ Door renamed: %s → %s | By: %s', doorId, name, GetPlayerName(src)),
        {{'event', 'door_renamed'}, {'doorId', doorId}, {'newName', name}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:manageAccess', function(doorId, targetIdentifier, grantAccess)
    local src = source
    local door = doors[doorId]
    if not door then
        SendActionFeedback(src, false, 'Door not found', doorId, 'access')
        return
    end
    if not Ox then
        SendActionFeedback(src, false, 'Framework error', doorId, 'access')
        return
    end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then
        SendActionFeedback(src, false, 'Player data error', doorId, 'access')
        return
    end
    if not (IsPlayerAdmin(src) or (door.owner_charid and tostring(door.owner_charid) == tostring(player.charId))) then
        SendActionFeedback(src, false, 'No permission', doorId, 'access')
        return
    end
    local accessList = door.access_list or {}
    if grantAccess then
        local targetPlayer = Ox.GetPlayer(targetIdentifier)
        if targetPlayer and targetPlayer.charId then
            local charId = tostring(targetPlayer.charId)
            local found = false
            for _, id in ipairs(accessList) do
                if tostring(id) == charId then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(accessList, charId)
                debugPrint(3, '✅ Access granted to CharID:', charId, 'for door:', doorId)
            end
        else
            SendActionFeedback(src, false, 'Target player not found', doorId, 'access')
            return
        end
    else
        for i = #accessList, 1, -1 do
            if tostring(accessList[i]) == tostring(targetIdentifier) then
                table.remove(accessList, i)
                debugPrint(3, '🔒 Access revoked from CharID:', targetIdentifier, 'for door:', doorId)
                break
            end
        end
    end
    door.access_list = accessList
    doors[doorId] = door
    CreateThread(function()
        SaveDoor(doorId, door)
    end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Access updated', doorId, 'access')
    NostrLog(
        string.format('🔑 Access %s on %s | Target: %s | By: %s', grantAccess and 'granted' or 'revoked', door.name, tostring(targetIdentifier), GetPlayerName(src)),
        {{'event', 'door_access_changed'}, {'doorId', doorId}, {'target', tostring(targetIdentifier)}, {'granted', tostring(grantAccess)}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:ringBell', function(doorId)
    local src = source
    local door = doors[doorId]
    if not door or not door.owner_charid or not Ox then return end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then return end
    local playerName = (player.get('firstName') or 'Unknown') .. ' ' .. (player.get('lastName') or 'Player')
    for _, playerId in ipairs(GetPlayers()) do
        local targetPlayer = Ox.GetPlayer(tonumber(playerId))
        if targetPlayer and tostring(targetPlayer.charId) == tostring(door.owner_charid) then
            TriggerClientEvent('ox_lib:notify', targetPlayer.source, {
                title = '🔔 Someone is ringing',
                description = playerName .. ' is at ' .. door.name,
                type = 'inform',
                duration = 5000
            })
            debugPrint(4, '🔔 Bell rang at door:', doorId, 'by', playerName)
            NostrLog(
                string.format('🔔 Bell rung at: %s | By: %s', door.name, playerName),
                {{'event', 'door_bell'}, {'doorId', doorId}, {'doorName', door.name}, {'player', playerName}}
            )
            break
        end
    end
end)

RegisterNetEvent('rde_doors:knock', function(doorId)
    local src = source
    local door = doors[doorId]
    if not door or not door.owner_charid or not Ox then return end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then return end
    local playerName = (player.get('firstName') or 'Unknown') .. ' ' .. (player.get('lastName') or 'Player')
    for _, playerId in ipairs(GetPlayers()) do
        local targetPlayer = Ox.GetPlayer(tonumber(playerId))
        if targetPlayer and tostring(targetPlayer.charId) == tostring(door.owner_charid) then
            TriggerClientEvent('ox_lib:notify', targetPlayer.source, {
                title = '👊 Someone is knocking',
                description = playerName .. ' is knocking at ' .. door.name,
                type = 'inform',
                duration = 5000
            })
            debugPrint(4, '👊 Knock at door:', doorId, 'by', playerName)
            NostrLog(
                string.format('👊 Knock at: %s | By: %s', door.name, playerName),
                {{'event', 'door_knock'}, {'doorId', doorId}, {'doorName', door.name}, {'player', playerName}}
            )
            break
        end
    end
end)

-- ============================================
-- 📊 DOOR GROUP EVENTS
-- ============================================
RegisterNetEvent('rde_doors:createGroup', function(name)
    local src = source
    if not IsPlayerAdmin(src) then
        SendActionFeedback(src, false, 'No permission', nil, 'group_create')
        return
    end
    if not name or name == "" then
        SendActionFeedback(src, false, 'Invalid name', nil, 'group_create')
        return
    end
    local groupId = GenerateGroupId()
    local success = CreateDoorGroup(groupId, {
        name = name,
        doors = {}
    })
    if not success then
        SendActionFeedback(src, false, 'Failed to create group', nil, 'group_create')
        return
    end
    doorGroups[groupId] = {
        id = groupId,
        name = name,
        doors = {}
    }
    BroadcastDoorGroupUpdate(groupId, doorGroups[groupId])
    SendActionFeedback(src, true, 'Group created', nil, 'group_create')
    debugPrint(3, '✅ Created group:', groupId, '| Name:', name, '| By:', GetPlayerName(src))
    NostrLog(
        string.format('✅ Group created: %s | By: %s', name, GetPlayerName(src)),
        {{'event', 'door_group_created'}, {'groupId', groupId}, {'groupName', name}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:renameGroup', function(groupId, name)
    local src = source
    if not IsPlayerAdmin(src) then
        SendActionFeedback(src, false, 'No permission', nil, 'group_rename')
        return
    end
    local group = doorGroups[groupId]
    if not group then
        SendActionFeedback(src, false, 'Group not found', nil, 'group_rename')
        return
    end
    if not name or name == "" then
        SendActionFeedback(src, false, 'Invalid name', nil, 'group_rename')
        return
    end
    group.name = name
    doorGroups[groupId] = group
    CreateThread(function()
        SaveDoorGroup(groupId, group)
    end)
    BroadcastDoorGroupUpdate(groupId, group)
    SendActionFeedback(src, true, 'Group renamed', nil, 'group_rename')
    debugPrint(3, '✏️ Renamed group:', groupId, '| New name:', name, '| By:', GetPlayerName(src))
    NostrLog(
        string.format('✏️ Group renamed: %s → %s | By: %s', groupId, name, GetPlayerName(src)),
        {{'event', 'door_group_renamed'}, {'groupId', groupId}, {'newName', name}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:deleteGroup', function(groupId)
    local src = source
    if not IsPlayerAdmin(src) then
        SendActionFeedback(src, false, 'No permission', nil, 'group_delete')
        return
    end
    local group = doorGroups[groupId]
    if not group then
        SendActionFeedback(src, false, 'Group not found', nil, 'group_delete')
        return
    end
    if not DeleteDoorGroup(groupId) then
        SendActionFeedback(src, false, 'Failed to delete group', nil, 'group_delete')
        return
    end
    doorGroups[groupId] = nil
    BroadcastDoorGroupDelete(groupId)
    SendActionFeedback(src, true, 'Group deleted', nil, 'group_delete')
    debugPrint(3, '🗑️ Deleted group:', groupId, '| By:', GetPlayerName(src))
    NostrLog(
        string.format('🗑️ Group deleted: %s | By: %s', groupId, GetPlayerName(src)),
        {{'event', 'door_group_deleted'}, {'groupId', groupId}, {'player', GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:addToGroup', function(doorId, groupId)
    local src = source
    if not IsPlayerAdmin(src) then
        SendActionFeedback(src, false, 'No permission', nil, 'add_to_group')
        return
    end
    local door = doors[doorId]
    if not door then
        SendActionFeedback(src, false, 'Door not found', nil, 'add_to_group')
        return
    end
    local group = doorGroups[groupId]
    if not group then
        SendActionFeedback(src, false, 'Group not found', nil, 'add_to_group')
        return
    end
    local found = false
    for _, id in ipairs(group.doors) do
        if id == doorId then
            found = true
            break
        end
    end
    if not found then
        table.insert(group.doors, doorId)
        door.group_id = groupId
        doors[doorId] = door
        CreateThread(function()
            SaveDoorGroup(groupId, group)
            SaveDoor(doorId, door)
        end)
        BroadcastDoorGroupUpdate(groupId, group)
        BroadcastDoorUpdate(doorId, door)
        SendActionFeedback(src, true, 'Door added to group', nil, 'add_to_group')
        debugPrint(3, '✅ Added door:', doorId, 'to group:', groupId, '| By:', GetPlayerName(src))
        NostrLog(
            string.format('➕ Door added to group: %s → %s | By: %s', doorId, groupId, GetPlayerName(src)),
            {{'event', 'door_added_to_group'}, {'doorId', doorId}, {'groupId', groupId}, {'player', GetPlayerName(src)}}
        )
    else
        SendActionFeedback(src, false, 'Door already in group', nil, 'add_to_group')
    end
end)

RegisterNetEvent('rde_doors:removeFromGroup', function(doorId, groupId)
    local src = source
    if not IsPlayerAdmin(src) then
        SendActionFeedback(src, false, 'No permission', nil, 'remove_from_group')
        return
    end
    local door = doors[doorId]
    if not door then
        SendActionFeedback(src, false, 'Door not found', nil, 'remove_from_group')
        return
    end
    local group = doorGroups[groupId]
    if not group then
        SendActionFeedback(src, false, 'Group not found', nil, 'remove_from_group')
        return
    end
    for i = #group.doors, 1, -1 do
        if group.doors[i] == doorId then
            table.remove(group.doors, i)
            door.group_id = nil
            doors[doorId] = door
            CreateThread(function()
                SaveDoorGroup(groupId, group)
                SaveDoor(doorId, door)
            end)
            BroadcastDoorGroupUpdate(groupId, group)
            BroadcastDoorUpdate(doorId, door)
            SendActionFeedback(src, true, 'Door removed from group', nil, 'remove_from_group')
            debugPrint(3, '✅ Removed door:', doorId, 'from group:', groupId, '| By:', GetPlayerName(src))
            NostrLog(
                string.format('➖ Door removed from group: %s ← %s | By: %s', doorId, groupId, GetPlayerName(src)),
                {{'event', 'door_removed_from_group'}, {'doorId', doorId}, {'groupId', groupId}, {'player', GetPlayerName(src)}}
            )
            return
        end
    end
    SendActionFeedback(src, false, 'Door not in group', nil, 'remove_from_group')
end)

-- ============================================
-- 📊 ADMIN COMMANDS
-- ============================================
lib.addCommand('doorslist', {
    help = 'List all doors',
    restricted = false
}, function(source)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'You do not have permission',
            type = 'error'
        })
        return
    end
    local count = 0
    local validCount = 0
    local invalidCount = 0
    print('^3========== RDE DOORS ==========^7')
    for doorId, door in pairs(doors) do
        count = count + 1
        if door.coords and type(door.coords.x) == 'number' and type(door.coords.y) == 'number' and type(door.coords.z) == 'number' then
            validCount = validCount + 1
            print(string.format('^5[%d]^7 %s | %s | %s | %.2f, %.2f, %.2f',
                validCount, doorId, door.name, door.locked and 'Locked' or 'Unlocked',
                door.coords.x, door.coords.y, door.coords.z))
        else
            invalidCount = invalidCount + 1
            print(string.format('^1[%d]^7 %s | %s | ^1INVALID COORDS^7',
                count, doorId, door.name))
        end
    end
    print('^3================================^7')
    print(string.format('^2Total:^7 %d | ^2Valid:^7 %d | ^1Invalid:^7 %d', count, validCount, invalidCount))
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Doors',
        description = string.format('Total: %d (Valid: %d, Invalid: %d)', count, validCount, invalidCount),
        type = 'info'
    })
end)

lib.addCommand('resyncdoors', {
    help = 'Resync all doors',
    restricted = false
}, function(source)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'You do not have permission',
            type = 'error'
        })
        return
    end
    debugPrint(3, '🔄 Resyncing all doors...')
    if not LoadDoors() or not LoadDoorGroups() then
        SendActionFeedback(source, false, 'Failed to reload doors', nil, 'resync')
        return
    end
    for _, playerId in ipairs(GetPlayers()) do
        CreateThread(function()
            SyncAllDoors(tonumber(playerId))
        end)
    end
    SendActionFeedback(source, true, 'Doors resynced successfully', nil, 'resync')
    debugPrint(3, '✅ Doors resynced by:', GetPlayerName(source))
end)

lib.addCommand('cleandoors', {
    help = 'Clean up invalid doors in database',
    restricted = false
}, function(source)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'You do not have permission',
            type = 'error'
        })
        return
    end
    if not MySQL then
        SendActionFeedback(source, false, 'MySQL not available', nil, 'clean')
        return
    end
    debugPrint(3, '🧹 Starting database cleanup...')
    local success, result = pcall(function()
        return MySQL.query.await('SELECT id, coords FROM rde_owned_doors')
    end)
    if not success then
        SendActionFeedback(source, false, 'Failed to query doors', nil, 'clean')
        return
    end
    local deletedCount = 0
    local keptCount = 0
    for _, dbDoor in ipairs(result) do
        local coords = DeserializeCoords(dbDoor.coords)
        if not coords or type(coords.x) ~= 'number' or type(coords.y) ~= 'number' or type(coords.z) ~= 'number' then
            local deleteSuccess = pcall(function()
                return MySQL.query.await('DELETE FROM rde_owned_doors WHERE id = ?', {dbDoor.id})
            end)
            if deleteSuccess then
                deletedCount = deletedCount + 1
                debugPrint(2, '🗑️ Deleted invalid door:', dbDoor.id)
            end
        else
            keptCount = keptCount + 1
        end
    end
    LoadDoors()
    LoadDoorGroups()
    for _, playerId in ipairs(GetPlayers()) do
        CreateThread(function()
            SyncAllDoors(tonumber(playerId))
        end)
    end
    SendActionFeedback(source, true, string.format('Cleanup complete: %d deleted, %d kept', deletedCount, keptCount), nil, 'clean')
    debugPrint(3, '✅ Database cleanup complete:', deletedCount, 'invalid doors deleted')
end)

lib.addCommand('doorinfo', {
    help = 'Get info about nearest door',
    restricted = false
}, function(source)
    if not IsPlayerAdmin(source) then return end
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local nearestDoor = nil
    local nearestDist = 999999.0
    for doorId, door in pairs(doors) do
        if door.coords then
            local dx = playerCoords.x - door.coords.x
            local dy = playerCoords.y - door.coords.y
            local dz = playerCoords.z - door.coords.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dist < nearestDist and dist < 10.0 then
                nearestDist = dist
                nearestDoor = door
            end
        end
    end
    if nearestDoor then
        print('^3========== DOOR INFO ==========^7')
        print('^5ID:^7', nearestDoor.id)
        print('^5Name:^7', nearestDoor.name)
        print('^5Type:^7', nearestDoor.type)
        print('^5Locked:^7', nearestDoor.locked and 'Yes' or 'No')
        print('^5Owner CharID:^7', nearestDoor.owner_charid or 'None')
        print('^5Owner Name:^7', nearestDoor.owner_name or 'None')
        print('^5Price:^7', tostring(nearestDoor.price or 'N/A'))
        print('^5Distance:^7', string.format('%.2f meters', nearestDist))
        print('^5Coords:^7', string.format('%.2f, %.2f, %.2f', nearestDoor.coords.x, nearestDoor.coords.y, nearestDoor.coords.z))
        print('^5Group:^7', nearestDoor.group_id or 'None')
        print('^3================================^7')
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Nearest Door',
            description = string.format('%s (%.1fm away)', nearestDoor.name, nearestDist),
            type = 'info'
        })
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'No Door Found',
            description = 'No door within 10 meters',
            type = 'error'
        })
    end
end)

-- ============================================
-- 🚀 INITIALIZATION
-- ============================================
CreateThread(function()
    debugPrint(3, '🚀 Starting RDE Doors initialization...')
    while GetResourceState('oxmysql') ~= 'started' do
        debugPrint(3, '⏳ Waiting for oxmysql...')
        Wait(500)
    end
    while GetResourceState('ox_core') ~= 'started' do
        Wait(100)
    end
    local success, result = pcall(require, '@ox_core/lib/init')
    if success and result then
        Ox = result
        debugPrint(3, '✅ ox_core loaded')
    else
        debugPrint(1, '❌ ox_core load failed')
        return
    end
    success, result = pcall(require, 'shared.config')
    if success and result then
        Config = result
        L = Config.Lang[Config.DefaultLanguage or 'en']
        debugPrint(3, '✅ Config loaded')
    else
        debugPrint(2, '⚠️ Using fallback config')
        Config = { Debug = true, Defaults = { type = 'single', locked = true, autolock = 0, heading = 0, maxDistance = 2.5, price = 0 }, AdminSystem = { acePermission = 'rde.doors.admin', oxGroups = { admin = true, superadmin = true } }, Performance = { useStateBags = true } }
        L = { doorNotFound = 'Door not found', accessDenied = 'Access denied', noPermission = 'No permission', locked = 'Locked', unlocked = 'Unlocked' }
    end
    debugPrint(3, '🔧 Initializing database...')
    if InitializeDatabase() then
        Wait(500)
        if LoadDoors() and LoadDoorGroups() then
            local count = 0
            local validCount = 0
            for _, door in pairs(doors) do
                count = count + 1
                if door.coords and type(door.coords.x) == 'number' then
                    validCount = validCount + 1
                end
            end
            debugPrint(3, '✅ Server initialized with', count, 'doors (', validCount, 'valid) and', #doorGroups, 'groups')
            print('^2[RDE Doors] ✅ Ready with ' .. count .. ' doors (' .. validCount .. ' valid) and ' .. #doorGroups .. ' groups^7')
        else
            debugPrint(1, '❌ Failed to load doors or groups')
        end
    else
        debugPrint(1, '❌ Failed to initialize database')
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= resourceName then return end
    debugPrint(3, '🛑 Shutting down RDE Doors')
    doors = {}
    doorGroups = {}
    doorStateBags = {}
    lastBroadcast = {}
    initialized = false
end)

-- ox:playerLoaded server signature: (playerId, userId, charId)
-- See: https://coxdocs.dev/ox_core/Events/server
AddEventHandler('ox:playerLoaded', function(playerId, userId, charId)
    if not playerId then return end
    debugPrint(3, '👤 Player loaded:', GetPlayerName(playerId), '| UserID:', userId, '| CharID:', charId)
    NostrLog(
        string.format('👤 Player loaded: %s | UserID: %s | CharID: %s', GetPlayerName(playerId), tostring(userId), tostring(charId)),
        {{'event', 'player_loaded'}, {'charId', tostring(charId)}, {'userId', tostring(userId)}}
    )
    SetTimeout(1000, function()
        if GetPlayerPing(playerId) > 0 then
            SyncAllDoors(playerId)
        end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    debugPrint(4, '👋 Player dropped:', GetPlayerName(src), '| Reason:', reason)
    NostrLog(
        string.format('👋 Player dropped: %s | Reason: %s', GetPlayerName(src), tostring(reason)),
        {{'event', 'player_dropped'}, {'reason', tostring(reason)}}
    )
end)

debugPrint(3, '✅ Server script loaded successfully')

print('^2[RDE | Doors | Server] 📜 Server-side script ready^7')
