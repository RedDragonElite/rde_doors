-- ============================================
-- 🚪 RDE DOORS - SERVER
-- ============================================
-- Version: 3.0.0 (Double Door Support + Auto-Migration)
-- Author: RDE | SerpentsByte
-- Features: Double Doors, Door Groups, Item Support, Admin System,
--           Auto DB Migration, Backward Compatibility, Nostr Logging,
--           Statebag-Sync, ox_inventory, Triple Admin Verification
-- ============================================

-- ============================================
-- 🔧 GLOBAL VARIABLES
-- ============================================
local Ox, Config, L
local doors      = {}
local doorGroups = {}
local initialized    = false
local resourceName   = GetCurrentResourceName()
local doorStateBags  = {}
local lastBroadcast  = {}
local broadcastCooldown = 100

local json = json or require('json')

-- ============================================
-- 📝 UTILITY FUNCTIONS
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
    if not data then return false, 'No data provided' end
    if not data.name or data.name == '' then return false, 'Name is required' end
    if not data.coords or type(data.coords) ~= 'table' then return false, 'Valid coordinates required' end
    if not data.coords.x or not data.coords.y or not data.coords.z then return false, 'Invalid coordinate format' end
    if type(data.coords.x) ~= 'number' or type(data.coords.y) ~= 'number' or type(data.coords.z) ~= 'number' then
        return false, 'Coordinates must be numbers'
    end
    -- For double doors: require door_a/door_b instead of model
    if data.door_a and data.door_b then
        -- double door — coords required, model on each sub-door
        if not data.door_a.model or not data.door_b.model then return false, 'Double door requires model on each sub-door' end
        if not data.door_a.coords or not data.door_b.coords then return false, 'Double door requires coords on each sub-door' end
    else
        if not data.model then return false, 'Model is required' end
    end
    return true, 'Valid'
end

local function SerializeCoords(coords)
    if type(coords) == 'table' then
        return json.encode({ x = coords.x or 0.0, y = coords.y or 0.0, z = coords.z or 0.0 })
    end
    return coords
end

local function DeserializeCoords(coords)
    if type(coords) == 'string' then
        local ok, result = pcall(json.decode, coords)
        if ok and result then
            return { x = result.x or 0.0, y = result.y or 0.0, z = result.z or 0.0 }
        end
    elseif type(coords) == 'table' then
        return { x = coords.x or 0.0, y = coords.y or 0.0, z = coords.z or 0.0 }
    end
    return nil
end

local function DeserializeDoubleDoor(raw)
    if not raw then return nil end
    local ok, result = pcall(json.decode, raw)
    if not ok or not result then return nil end
    -- Validate both sub-doors
    if not result.door_a or not result.door_b then return nil end
    local a, b = result.door_a, result.door_b
    if not a.coords or not b.coords then return nil end
    a.coords = DeserializeCoords(a.coords) or a.coords
    b.coords = DeserializeCoords(b.coords) or b.coords
    return result
end

local function DoesDoorExistAtPosition(coords, excludeId)
    if not coords then return false end
    for doorId, door in pairs(doors) do
        if doorId ~= excludeId and door.coords then
            local dx = coords.x - door.coords.x
            local dy = coords.y - door.coords.y
            local dz = coords.z - door.coords.z
            if math.sqrt(dx*dx + dy*dy + dz*dz) < 1.0 then
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
    if IsPlayerAceAllowed(source, 'rde.doors.admin') then
        debugPrint(3, 'Admin verified (ACE):', GetPlayerName(source))
        return true
    end
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
    if not player or not player.charId then return false end
    local charId = tostring(player.charId)
    if door.owner_charid and tostring(door.owner_charid) == charId then return true end
    if door.access_list and type(door.access_list) == 'table' then
        for _, accessCharId in ipairs(door.access_list) do
            if tostring(accessCharId) == charId then return true end
        end
    end
    if door.auth and type(door.auth) == 'table' then
        local groups = player.getGroups and player.getGroups() or {}
        for groupName in pairs(groups) do
            for _, authGroup in ipairs(door.auth) do
                if groupName == authGroup then return true end
            end
        end
    end
    if door.items and type(door.items) == 'table' and exports.ox_inventory then
        for _, item in ipairs(door.items) do
            local count = exports.ox_inventory:GetItemCount(source, item)
            if count and count > 0 then return true end
        end
    end
    return false
end

-- ============================================
-- 💾 DATABASE — AUTO-MIGRATION
-- ============================================

-- Checks if a column exists in a table, returns bool
local function ColumnExists(tableName, columnName)
    local result = MySQL.query.await(
        'SELECT COUNT(*) as cnt FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
        { tableName, columnName }
    )
    return result and result[1] and result[1].cnt > 0
end

local function InitializeDatabase()
    if not MySQL then
        debugPrint(1, '❌ MySQL not available')
        return false
    end

    local ok = pcall(function()
        -- ── Main doors table (CREATE IF NOT EXISTS = backward compatible) ──
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS rde_owned_doors (
                id           VARCHAR(50)  PRIMARY KEY,
                type         VARCHAR(20)  DEFAULT 'single',
                name         VARCHAR(100) NOT NULL,
                coords       LONGTEXT     NOT NULL,
                model        VARCHAR(100) NOT NULL DEFAULT '',
                model_hash   VARCHAR(50),
                locked       TINYINT(1)   DEFAULT 1,
                auth         LONGTEXT     DEFAULT '[]',
                autolock     INT          DEFAULT 0,
                items        LONGTEXT     DEFAULT '[]',
                heading      FLOAT        DEFAULT 0.0,
                maxDistance  FLOAT        DEFAULT 2.5,
                owner_charid VARCHAR(50),
                owner_name   VARCHAR(100),
                price        INT          DEFAULT 0,
                access_list  LONGTEXT     DEFAULT '[]',
                group_id     VARCHAR(50),
                created_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
                updated_at   TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]])

        -- ── Groups table ──
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS rde_door_groups (
                id         VARCHAR(50)  PRIMARY KEY,
                name       VARCHAR(100) NOT NULL,
                doors      LONGTEXT     DEFAULT '[]',
                created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ]])
    end)

    if not ok then
        debugPrint(1, '❌ Base table creation failed')
        return false
    end

    -- ── Auto-migration: add double-door columns if they don't exist yet ──
    -- These were not in the original schema, so older installs need them added.
    local migrations = {
        -- { column, ALTER statement }
        {
            col  = 'double_door_data',
            sql  = 'ALTER TABLE rde_owned_doors ADD COLUMN double_door_data LONGTEXT DEFAULT NULL'
        },
    }

    for _, m in ipairs(migrations) do
        if not ColumnExists('rde_owned_doors', m.col) then
            local mOk, mErr = pcall(MySQL.query.await, m.sql)
            if mOk then
                debugPrint(3, '✅ Migration applied: added column', m.col)
            else
                debugPrint(1, '❌ Migration failed for column', m.col, ':', tostring(mErr))
                return false
            end
        else
            debugPrint(4, '✔ Column already exists:', m.col)
        end
    end

    debugPrint(3, '✅ Database ready (schema up to date)')
    return true
end

-- ============================================
-- 💾 LOAD / SAVE
-- ============================================
local function LoadDoors()
    if not MySQL then debugPrint(1, '❌ MySQL not available'); return false end
    local ok, result = pcall(function()
        return MySQL.query.await('SELECT * FROM rde_owned_doors')
    end)
    if not ok then debugPrint(1, '❌ Failed to load doors'); return false end

    doors = {}
    local count, invalid = 0, 0

    if result and type(result) == 'table' then
        for _, row in ipairs(result) do
            if row and row.id then
                local coords = DeserializeCoords(row.coords)
                if coords then
                    local door = {
                        id           = row.id,
                        type         = row.type or 'single',
                        name         = row.name,
                        coords       = coords,
                        model        = row.model or '',
                        model_hash   = row.model_hash,
                        locked       = (row.locked == 1 or row.locked == true),
                        auth         = type(row.auth) == 'string' and json.decode(row.auth) or {},
                        autolock     = row.autolock or 0,
                        items        = type(row.items) == 'string' and json.decode(row.items) or {},
                        heading      = row.heading or 0.0,
                        maxDistance  = row.maxDistance or 2.5,
                        owner_charid = row.owner_charid,
                        owner_name   = row.owner_name,
                        price        = row.price or 0,
                        access_list  = type(row.access_list) == 'string' and json.decode(row.access_list) or {},
                        group_id     = row.group_id,
                    }

                    -- Double door: deserialize if present
                    if row.double_door_data and row.double_door_data ~= '' then
                        local dd = DeserializeDoubleDoor(row.double_door_data)
                        if dd then
                            door.door_a = dd.door_a
                            door.door_b = dd.door_b
                            -- Recompute midpoint coords (keep the stored value as fallback)
                            local ax, bx = door.door_a.coords.x, door.door_b.coords.x
                            local ay, by = door.door_a.coords.y, door.door_b.coords.y
                            local az, bz = door.door_a.coords.z, door.door_b.coords.z
                            door.coords = {
                                x = (ax + bx) / 2.0,
                                y = (ay + by) / 2.0,
                                z = (az + bz) / 2.0,
                            }
                        end
                    end

                    doors[row.id] = door
                    doorStateBags[row.id] = true
                    count = count + 1
                else
                    debugPrint(2, '⚠️ Invalid coordinates for door:', row.id)
                    invalid = invalid + 1
                end
            end
        end
    end

    initialized = true
    debugPrint(3, '✅ Loaded', count, 'doors (', invalid, 'invalid skipped)')
    return true
end

local function LoadDoorGroups()
    if not MySQL then debugPrint(1, '❌ MySQL not available'); return false end
    local ok, result = pcall(function()
        return MySQL.query.await('SELECT * FROM rde_door_groups')
    end)
    if not ok then debugPrint(1, '❌ Failed to load door groups'); return false end

    doorGroups = {}
    local count = 0
    if result and type(result) == 'table' then
        for _, row in ipairs(result) do
            if row and row.id then
                doorGroups[row.id] = {
                    id    = row.id,
                    name  = row.name,
                    doors = type(row.doors) == 'string' and json.decode(row.doors) or {},
                }
                count = count + 1
            end
        end
    end
    debugPrint(3, '✅ Loaded', count, 'door groups')
    return true
end

local function BuildDoubleDoorJson(door)
    if not door.door_a or not door.door_b then return nil end
    return json.encode({
        door_a = {
            model  = door.door_a.model,
            coords = door.door_a.coords,
            heading= door.door_a.heading or 0.0,
        },
        door_b = {
            model  = door.door_b.model,
            coords = door.door_b.coords,
            heading= door.door_b.heading or 0.0,
        },
    })
end

local function SaveDoor(doorId, door)
    if not MySQL or not doorId or not door then return false end
    if not door.coords or type(door.coords.x) ~= 'number' then
        debugPrint(1, '❌ Invalid coords for door:', doorId)
        return false
    end
    local ddJson = BuildDoubleDoorJson(door)
    local ok = pcall(function()
        MySQL.update.await([[
            UPDATE rde_owned_doors
            SET type=?, name=?, coords=?, model=?, model_hash=?,
                locked=?, auth=?, autolock=?, items=?, heading=?,
                maxDistance=?, owner_charid=?, owner_name=?, price=?,
                access_list=?, group_id=?, double_door_data=?
            WHERE id=?
        ]], {
            door.type,
            door.name,
            SerializeCoords(door.coords),
            door.model or '',
            door.model_hash,
            door.locked and 1 or 0,
            json.encode(door.auth or {}),
            door.autolock,
            json.encode(door.items or {}),
            door.heading,
            door.maxDistance,
            door.owner_charid,
            door.owner_name,
            door.price,
            json.encode(door.access_list or {}),
            door.group_id,
            ddJson,
            doorId,
        })
    end)
    return ok
end

local function CreateDoor(doorId, door)
    if not MySQL or not doorId or not door then return false end
    if not door.coords or type(door.coords.x) ~= 'number' then
        debugPrint(1, '❌ Invalid coords for new door:', doorId)
        return false
    end
    local exists, existId = DoesDoorExistAtPosition(door.coords, doorId)
    if exists then
        debugPrint(2, '⚠️ Door already exists at position – existing ID:', existId)
        return false
    end
    local ddJson = BuildDoubleDoorJson(door)
    local ok = pcall(function()
        MySQL.insert.await([[
            INSERT INTO rde_owned_doors
            (id,type,name,coords,model,model_hash,locked,auth,autolock,items,
             heading,maxDistance,owner_charid,owner_name,price,access_list,group_id,double_door_data)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ]], {
            doorId,
            door.type or 'single',
            door.name,
            SerializeCoords(door.coords),
            door.model or '',
            door.model_hash or (door.model ~= '' and GetHashKey(door.model) or nil),
            door.locked and 1 or 0,
            json.encode(door.auth or {}),
            door.autolock or 0,
            json.encode(door.items or {}),
            door.heading or 0.0,
            door.maxDistance or 2.5,
            door.owner_charid,
            door.owner_name,
            door.price or 0,
            json.encode(door.access_list or {}),
            door.group_id,
            ddJson,
        })
    end)
    return ok
end

local function DeleteDoor(doorId)
    if not MySQL or not doorId then return false end
    local ok = pcall(function()
        MySQL.query.await('DELETE FROM rde_owned_doors WHERE id=?', { doorId })
    end)
    return ok
end

local function SaveDoorGroup(groupId, group)
    if not MySQL or not groupId or not group then return false end
    local ok = pcall(function()
        MySQL.update.await('UPDATE rde_door_groups SET name=?, doors=? WHERE id=?', {
            group.name, json.encode(group.doors or {}), groupId
        })
    end)
    return ok
end

local function CreateDoorGroup(groupId, group)
    if not MySQL or not groupId or not group then return false end
    local ok = pcall(function()
        MySQL.insert.await('INSERT INTO rde_door_groups (id,name,doors) VALUES (?,?,?)', {
            groupId, group.name, json.encode(group.doors or {})
        })
    end)
    return ok
end

local function DeleteDoorGroup(groupId)
    if not MySQL or not groupId then return false end
    local ok = pcall(function()
        MySQL.query.await('DELETE FROM rde_door_groups WHERE id=?', { groupId })
    end)
    return ok
end

-- ============================================
-- 📡 SYNCHRONIZATION
-- ============================================
local function BroadcastDoorUpdate(doorId, door)
    if not doorId or not door then return end
    if not door.coords or type(door.coords.x) ~= 'number' then
        debugPrint(1, '❌ Invalid coords in broadcast:', doorId)
        return
    end
    local t = GetGameTimer()
    if lastBroadcast[doorId] and (t - lastBroadcast[doorId] < broadcastCooldown) then return end
    lastBroadcast[doorId] = t
    TriggerClientEvent('rde_doors:doorUpdate', -1, doorId, door)
    debugPrint(4, '📢 Broadcast update:', doorId, '| Locked:', door.locked)
end

local function BroadcastDoorDelete(doorId)
    if not doorId then return end
    TriggerClientEvent('rde_doors:doorDeleted', -1, doorId)
    debugPrint(4, '📢 Broadcast delete:', doorId)
end

local function BroadcastDoorGroupUpdate(groupId, group)
    if not groupId or not group then return end
    TriggerClientEvent('rde_doors:doorGroupUpdate', -1, groupId, group)
end

local function BroadcastDoorGroupDelete(groupId)
    if not groupId then return end
    TriggerClientEvent('rde_doors:doorGroupDeleted', -1, groupId)
end

local function SyncAllDoors(source)
    if not source then return end
    local attempts = 0
    while not initialized and attempts < 20 do Wait(100); attempts = attempts + 1 end
    if not initialized then debugPrint(2, '⚠️ Sync requested but not initialized'); return end

    local doorArray = {}
    for _, door in pairs(doors) do
        if door.coords and type(door.coords.x) == 'number' then
            table.insert(doorArray, door)
        end
    end
    TriggerClientEvent('rde_doors:syncDoors', source, doorArray, doorGroups)
    debugPrint(3, '📤 Synced', #doorArray, 'doors to', GetPlayerName(source))
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
    if not door or door.price <= 0 or door.owner_charid then return false, 'Door not available' end
    if not Ox then return false, 'Framework error' end
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return false, 'Player data error' end
    if not exports.ox_inventory then return false, 'Inventory system not available' end
    local moneyCount = exports.ox_inventory:GetItemCount(source, 'money')
    if moneyCount < door.price then return false, 'Not enough money' end
    if not exports.ox_inventory:RemoveItem(source, 'money', door.price) then return false, 'Transaction failed' end
    door.owner_charid = tostring(player.charId)
    door.owner_name   = (player.get('firstName') or 'Unknown') .. ' ' .. (player.get('lastName') or 'Player')
    door.price = 0
    if not SaveDoor(doorId, door) then
        exports.ox_inventory:AddItem(source, 'money', door.price)
        return false, 'Failed to save door'
    end
    doors[doorId] = door
    BroadcastDoorUpdate(doorId, door)
    NostrLog(
        ('💳 Door purchased: %s | By: %s (CharID: %s)'):format(door.name, GetPlayerName(source), tostring(player.charId)),
        {{'event','door_purchased'},{'doorId',doorId},{'charId',tostring(player.charId)},{'player',GetPlayerName(source)}}
    )
    return true, 'Purchase successful'
end)

lib.callback.register('rde_doors:useItem', function(source, doorId, item)
    local door = doors[doorId]
    if not door or not door.items or not exports.ox_inventory then return false, 'Invalid door or item' end
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return false, 'Player data error' end
    local itemCount = exports.ox_inventory:GetItemCount(source, item)
    if itemCount <= 0 then return false, 'Missing required item' end
    if not exports.ox_inventory:RemoveItem(source, item, 1) then return false, 'Failed to use item' end
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
    CreateThread(function() SyncAllDoors(src) end)
end)

RegisterNetEvent('rde_doors:toggleLock', function(doorId)
    local src  = source
    local door = doors[doorId]
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'toggle'); return end
    if not HasAccess(door, src) then SendActionFeedback(src, false, 'Access denied', doorId, 'toggle'); return end
    door.locked = not door.locked
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    local statusText = door.locked and 'Locked' or 'Unlocked'
    SendActionFeedback(src, true, statusText, doorId, 'toggle')
    debugPrint(3, '🔒 Door', statusText, '| ID:', doorId, '| Player:', GetPlayerName(src))
    NostrLog(
        ('🔒 Door %s | %s | By: %s'):format(statusText, door.name, GetPlayerName(src)),
        {{'event','door_toggle'},{'doorId',doorId},{'status',statusText},{'player',GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:createDoor', function(doorData)
    local src = source
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', nil, 'create'); return end
    local valid, message = ValidateDoorData(doorData)
    if not valid then SendActionFeedback(src, false, message, nil, 'create'); return end

    local doorId = GenerateUniqueId()
    local exists, existId = DoesDoorExistAtPosition(doorData.coords)
    if exists then SendActionFeedback(src, false, 'Door already exists', existId, 'create'); return end

    -- Sanitize coords
    doorData.coords = {
        x = type(doorData.coords.x) == 'number' and doorData.coords.x or 0.0,
        y = type(doorData.coords.y) == 'number' and doorData.coords.y or 0.0,
        z = type(doorData.coords.z) == 'number' and doorData.coords.z or 0.0,
    }

    -- Sanitize double-door sub-coords if present
    if doorData.door_a and doorData.door_b then
        doorData.type = 'double'
        doorData.model = '' -- no single model for double doors
        doorData.door_a.coords = {
            x = tonumber(doorData.door_a.coords.x) or 0.0,
            y = tonumber(doorData.door_a.coords.y) or 0.0,
            z = tonumber(doorData.door_a.coords.z) or 0.0,
        }
        doorData.door_b.coords = {
            x = tonumber(doorData.door_b.coords.x) or 0.0,
            y = tonumber(doorData.door_b.coords.y) or 0.0,
            z = tonumber(doorData.door_b.coords.z) or 0.0,
        }
    else
        doorData.model_hash = doorData.model_hash or GetHashKey(doorData.model)
    end

    doorData.locked      = doorData.locked == nil and true or doorData.locked
    doorData.auth        = doorData.auth or {}
    doorData.items       = doorData.items or {}
    doorData.access_list = doorData.access_list or {}

    if not CreateDoor(doorId, doorData) then
        SendActionFeedback(src, false, 'Door creation failed', doorId, 'create')
        return
    end

    doors[doorId] = {
        id           = doorId,
        type         = doorData.type or 'single',
        name         = doorData.name,
        coords       = doorData.coords,
        model        = doorData.model or '',
        model_hash   = doorData.model_hash,
        locked       = doorData.locked,
        auth         = doorData.auth,
        autolock     = doorData.autolock or 0,
        items        = doorData.items,
        heading      = doorData.heading or 0.0,
        maxDistance  = doorData.maxDistance or 2.5,
        owner_charid = doorData.owner_charid,
        owner_name   = doorData.owner_name,
        price        = doorData.price or 0,
        access_list  = doorData.access_list,
        group_id     = doorData.group_id,
        door_a       = doorData.door_a,
        door_b       = doorData.door_b,
    }
    BroadcastDoorUpdate(doorId, doors[doorId])
    SendActionFeedback(src, true, 'Door created', doorId, 'create')
    debugPrint(3, '✅ Created door:', doorId, '| Name:', doorData.name, '| Type:', doorData.type or 'single', '| By:', GetPlayerName(src))
    NostrLog(
        ('✅ Door created: %s (%s) | By: %s'):format(doorData.name, doorData.type or 'single', GetPlayerName(src)),
        {{'event','door_created'},{'doorId',doorId},{'doorName',doorData.name},{'player',GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:updateDoor', function(doorId, updates)
    local src  = source
    local door = doors[doorId]
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'update'); return end
    if not (IsPlayerAdmin(src) or HasAccess(door, src)) then SendActionFeedback(src, false, 'No permission', doorId, 'update'); return end

    if updates.name   then door.name   = updates.name   end
    if updates.type   then door.type   = updates.type   end
    if updates.price ~= nil then door.price = updates.price end
    if updates.auth   then door.auth   = updates.auth   end
    if updates.group_id then door.group_id = updates.group_id end
    if updates.coords then
        if type(updates.coords.x) ~= 'number' then
            SendActionFeedback(src, false, 'Invalid coordinates', doorId, 'update'); return
        end
        door.coords = updates.coords
    end

    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Door updated', doorId, 'update')
    debugPrint(3, '🔄 Updated door:', doorId, '| By:', GetPlayerName(src))
    NostrLog(
        ('🔄 Door updated: %s | By: %s'):format(door.name, GetPlayerName(src)),
        {{'event','door_updated'},{'doorId',doorId},{'doorName',door.name},{'player',GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:deleteDoor', function(doorId)
    local src  = source
    local door = doors[doorId]
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', doorId, 'delete'); return end
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'delete'); return end
    if not DeleteDoor(doorId) then SendActionFeedback(src, false, 'Save error', doorId, 'delete'); return end
    doors[doorId]       = nil
    doorStateBags[doorId] = nil
    lastBroadcast[doorId] = nil
    BroadcastDoorDelete(doorId)
    SendActionFeedback(src, true, 'Door deleted', doorId, 'delete')
    debugPrint(3, '🗑️ Deleted door:', doorId, '| By:', GetPlayerName(src))
    NostrLog(
        ('🗑️ Door deleted: %s | By: %s'):format(doorId, GetPlayerName(src)),
        {{'event','door_deleted'},{'doorId',doorId},{'player',GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:setPrice', function(doorId, price)
    local src  = source
    local door = doors[doorId]
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'price'); return end
    if not Ox then SendActionFeedback(src, false, 'Framework error', doorId, 'price'); return end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then SendActionFeedback(src, false, 'Player data error', doorId, 'price'); return end
    if not (IsPlayerAdmin(src) or (door.owner_charid and tostring(door.owner_charid) == tostring(player.charId))) then
        SendActionFeedback(src, false, 'No permission', doorId, 'price'); return
    end
    door.price = math.max(0, tonumber(price) or 0)
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Price updated', doorId, 'price')
    debugPrint(3, '💰 Price updated for door:', doorId, '| New price:', door.price, '| By:', GetPlayerName(src))
    NostrLog(
        ('💰 Price set: %s → $%d | By: %s'):format(door.name, door.price, GetPlayerName(src)),
        {{'event','door_price_set'},{'doorId',doorId},{'price',tostring(door.price)},{'player',GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:rename', function(doorId, name)
    local src  = source
    local door = doors[doorId]
    if not door or not name or name == '' then SendActionFeedback(src, false, 'Invalid name', doorId, 'rename'); return end
    if not Ox then SendActionFeedback(src, false, 'Framework error', doorId, 'rename'); return end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then SendActionFeedback(src, false, 'Player data error', doorId, 'rename'); return end
    if not (IsPlayerAdmin(src) or (door.owner_charid and tostring(door.owner_charid) == tostring(player.charId))) then
        SendActionFeedback(src, false, 'No permission', doorId, 'rename'); return
    end
    door.name = name
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Door renamed', doorId, 'rename')
    debugPrint(3, '✏️ Renamed door:', doorId, '| New name:', name, '| By:', GetPlayerName(src))
    NostrLog(
        ('✏️ Door renamed: %s → %s | By: %s'):format(doorId, name, GetPlayerName(src)),
        {{'event','door_renamed'},{'doorId',doorId},{'newName',name},{'player',GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:manageAccess', function(doorId, targetIdentifier, grantAccess)
    local src  = source
    local door = doors[doorId]
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'access'); return end
    if not Ox then SendActionFeedback(src, false, 'Framework error', doorId, 'access'); return end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then SendActionFeedback(src, false, 'Player data error', doorId, 'access'); return end
    if not (IsPlayerAdmin(src) or (door.owner_charid and tostring(door.owner_charid) == tostring(player.charId))) then
        SendActionFeedback(src, false, 'No permission', doorId, 'access'); return
    end
    local accessList = door.access_list or {}
    if grantAccess then
        local targetPlayer = Ox.GetPlayer(targetIdentifier)
        if targetPlayer and targetPlayer.charId then
            local charId = tostring(targetPlayer.charId)
            local found = false
            for _, id in ipairs(accessList) do
                if tostring(id) == charId then found = true; break end
            end
            if not found then table.insert(accessList, charId) end
        else
            SendActionFeedback(src, false, 'Target player not found', doorId, 'access'); return
        end
    else
        for i = #accessList, 1, -1 do
            if tostring(accessList[i]) == tostring(targetIdentifier) then
                table.remove(accessList, i); break
            end
        end
    end
    door.access_list = accessList
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Access updated', doorId, 'access')
    NostrLog(
        ('🔑 Access %s on %s | Target: %s | By: %s'):format(grantAccess and 'granted' or 'revoked', door.name, tostring(targetIdentifier), GetPlayerName(src)),
        {{'event','door_access_changed'},{'doorId',doorId},{'target',tostring(targetIdentifier)},{'granted',tostring(grantAccess)},{'player',GetPlayerName(src)}}
    )
end)

RegisterNetEvent('rde_doors:ringBell', function(doorId)
    local src  = source
    local door = doors[doorId]
    if not door or not door.owner_charid or not Ox then return end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then return end
    local playerName = (player.get('firstName') or 'Unknown') .. ' ' .. (player.get('lastName') or 'Player')
    for _, playerId in ipairs(GetPlayers()) do
        local tp = Ox.GetPlayer(tonumber(playerId))
        if tp and tostring(tp.charId) == tostring(door.owner_charid) then
            TriggerClientEvent('ox_lib:notify', tp.source, {
                title = '🔔 Someone is ringing',
                description = playerName .. ' is at ' .. door.name,
                type = 'inform', duration = 5000
            })
            break
        end
    end
end)

RegisterNetEvent('rde_doors:knock', function(doorId)
    local src  = source
    local door = doors[doorId]
    if not door or not door.owner_charid or not Ox then return end
    local player = Ox.GetPlayer(src)
    if not player or not player.charId then return end
    local playerName = (player.get('firstName') or 'Unknown') .. ' ' .. (player.get('lastName') or 'Player')
    for _, playerId in ipairs(GetPlayers()) do
        local tp = Ox.GetPlayer(tonumber(playerId))
        if tp and tostring(tp.charId) == tostring(door.owner_charid) then
            TriggerClientEvent('ox_lib:notify', tp.source, {
                title = '👊 Someone is knocking',
                description = playerName .. ' is knocking at ' .. door.name,
                type = 'inform', duration = 5000
            })
            break
        end
    end
end)

-- ============================================
-- 📊 DOOR GROUP EVENTS
-- ============================================
RegisterNetEvent('rde_doors:createGroup', function(name)
    local src = source
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', nil, 'group_create'); return end
    if not name or name == '' then SendActionFeedback(src, false, 'Invalid name', nil, 'group_create'); return end
    local groupId = GenerateGroupId()
    if not CreateDoorGroup(groupId, { name = name, doors = {} }) then
        SendActionFeedback(src, false, 'Failed to create group', nil, 'group_create'); return
    end
    doorGroups[groupId] = { id = groupId, name = name, doors = {} }
    BroadcastDoorGroupUpdate(groupId, doorGroups[groupId])
    SendActionFeedback(src, true, 'Group created', nil, 'group_create')
    NostrLog(('✅ Group created: %s | By: %s'):format(name, GetPlayerName(src)), {{'event','door_group_created'},{'groupId',groupId},{'groupName',name},{'player',GetPlayerName(src)}})
end)

RegisterNetEvent('rde_doors:renameGroup', function(groupId, name)
    local src   = source
    local group = doorGroups[groupId]
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', nil, 'group_rename'); return end
    if not group then SendActionFeedback(src, false, 'Group not found', nil, 'group_rename'); return end
    if not name or name == '' then SendActionFeedback(src, false, 'Invalid name', nil, 'group_rename'); return end
    group.name = name
    doorGroups[groupId] = group
    CreateThread(function() SaveDoorGroup(groupId, group) end)
    BroadcastDoorGroupUpdate(groupId, group)
    SendActionFeedback(src, true, 'Group renamed', nil, 'group_rename')
end)

RegisterNetEvent('rde_doors:deleteGroup', function(groupId)
    local src   = source
    local group = doorGroups[groupId]
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', nil, 'group_delete'); return end
    if not group then SendActionFeedback(src, false, 'Group not found', nil, 'group_delete'); return end
    if not DeleteDoorGroup(groupId) then SendActionFeedback(src, false, 'Failed to delete group', nil, 'group_delete'); return end
    doorGroups[groupId] = nil
    BroadcastDoorGroupDelete(groupId)
    SendActionFeedback(src, true, 'Group deleted', nil, 'group_delete')
end)

RegisterNetEvent('rde_doors:addToGroup', function(doorId, groupId)
    local src   = source
    local door  = doors[doorId]
    local group = doorGroups[groupId]
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', nil, 'add_to_group'); return end
    if not door  then SendActionFeedback(src, false, 'Door not found',  nil, 'add_to_group'); return end
    if not group then SendActionFeedback(src, false, 'Group not found', nil, 'add_to_group'); return end
    local found = false
    for _, id in ipairs(group.doors) do if id == doorId then found = true; break end end
    if not found then
        table.insert(group.doors, doorId)
        door.group_id = groupId
        doors[doorId] = door
        CreateThread(function() SaveDoorGroup(groupId, group); SaveDoor(doorId, door) end)
        BroadcastDoorGroupUpdate(groupId, group)
        BroadcastDoorUpdate(doorId, door)
        SendActionFeedback(src, true, 'Door added to group', nil, 'add_to_group')
    else
        SendActionFeedback(src, false, 'Door already in group', nil, 'add_to_group')
    end
end)

RegisterNetEvent('rde_doors:removeFromGroup', function(doorId, groupId)
    local src   = source
    local door  = doors[doorId]
    local group = doorGroups[groupId]
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', nil, 'remove_from_group'); return end
    if not door  then SendActionFeedback(src, false, 'Door not found',  nil, 'remove_from_group'); return end
    if not group then SendActionFeedback(src, false, 'Group not found', nil, 'remove_from_group'); return end
    for i = #group.doors, 1, -1 do
        if group.doors[i] == doorId then
            table.remove(group.doors, i)
            door.group_id = nil
            doors[doorId] = door
            CreateThread(function() SaveDoorGroup(groupId, group); SaveDoor(doorId, door) end)
            BroadcastDoorGroupUpdate(groupId, group)
            BroadcastDoorUpdate(doorId, door)
            SendActionFeedback(src, true, 'Door removed from group', nil, 'remove_from_group')
            return
        end
    end
    SendActionFeedback(src, false, 'Door not in group', nil, 'remove_from_group')
end)

-- ============================================
-- 📊 ADMIN COMMANDS
-- ============================================
lib.addCommand('doorslist', { help = 'List all doors', restricted = false }, function(source)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { title='Error', description='No permission', type='error' }); return
    end
    local count, valid, invalid = 0, 0, 0
    print('^3========== RDE DOORS ==========^7')
    for doorId, door in pairs(doors) do
        count = count + 1
        if door.coords and type(door.coords.x) == 'number' then
            valid = valid + 1
            local typeLabel = door.door_a and '[DOUBLE]' or '[SINGLE]'
            print(string.format('^5[%d]^7 %s %s | %s | %s | %.2f, %.2f, %.2f',
                valid, typeLabel, doorId, door.name,
                door.locked and 'Locked' or 'Unlocked',
                door.coords.x, door.coords.y, door.coords.z))
        else
            invalid = invalid + 1
            print(string.format('^1[%d]^7 %s | %s | ^1INVALID COORDS^7', count, doorId, door.name))
        end
    end
    print('^3================================^7')
    print(string.format('^2Total:^7 %d | ^2Valid:^7 %d | ^1Invalid:^7 %d', count, valid, invalid))
    TriggerClientEvent('ox_lib:notify', source, {
        title='Doors', description=('Total: %d (Valid: %d, Invalid: %d)'):format(count, valid, invalid), type='info'
    })
end)

lib.addCommand('resyncdoors', { help = 'Resync all doors', restricted = false }, function(source)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { title='Error', description='No permission', type='error' }); return
    end
    debugPrint(3, '🔄 Resyncing all doors...')
    if not LoadDoors() or not LoadDoorGroups() then
        SendActionFeedback(source, false, 'Failed to reload doors', nil, 'resync'); return
    end
    for _, playerId in ipairs(GetPlayers()) do
        CreateThread(function() SyncAllDoors(tonumber(playerId)) end)
    end
    SendActionFeedback(source, true, 'Doors resynced', nil, 'resync')
    debugPrint(3, '✅ Doors resynced by:', GetPlayerName(source))
end)

lib.addCommand('cleandoors', { help = 'Clean up invalid doors', restricted = false }, function(source)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { title='Error', description='No permission', type='error' }); return
    end
    if not MySQL then SendActionFeedback(source, false, 'MySQL not available', nil, 'clean'); return end
    debugPrint(3, '🧹 Starting database cleanup...')
    local ok, result = pcall(function()
        return MySQL.query.await('SELECT id, coords FROM rde_owned_doors')
    end)
    if not ok then SendActionFeedback(source, false, 'Failed to query doors', nil, 'clean'); return end
    local deleted, kept = 0, 0
    for _, row in ipairs(result) do
        local coords = DeserializeCoords(row.coords)
        if not coords or type(coords.x) ~= 'number' then
            pcall(function() MySQL.query.await('DELETE FROM rde_owned_doors WHERE id=?', {row.id}) end)
            deleted = deleted + 1
        else
            kept = kept + 1
        end
    end
    LoadDoors(); LoadDoorGroups()
    for _, playerId in ipairs(GetPlayers()) do
        CreateThread(function() SyncAllDoors(tonumber(playerId)) end)
    end
    SendActionFeedback(source, true, ('Cleanup: %d deleted, %d kept'):format(deleted, kept), nil, 'clean')
end)

lib.addCommand('doorinfo', { help = 'Get info about nearest door', restricted = false }, function(source)
    if not IsPlayerAdmin(source) then return end
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local nearest, nearestDist = nil, 999999.0
    for _, door in pairs(doors) do
        if door.coords then
            local dx, dy, dz = playerCoords.x - door.coords.x, playerCoords.y - door.coords.y, playerCoords.z - door.coords.z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            if dist < nearestDist and dist < 10.0 then nearestDist = dist; nearest = door end
        end
    end
    if nearest then
        print('^3========== DOOR INFO ==========^7')
        print('^5ID:^7', nearest.id)
        print('^5Name:^7', nearest.name)
        print('^5Type:^7', nearest.type or 'single')
        if nearest.door_a then
            print('^5Door A model:^7', nearest.door_a.model)
            print('^5Door B model:^7', nearest.door_b.model)
        else
            print('^5Model:^7', nearest.model)
        end
        print('^5Locked:^7', nearest.locked and 'Yes' or 'No')
        print('^5Owner:^7', nearest.owner_name or 'None', '| CharID:', nearest.owner_charid or 'None')
        print('^5Price:^7', nearest.price or 0)
        print('^5Distance:^7', string.format('%.2f m', nearestDist))
        print('^5Coords:^7', string.format('%.2f, %.2f, %.2f', nearest.coords.x, nearest.coords.y, nearest.coords.z))
        print('^5Group:^7', nearest.group_id or 'None')
        print('^3================================^7')
        TriggerClientEvent('ox_lib:notify', source, {
            title='Nearest Door',
            description=string.format('%s (%.1fm) [%s]', nearest.name, nearestDist, nearest.type or 'single'),
            type='info'
        })
    else
        TriggerClientEvent('ox_lib:notify', source, { title='No Door Found', description='No door within 10 meters', type='error' })
    end
end)

-- ============================================
-- 🚀 INITIALIZATION
-- ============================================
CreateThread(function()
    debugPrint(3, '🚀 Starting RDE Doors v3.0.0 initialization...')
    while GetResourceState('oxmysql') ~= 'started' do
        debugPrint(3, '⏳ Waiting for oxmysql...')
        Wait(500)
    end
    while GetResourceState('ox_core') ~= 'started' do Wait(100) end

    local ok, result = pcall(require, '@ox_core/lib/init')
    if ok and result then
        Ox = result
        debugPrint(3, '✅ ox_core loaded')
    else
        debugPrint(1, '❌ ox_core load failed')
        return
    end

    ok, result = pcall(require, 'shared.config')
    if ok and result then
        Config = result
        L = Config.Lang[Config.DefaultLanguage or 'en']
        debugPrint(3, '✅ Config loaded')
    else
        debugPrint(2, '⚠️ Using fallback config')
        Config = {
            Debug = true,
            Defaults = { type = 'single', locked = true, autolock = 0, heading = 0, maxDistance = 2.5, price = 0 },
            AdminSystem = { acePermission = 'rde.doors.admin', oxGroups = { admin = true, superadmin = true } },
            Performance = { useStateBags = true }
        }
        L = { doorNotFound = 'Door not found', accessDenied = 'Access denied', noPermission = 'No permission' }
    end

    debugPrint(3, '🔧 Initializing database (running auto-migration if needed)...')
    if InitializeDatabase() then
        Wait(500)
        if LoadDoors() and LoadDoorGroups() then
            local count, valid = 0, 0
            for _, door in pairs(doors) do
                count = count + 1
                if door.coords and type(door.coords.x) == 'number' then valid = valid + 1 end
            end
            debugPrint(3, '✅ Server ready with', count, 'doors (', valid, 'valid) and', #doorGroups, 'groups')
            print('^2[RDE Doors v3.0.0] ✅ Ready – ' .. count .. ' doors (' .. valid .. ' valid) | Double Door Support ACTIVE^7')
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
    doors = {}; doorGroups = {}; doorStateBags = {}; lastBroadcast = {}; initialized = false
end)

AddEventHandler('ox:playerLoaded', function(playerId, userId, charId)
    if not playerId then return end
    debugPrint(3, '👤 Player loaded:', GetPlayerName(playerId), '| CharID:', charId)
    SetTimeout(1000, function()
        if GetPlayerPing(playerId) > 0 then SyncAllDoors(playerId) end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    debugPrint(4, '👋 Player dropped:', GetPlayerName(source), '| Reason:', reason)
end)

debugPrint(3, '✅ Server script loaded successfully')
print('^2[RDE | Doors | Server v3.0.0] 📜 Ready^7')
