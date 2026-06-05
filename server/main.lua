-- ============================================
-- 🚪 RDE DOORS - SERVER
-- ============================================
-- Version: 4.0.0 (ox_doorlock Feature Parity + Backward Compat)
-- Author: RDE | SerpentsByte
-- Features: Double Doors, Sliding/Automatic Doors, Lockpick, Passcode,
--           Autolock, Group+Grade Auth, Item Metadata, Custom Sounds,
--           Hold Open, Hide UI, Door Groups, Auto-Migration, Nostr Logging,
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

-- Autolock timer tracking: doorId → timer handle (so we can cancel if re-locked manually)
local autolockTimers = {}

-- Pick-cooldown per source (anti-spam)
local pickCooldown = {}

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
    if data.door_a and data.door_b then
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
    if not result.door_a or not result.door_b then return nil end
    local a, b = result.door_a, result.door_b
    if not a.coords or not b.coords then return nil end
    a.coords = DeserializeCoords(a.coords) or a.coords
    b.coords = DeserializeCoords(b.coords) or b.coords
    return result
end

-- Safe JSON decode helper for v4 columns
local function SafeJsonDecode(raw, default)
    if not raw or raw == '' then return default end
    if type(raw) ~= 'string' then return raw end
    local ok, result = pcall(json.decode, raw)
    if ok and result ~= nil then return result end
    return default
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
        debugPrint(4, 'Admin verified (ACE):', GetPlayerName(source))
        return true
    end
    if Ox then
        local player = Ox.GetPlayer(source)
        if player and player.charId then
            local groups = player.getGroups and player.getGroups() or {}
            if groups.admin or groups.superadmin or groups.management then
                debugPrint(4, 'Admin verified (ox_core):', GetPlayerName(source))
                return true
            end
        end
    end
    return false
end

-- ============================================
-- 🔐 ACCESS CHECKING (v4 — extended)
-- ============================================
-- Returns: authorised (bool), reason (string)
-- ox_inventory metadata helper
-- ox_inventory:Search(inv, search, items, metadata) — metadata can be string (type filter) or table
local function HasItemWithMetadata(source, itemName, metadataType)
    if not exports.ox_inventory then return false end
    if metadataType and metadataType ~= '' then
        -- Pass metadata directly as ox_inventory expects (mirrors ox_doorlock behavior)
        local results = exports.ox_inventory:Search(source, 'slots', itemName, metadataType)
        if results and results[1] and results[1].count and results[1].count > 0 then
            return true, results[1].slot
        end
        return false
    else
        local count = exports.ox_inventory:GetItemCount(source, itemName) or 0
        return count > 0
    end
end

local function HasAccess(door, source, opts)
    opts = opts or {}
    if not door or not source then return false end
    if IsPlayerAdmin(source) then return true, 'admin' end
    if not Ox then return false, 'no_framework' end
    local player = Ox.GetPlayer(source)
    if not player or not player.charId then return false, 'no_player' end
    local charId = tostring(player.charId)

    -- 1) Owner check
    if door.owner_charid and tostring(door.owner_charid) == charId then return true, 'owner' end

    -- 2) Access list (per-character)
    if door.access_list and type(door.access_list) == 'table' then
        for _, accessCharId in ipairs(door.access_list) do
            if tostring(accessCharId) == charId then return true, 'access_list' end
        end
    end

    -- 3) Legacy `auth` array (group name only, grade 0)
    if door.auth and type(door.auth) == 'table' and #door.auth > 0 then
        local groups = player.getGroups and player.getGroups() or {}
        for groupName in pairs(groups) do
            for _, authGroup in ipairs(door.auth) do
                if groupName == authGroup then return true, 'legacy_auth' end
            end
        end
    end

    -- 4) NEW v4: groups_data with grade requirement { groupName = minGrade }
    if door.groups_data and type(door.groups_data) == 'table' then
        local playerGroups = player.getGroups and player.getGroups() or {}
        for groupName, minGrade in pairs(door.groups_data) do
            local playerGrade = playerGroups[groupName]
            if playerGrade ~= nil then
                -- ox_core groups: grade is an integer; some frameworks store as boolean true
                local pg = type(playerGrade) == 'number' and playerGrade
                       or (playerGrade == true and 0)
                       or tonumber(playerGrade)
                local mg = tonumber(minGrade) or 0
                if pg and pg >= mg then return true, 'group_grade' end
            end
        end
    end

    -- 5) NEW v4: items_data with metadata { name, metadata, remove }
    if door.items_data and type(door.items_data) == 'table' and exports.ox_inventory then
        for _, itemDef in ipairs(door.items_data) do
            if type(itemDef) == 'table' and itemDef.name then
                local has, slot = HasItemWithMetadata(source, itemDef.name, itemDef.metadata)
                if has then return true, ('item_meta:%s'):format(itemDef.name), itemDef, slot end
            end
        end
    end

    -- 6) Legacy items array (simple, no metadata)
    -- IMPORTANT: items array originally allowed access just by *having* the item.
    -- v4 preserves this behavior for backward compat.
    if door.items and type(door.items) == 'table' and #door.items > 0 and exports.ox_inventory then
        for _, item in ipairs(door.items) do
            local count = exports.ox_inventory:GetItemCount(source, item) or 0
            if count > 0 then return true, ('item:%s'):format(item) end
        end
    end

    -- 7) NEW v4: Passcode (handled separately if `opts.passcode` provided)
    if opts.passcode and door.passcode and door.passcode ~= '' then
        if tostring(opts.passcode) == tostring(door.passcode) then
            return true, 'passcode'
        end
    end

    return false, 'no_match'
end

-- ============================================
-- 💾 DATABASE — AUTO-MIGRATION (v4)
-- ============================================
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

    -- ── Auto-migration: v3.0.0 column + v4.0.0 columns ──
    -- `postMigration` runs ONCE — only when the column is freshly added — so it backfills
    -- existing doors based on their type. Subsequent loads respect whatever the user explicitly set.
    local migrations = {
        -- v3.0.0
        { col = 'double_door_data',    sql = 'ALTER TABLE rde_owned_doors ADD COLUMN double_door_data LONGTEXT DEFAULT NULL' },
        -- v4.0.0 - ox_doorlock feature parity
        { col = 'passcode',            sql = 'ALTER TABLE rde_owned_doors ADD COLUMN passcode VARCHAR(100) DEFAULT NULL' },
        {
            col = 'auto',
            sql = 'ALTER TABLE rde_owned_doors ADD COLUMN `auto` TINYINT(1) DEFAULT 0',
            -- v3→v4: existing sliding/garage/gate doors should default to auto=1
            postMigration = [[
                UPDATE rde_owned_doors
                SET `auto`=1
                WHERE type IN ('sliding','garage','gate') AND (`auto`=0 OR `auto` IS NULL)
            ]]
        },
        { col = 'door_rate',           sql = 'ALTER TABLE rde_owned_doors ADD COLUMN door_rate FLOAT DEFAULT NULL' },
        { col = 'lockpick',            sql = 'ALTER TABLE rde_owned_doors ADD COLUMN lockpick TINYINT(1) DEFAULT 0' },
        { col = 'lockpick_difficulty', sql = 'ALTER TABLE rde_owned_doors ADD COLUMN lockpick_difficulty LONGTEXT DEFAULT NULL' },
        { col = 'hide_ui',             sql = 'ALTER TABLE rde_owned_doors ADD COLUMN hide_ui TINYINT(1) DEFAULT 0' },
        { col = 'hold_open',           sql = 'ALTER TABLE rde_owned_doors ADD COLUMN hold_open TINYINT(1) DEFAULT 0' },
        { col = 'lock_sound',          sql = 'ALTER TABLE rde_owned_doors ADD COLUMN lock_sound VARCHAR(100) DEFAULT NULL' },
        { col = 'unlock_sound',        sql = 'ALTER TABLE rde_owned_doors ADD COLUMN unlock_sound VARCHAR(100) DEFAULT NULL' },
        { col = 'groups_data',         sql = 'ALTER TABLE rde_owned_doors ADD COLUMN groups_data LONGTEXT DEFAULT NULL' },
        { col = 'items_data',          sql = 'ALTER TABLE rde_owned_doors ADD COLUMN items_data LONGTEXT DEFAULT NULL' },
    }

    local migratedCount = 0
    for _, m in ipairs(migrations) do
        if not ColumnExists('rde_owned_doors', m.col) then
            local mOk, mErr = pcall(MySQL.query.await, m.sql)
            if mOk then
                debugPrint(3, '✅ Migration applied: added column', m.col)
                migratedCount = migratedCount + 1
                -- Run post-migration backfill if defined
                if m.postMigration then
                    local pmOk, pmRes = pcall(function()
                        return MySQL.update.await(m.postMigration)
                    end)
                    if pmOk then
                        debugPrint(3, '   ↳ Backfill applied for', m.col, '— affected:', tostring(pmRes))
                    else
                        debugPrint(2, '   ↳ Backfill failed for', m.col, ':', tostring(pmRes))
                    end
                end
            else
                debugPrint(1, '❌ Migration failed for column', m.col, ':', tostring(mErr))
                return false
            end
        else
            debugPrint(4, '✔ Column already exists:', m.col)
        end
    end

    if migratedCount > 0 then
        print('^2[RDE Doors v4.0.0] ✅ Migration: ' .. migratedCount .. ' new column(s) added^7')
        NostrLog(('🔧 DB Migration: %d column(s) added'):format(migratedCount), {{'event','db_migration'},{'cols',tostring(migratedCount)}})
    end

    debugPrint(3, '✅ Database ready (schema up to date)')
    return true
end

-- ============================================
-- 💾 LOAD / SAVE
-- ============================================

-- Helper: turn a tinyint/bool/number/string-bool into proper bool
local function ToBool(v)
    if v == nil then return false end
    if type(v) == 'boolean' then return v end
    if type(v) == 'number' then return v == 1 end
    if type(v) == 'string' then return v == '1' or v:lower() == 'true' end
    return false
end

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
                        locked       = ToBool(row.locked),
                        auth         = SafeJsonDecode(row.auth, {}),
                        autolock     = tonumber(row.autolock) or 0,
                        items        = SafeJsonDecode(row.items, {}),
                        heading      = row.heading or 0.0,
                        maxDistance  = tonumber(row.maxDistance) or 2.5,
                        owner_charid = row.owner_charid,
                        owner_name   = row.owner_name,
                        price        = tonumber(row.price) or 0,
                        access_list  = SafeJsonDecode(row.access_list, {}),
                        group_id     = row.group_id,
                        -- v4.0.0 fields
                        passcode            = row.passcode,
                        auto                = ToBool(row.auto),
                        door_rate           = row.door_rate ~= nil and tonumber(row.door_rate) or nil,
                        lockpick            = ToBool(row.lockpick),
                        lockpick_difficulty = SafeJsonDecode(row.lockpick_difficulty, nil),
                        hide_ui             = ToBool(row.hide_ui),
                        hold_open           = ToBool(row.hold_open),
                        lock_sound          = row.lock_sound,
                        unlock_sound        = row.unlock_sound,
                        groups_data         = SafeJsonDecode(row.groups_data, nil),
                        items_data          = SafeJsonDecode(row.items_data, nil),
                    }

                    -- Double door
                    if row.double_door_data and row.double_door_data ~= '' then
                        local dd = DeserializeDoubleDoor(row.double_door_data)
                        if dd then
                            door.door_a = dd.door_a
                            door.door_b = dd.door_b
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
                    doors = SafeJsonDecode(row.doors, {}),
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

-- JSON-encode nullable fields, returning nil if empty (so DB stays clean)
local function MaybeJson(value)
    if value == nil then return nil end
    if type(value) == 'table' and next(value) == nil then return nil end
    return json.encode(value)
end

local function SaveDoor(doorId, door)
    if not MySQL or not doorId or not door then return false end
    if not door.coords or type(door.coords.x) ~= 'number' then
        debugPrint(1, '❌ Invalid coords for door:', doorId)
        return false
    end
    local ddJson = BuildDoubleDoorJson(door)
    local ok, err = pcall(function()
        MySQL.update.await([[
            UPDATE rde_owned_doors SET
                type=?, name=?, coords=?, model=?, model_hash=?,
                locked=?, auth=?, autolock=?, items=?, heading=?,
                maxDistance=?, owner_charid=?, owner_name=?, price=?,
                access_list=?, group_id=?, double_door_data=?,
                passcode=?, `auto`=?, door_rate=?, lockpick=?,
                lockpick_difficulty=?, hide_ui=?, hold_open=?,
                lock_sound=?, unlock_sound=?, groups_data=?, items_data=?
            WHERE id=?
        ]], {
            door.type,
            door.name,
            SerializeCoords(door.coords),
            door.model or '',
            door.model_hash,
            door.locked and 1 or 0,
            json.encode(door.auth or {}),
            door.autolock or 0,
            json.encode(door.items or {}),
            door.heading,
            door.maxDistance,
            door.owner_charid,
            door.owner_name,
            door.price,
            json.encode(door.access_list or {}),
            door.group_id,
            ddJson,
            -- v4 fields
            (door.passcode ~= nil and door.passcode ~= '') and door.passcode or nil,
            door.auto and 1 or 0,
            door.door_rate,
            door.lockpick and 1 or 0,
            MaybeJson(door.lockpick_difficulty),
            door.hide_ui and 1 or 0,
            door.hold_open and 1 or 0,
            (door.lock_sound ~= nil and door.lock_sound ~= '') and door.lock_sound or nil,
            (door.unlock_sound ~= nil and door.unlock_sound ~= '') and door.unlock_sound or nil,
            MaybeJson(door.groups_data),
            MaybeJson(door.items_data),
            doorId,
        })
    end)
    if not ok then debugPrint(1, '❌ SaveDoor failed:', doorId, '|', tostring(err)) end
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
    local ok, err = pcall(function()
        MySQL.insert.await([[
            INSERT INTO rde_owned_doors
            (id,type,name,coords,model,model_hash,locked,auth,autolock,items,
             heading,maxDistance,owner_charid,owner_name,price,access_list,group_id,double_door_data,
             passcode,`auto`,door_rate,lockpick,lockpick_difficulty,hide_ui,hold_open,
             lock_sound,unlock_sound,groups_data,items_data)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
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
            -- v4 fields
            (door.passcode ~= nil and door.passcode ~= '') and door.passcode or nil,
            door.auto and 1 or 0,
            door.door_rate,
            door.lockpick and 1 or 0,
            MaybeJson(door.lockpick_difficulty),
            door.hide_ui and 1 or 0,
            door.hold_open and 1 or 0,
            (door.lock_sound ~= nil and door.lock_sound ~= '') and door.lock_sound or nil,
            (door.unlock_sound ~= nil and door.unlock_sound ~= '') and door.unlock_sound or nil,
            MaybeJson(door.groups_data),
            MaybeJson(door.items_data),
        })
    end)
    if not ok then debugPrint(1, '❌ CreateDoor failed:', doorId, '|', tostring(err)) end
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

-- Build a safe client-side representation of a door.
-- IMPORTANT: We sanitize the passcode — client only gets a boolean `has_passcode`,
-- never the actual code. This prevents trivial passcode extraction by curious players.
local function BuildClientDoor(door)
    return {
        id           = door.id,
        type         = door.type,
        name         = door.name,
        coords       = door.coords,
        model        = door.model,
        model_hash   = door.model_hash,
        locked       = door.locked,
        auth         = door.auth,
        autolock     = door.autolock,
        items        = door.items,
        heading      = door.heading,
        maxDistance  = door.maxDistance,
        owner_charid = door.owner_charid,
        owner_name   = door.owner_name,
        price        = door.price,
        access_list  = door.access_list,
        group_id     = door.group_id,
        door_a       = door.door_a,
        door_b       = door.door_b,
        -- v4: safe fields
        has_passcode        = door.passcode ~= nil and door.passcode ~= '',
        auto                = door.auto or false,
        door_rate           = door.door_rate,
        lockpick            = door.lockpick or false,
        lockpick_difficulty = door.lockpick_difficulty,
        hide_ui             = door.hide_ui or false,
        hold_open           = door.hold_open or false,
        lock_sound          = door.lock_sound,
        unlock_sound        = door.unlock_sound,
        groups_data         = door.groups_data,
        items_data          = door.items_data,
    }
end

local function BroadcastDoorUpdate(doorId, door)
    if not doorId or not door then return end
    if not door.coords or type(door.coords.x) ~= 'number' then
        debugPrint(1, '❌ Invalid coords in broadcast:', doorId)
        return
    end
    local t = GetGameTimer()
    if lastBroadcast[doorId] and (t - lastBroadcast[doorId] < broadcastCooldown) then return end
    lastBroadcast[doorId] = t
    TriggerClientEvent('rde_doors:doorUpdate', -1, doorId, BuildClientDoor(door))
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
            table.insert(doorArray, BuildClientDoor(door))
        end
    end
    TriggerClientEvent('rde_doors:syncDoors', source, doorArray, doorGroups)
    debugPrint(3, '📤 Synced', #doorArray, 'doors to', GetPlayerName(source))
end

-- ============================================
-- 🔒 LOCK STATE MANAGEMENT (v4 — central function)
-- ============================================
-- Handles toggling lock state, autolock scheduling, sound triggers, notifications.
-- Single source of truth for all lock-state changes.
local function SetDoorState(doorId, newState, reason, source)
    local door = doors[doorId]
    if not door then return false, 'door_not_found' end

    door.locked = (newState == true or newState == 1 or newState == 'lock')
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)

    -- Trigger external event hook
    TriggerEvent('rde_doors:stateChanged', source, doorId, door.locked, reason)

    -- Autolock: when door becomes UNLOCKED and autolock > 0, schedule re-lock
    if not door.locked and door.autolock and door.autolock > 0 then
        -- Cancel previous timer if any
        if autolockTimers[doorId] then
            autolockTimers[doorId] = nil  -- old timer will check and skip
        end
        local thisTimer = GetGameTimer()
        autolockTimers[doorId] = thisTimer

        SetTimeout(door.autolock * 1000, function()
            -- Only re-lock if this is still the active timer (door not re-locked manually meanwhile)
            if autolockTimers[doorId] ~= thisTimer then return end
            autolockTimers[doorId] = nil
            local d = doors[doorId]
            if d and not d.locked then
                d.locked = true
                doors[doorId] = d
                CreateThread(function() SaveDoor(doorId, d) end)
                BroadcastDoorUpdate(doorId, d)
                TriggerEvent('rde_doors:stateChanged', nil, doorId, true, 'autolock')
                NostrLog(
                    ('⏱️ Autolock: %s'):format(d.name),
                    {{'event','door_autolock'},{'doorId',doorId},{'doorName',d.name}}
                )
                debugPrint(3, '⏱️ Autolock fired for door:', doorId)
            end
        end)
    else
        -- Lock state changed to locked — clear pending autolock timer
        if door.locked then autolockTimers[doorId] = nil end
    end

    return true
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
    local oldPrice = door.price
    door.price = 0
    if not SaveDoor(doorId, door) then
        exports.ox_inventory:AddItem(source, 'money', oldPrice)
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
    if door.locked then SetDoorState(doorId, false, 'item:'..item, source) end
    return true, 'Item used successfully'
end)

-- v4: Verify passcode without changing state (used for "knock-style" pre-check if needed)
lib.callback.register('rde_doors:verifyPasscode', function(source, doorId, passcode)
    local door = doors[doorId]
    if not door or not door.passcode or door.passcode == '' then return false end
    return tostring(passcode) == tostring(door.passcode)
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

-- v4: toggleLock now optionally accepts a passcode parameter (for non-authorized players)
RegisterNetEvent('rde_doors:toggleLock', function(doorId, passcode)
    local src  = source
    local door = doors[doorId]
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'toggle'); return end

    local authorised, reason, itemDef, slot = HasAccess(door, src, { passcode = passcode })
    if not authorised then
        SendActionFeedback(src, false, passcode and 'Incorrect passcode' or 'Access denied', doorId, 'toggle')
        return
    end

    -- v4: Consume item if items_data entry was matched AND remove = true
    if itemDef and itemDef.remove and itemDef.name and exports.ox_inventory then
        local removed = false
        if slot then
            removed = exports.ox_inventory:RemoveItem(src, itemDef.name, 1, nil, slot)
        else
            removed = exports.ox_inventory:RemoveItem(src, itemDef.name, 1)
        end
        if removed then
            TriggerClientEvent('ox_lib:notify', src, {
                title = '📦', description = ('Used: %s'):format(itemDef.name), type = 'inform'
            })
        end
    end

    local newLocked = not door.locked
    SetDoorState(doorId, newLocked, reason, src)
    local statusText = newLocked and 'Locked' or 'Unlocked'
    SendActionFeedback(src, true, statusText, doorId, 'toggle')
    debugPrint(3, '🔒 Door', statusText, '| ID:', doorId, '| Player:', GetPlayerName(src), '| Reason:', reason)
    NostrLog(
        ('🔒 Door %s | %s | By: %s | Auth: %s'):format(statusText, door.name, GetPlayerName(src), tostring(reason)),
        {{'event','door_toggle'},{'doorId',doorId},{'status',statusText},{'player',GetPlayerName(src)},{'auth',tostring(reason)}}
    )
end)

-- v4: Lockpick attempt event — called by client after successful skillcheck
RegisterNetEvent('rde_doors:attemptLockpick', function(doorId)
    local src  = source
    local door = doors[doorId]
    if not door then return end
    if not door.lockpick then
        SendActionFeedback(src, false, 'Door cannot be lockpicked', doorId, 'lockpick')
        return
    end

    -- Anti-spam cooldown
    local now = GetGameTimer()
    if pickCooldown[src] and (now - pickCooldown[src]) < 1500 then return end
    pickCooldown[src] = now

    -- Verify player has a lockpick item
    if not exports.ox_inventory then
        SendActionFeedback(src, false, 'Inventory unavailable', doorId, 'lockpick'); return
    end
    local hasItem = false
    local pickItem = nil
    for _, itemName in ipairs(Config.Lockpick.items) do
        if exports.ox_inventory:GetItemCount(src, itemName) > 0 then
            hasItem = true
            pickItem = itemName
            break
        end
    end
    if not hasItem then
        SendActionFeedback(src, false, 'No lockpick', doorId, 'lockpick')
        return
    end

    -- Don't allow picking unlocked doors unless config allows
    if not door.locked and not Config.Lockpick.canPickUnlocked then
        SendActionFeedback(src, false, 'Door already unlocked', doorId, 'lockpick')
        return
    end

    -- Successful pick — toggle state
    local newLocked = not door.locked
    SetDoorState(doorId, newLocked, 'lockpick:'..pickItem, src)
    SendActionFeedback(src, true, 'Lockpick successful', doorId, 'lockpick')
    NostrLog(
        ('🔧 Lockpick: %s | By: %s | Item: %s'):format(door.name, GetPlayerName(src), pickItem),
        {{'event','door_lockpick'},{'doorId',doorId},{'player',GetPlayerName(src)},{'item',pickItem}}
    )

    -- Random break chance on success
    if math.random() < (Config.Lockpick.breakChanceOnSuccess or 0.05) then
        exports.ox_inventory:RemoveItem(src, pickItem, 1)
        TriggerClientEvent('ox_lib:notify', src, {
            title = '💥', description = 'Lockpick broke', type = 'error'
        })
    end
end)

-- v4: Lockpick FAILED — separate event so we can break the lockpick item
RegisterNetEvent('rde_doors:lockpickFailed', function(doorId)
    local src = source
    local door = doors[doorId]
    if not door or not door.lockpick then return end
    if not exports.ox_inventory then return end

    -- Find lockpick item
    local pickItem = nil
    for _, itemName in ipairs(Config.Lockpick.items) do
        if exports.ox_inventory:GetItemCount(src, itemName) > 0 then
            pickItem = itemName
            break
        end
    end
    if not pickItem then return end

    -- Break chance on fail
    if math.random() < (Config.Lockpick.breakChanceOnFail or 0.20) then
        exports.ox_inventory:RemoveItem(src, pickItem, 1)
        TriggerClientEvent('ox_lib:notify', src, {
            title = '💥', description = 'Lockpick broke', type = 'error'
        })
        NostrLog(
            ('💥 Lockpick broke: %s | Item: %s'):format(GetPlayerName(src), pickItem),
            {{'event','lockpick_broke'},{'player',GetPlayerName(src)},{'item',pickItem}}
        )
    end
end)

RegisterNetEvent('rde_doors:createDoor', function(doorData)
    local src = source
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', nil, 'create'); return end
    local valid, message = ValidateDoorData(doorData)
    if not valid then SendActionFeedback(src, false, message, nil, 'create'); return end

    local doorId = GenerateUniqueId()
    local exists, existId = DoesDoorExistAtPosition(doorData.coords)
    if exists then SendActionFeedback(src, false, 'Door already exists', existId, 'create'); return end

    doorData.coords = {
        x = type(doorData.coords.x) == 'number' and doorData.coords.x or 0.0,
        y = type(doorData.coords.y) == 'number' and doorData.coords.y or 0.0,
        z = type(doorData.coords.z) == 'number' and doorData.coords.z or 0.0,
    }

    if doorData.door_a and doorData.door_b then
        doorData.type = 'double'
        doorData.model = ''
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
        -- model_hash may come as integer directly from GetEntityModel() on client
        if doorData.model_hash and type(doorData.model_hash) == 'number' and doorData.model_hash ~= 0 then
            -- already correct integer hash — keep as-is
            doorData.model_hash = doorData.model_hash
        elseif doorData.model and doorData.model ~= '' then
            doorData.model_hash = GetHashKey(doorData.model)
        else
            doorData.model_hash = nil
        end
    end

    doorData.locked      = doorData.locked == nil and true or doorData.locked
    doorData.auth        = doorData.auth or {}
    doorData.items       = doorData.items or {}
    doorData.access_list = doorData.access_list or {}

    -- v4: derive `auto` from door type if not explicitly set
    if doorData.auto == nil and Config.DoorTypes[doorData.type or 'single'] then
        doorData.auto = Config.DoorTypes[doorData.type or 'single'].autoDefault or false
    end

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
        -- v4
        passcode            = doorData.passcode,
        auto                = doorData.auto or false,
        door_rate           = doorData.door_rate,
        lockpick            = doorData.lockpick or false,
        lockpick_difficulty = doorData.lockpick_difficulty,
        hide_ui             = doorData.hide_ui or false,
        hold_open           = doorData.hold_open or false,
        lock_sound          = doorData.lock_sound,
        unlock_sound        = doorData.unlock_sound,
        groups_data         = doorData.groups_data,
        items_data          = doorData.items_data,
    }
    BroadcastDoorUpdate(doorId, doors[doorId])
    SendActionFeedback(src, true, 'Door created', doorId, 'create')
    debugPrint(3, '✅ Created door:', doorId, '| Name:', doorData.name, '| Type:', doorData.type or 'single', '| By:', GetPlayerName(src))
    NostrLog(
        ('✅ Door created: %s (%s) | By: %s'):format(doorData.name, doorData.type or 'single', GetPlayerName(src)),
        {{'event','door_created'},{'doorId',doorId},{'doorName',doorData.name},{'player',GetPlayerName(src)}}
    )
end)

-- v4: Generic updateDoor now accepts ALL fields (was: only name/price/type/auth/group_id/coords)
RegisterNetEvent('rde_doors:updateDoor', function(doorId, updates)
    local src  = source
    local door = doors[doorId]
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'update'); return end
    if not (IsPlayerAdmin(src) or HasAccess(door, src)) then SendActionFeedback(src, false, 'No permission', doorId, 'update'); return end
    if type(updates) ~= 'table' then SendActionFeedback(src, false, 'Invalid update payload', doorId, 'update'); return end

    -- Base fields
    if updates.name     then door.name     = updates.name end
    if updates.type     then door.type     = updates.type end
    if updates.price ~= nil then door.price = tonumber(updates.price) or 0 end
    if updates.auth     then door.auth     = updates.auth end
    if updates.group_id ~= nil then door.group_id = updates.group_id ~= '' and updates.group_id or nil end
    if updates.coords then
        if type(updates.coords.x) ~= 'number' then
            SendActionFeedback(src, false, 'Invalid coordinates', doorId, 'update'); return
        end
        door.coords = updates.coords
    end

    -- v4 fields (only admins can change these — extra safety)
    if IsPlayerAdmin(src) then
        if updates.passcode ~= nil then
            door.passcode = (updates.passcode == '' or updates.passcode == false) and nil or tostring(updates.passcode)
        end
        if updates.autolock ~= nil    then door.autolock    = math.max(0, tonumber(updates.autolock) or 0) end
        if updates.maxDistance ~= nil then door.maxDistance = math.max(0.5, math.min(10.0, tonumber(updates.maxDistance) or 2.5)) end
        if updates.door_rate ~= nil   then
            door.door_rate = (updates.door_rate == '' or updates.door_rate == false) and nil or tonumber(updates.door_rate)
        end
        if updates.auto ~= nil      then door.auto      = updates.auto and true or false end
        if updates.lockpick ~= nil  then door.lockpick  = updates.lockpick and true or false end
        if updates.lockpick_difficulty ~= nil then
            door.lockpick_difficulty = (type(updates.lockpick_difficulty) == 'table' and #updates.lockpick_difficulty > 0)
                                       and updates.lockpick_difficulty or nil
        end
        if updates.hide_ui ~= nil   then door.hide_ui   = updates.hide_ui and true or false end
        if updates.hold_open ~= nil then door.hold_open = updates.hold_open and true or false end
        if updates.lock_sound ~= nil then
            door.lock_sound = (updates.lock_sound == '' or updates.lock_sound == false) and nil or tostring(updates.lock_sound)
        end
        if updates.unlock_sound ~= nil then
            door.unlock_sound = (updates.unlock_sound == '' or updates.unlock_sound == false) and nil or tostring(updates.unlock_sound)
        end
        if updates.groups_data ~= nil then
            door.groups_data = (type(updates.groups_data) == 'table' and next(updates.groups_data)) and updates.groups_data or nil
        end
        if updates.items_data ~= nil then
            door.items_data = (type(updates.items_data) == 'table' and #updates.items_data > 0) and updates.items_data or nil
        end
    end

    doors[doorId] = door
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
    doors[doorId]         = nil
    doorStateBags[doorId] = nil
    lastBroadcast[doorId] = nil
    autolockTimers[doorId] = nil
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
end)

-- v4: Group + Grade management (separate from legacy `auth`)
RegisterNetEvent('rde_doors:manageGroup', function(doorId, groupName, minGrade, grantAccess)
    local src = source
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', doorId, 'group'); return end
    local door = doors[doorId]
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'group'); return end
    if not groupName or groupName == '' then SendActionFeedback(src, false, 'Invalid group', doorId, 'group'); return end

    door.groups_data = door.groups_data or {}
    if grantAccess then
        door.groups_data[groupName] = tonumber(minGrade) or 0
    else
        door.groups_data[groupName] = nil
    end
    if next(door.groups_data) == nil then door.groups_data = nil end
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, grantAccess and 'Group added' or 'Group removed', doorId, 'group')
end)

-- v4: Item + Metadata management
RegisterNetEvent('rde_doors:manageItemData', function(doorId, itemName, metadata, removeOnUse, grantAccess)
    local src = source
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', doorId, 'item_data'); return end
    local door = doors[doorId]
    if not door then SendActionFeedback(src, false, 'Door not found', doorId, 'item_data'); return end
    if not itemName or itemName == '' then SendActionFeedback(src, false, 'Invalid item', doorId, 'item_data'); return end

    door.items_data = door.items_data or {}
    if grantAccess then
        -- Replace existing entry with same name+metadata, or add new
        local replaced = false
        for i, def in ipairs(door.items_data) do
            if def.name == itemName and (def.metadata or '') == (metadata or '') then
                def.remove = removeOnUse and true or false
                replaced = true
                break
            end
        end
        if not replaced then
            table.insert(door.items_data, {
                name = itemName,
                metadata = (metadata ~= nil and metadata ~= '') and metadata or nil,
                remove = removeOnUse and true or false,
            })
        end
    else
        for i = #door.items_data, 1, -1 do
            local d = door.items_data[i]
            if d.name == itemName and (d.metadata or '') == (metadata or '') then
                table.remove(door.items_data, i)
                break
            end
        end
    end
    if #door.items_data == 0 then door.items_data = nil end
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, grantAccess and 'Item added' or 'Item removed', doorId, 'item_data')
end)

-- ==== Legacy item management (kept for backward compatibility) ====
RegisterNetEvent('rde_doors:addDoorItem', function(doorId, item)
    local src  = source
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', doorId, 'item'); return end
    local door = doors[doorId]
    if not door or not item or item == '' then SendActionFeedback(src, false, 'Invalid', doorId, 'item'); return end
    door.items = door.items or {}
    for _, i in ipairs(door.items) do if i == item then return end end
    table.insert(door.items, item)
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Item added', doorId, 'item')
end)

RegisterNetEvent('rde_doors:removeDoorItem', function(doorId, item)
    local src  = source
    if not IsPlayerAdmin(src) then SendActionFeedback(src, false, 'No permission', doorId, 'item'); return end
    local door = doors[doorId]
    if not door or not door.items then return end
    for i = #door.items, 1, -1 do
        if door.items[i] == item then table.remove(door.items, i); break end
    end
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    SendActionFeedback(src, true, 'Item removed', doorId, 'item')
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
-- 📊 DOOR GROUP EVENTS (unchanged from v3)
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
-- 📤 EXPORTS (v4)
-- ============================================
-- Get full server-side door object
exports('getDoor', function(doorId)
    return doors[doorId]
end)

-- Get door by name
exports('getDoorFromName', function(name)
    for _, door in pairs(doors) do
        if door.name == name then return door end
    end
end)

-- Get all doors (returns array of safe client-doors)
exports('getAllDoors', function()
    local arr = {}
    for _, d in pairs(doors) do
        if d.coords then arr[#arr+1] = BuildClientDoor(d) end
    end
    return arr
end)

-- Programmatic state change (bypasses access checks — admin/integration use)
exports('setDoorState', function(doorId, state, reason)
    return SetDoorState(doorId, state, reason or 'export', nil)
end)

-- Programmatic door editing (bypasses access checks — admin/integration use)
exports('editDoor', function(doorId, data)
    local door = doors[doorId]
    if not door or type(data) ~= 'table' then return false end
    for k, v in pairs(data) do
        if k ~= 'id' and k ~= 'coords' then
            door[k] = v
        end
    end
    doors[doorId] = door
    CreateThread(function() SaveDoor(doorId, door) end)
    BroadcastDoorUpdate(doorId, door)
    return true
end)

-- Listen for state changes externally:
--   AddEventHandler('rde_doors:stateChanged', function(source, doorId, locked, reason) ... end)

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
            local flags = {}
            if door.auto      then flags[#flags+1] = 'AUTO' end
            if door.lockpick  then flags[#flags+1] = 'LP' end
            if door.passcode  then flags[#flags+1] = 'PASS' end
            if door.autolock and door.autolock > 0 then flags[#flags+1] = ('AL%ds'):format(door.autolock) end
            local flagStr = #flags > 0 and (' ['..table.concat(flags, ',')..']') or ''
            print(string.format('^5[%d]^7 %s %s%s | %s | %s | %.2f, %.2f, %.2f',
                valid, typeLabel, doorId, flagStr, door.name,
                door.locked and 'Locked' or 'Unlocked',
                door.coords.x, door.coords.y, door.coords.z))
        else
            invalid = invalid + 1
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
end)

lib.addCommand('cleandoors', { help = 'Clean up invalid doors', restricted = false }, function(source)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { title='Error', description='No permission', type='error' }); return
    end
    if not MySQL then SendActionFeedback(source, false, 'MySQL not available', nil, 'clean'); return end
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
        -- v4 info
        print('^5Auto:^7', nearest.auto and 'Yes' or 'No', '| ^5Door Rate:^7', tostring(nearest.door_rate or 'auto'))
        print('^5Lockpick:^7', nearest.lockpick and 'Yes' or 'No', '| ^5Passcode:^7', nearest.passcode and 'Set' or 'None')
        print('^5Autolock:^7', nearest.autolock or 0, 's | ^5Max Distance:^7', nearest.maxDistance or 2.5, 'm')
        print('^5Hide UI:^7', nearest.hide_ui and 'Yes' or 'No', '| ^5Hold Open:^7', nearest.hold_open and 'Yes' or 'No')
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
    debugPrint(3, '🚀 Starting RDE Doors v4.0.0 initialization...')
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
            Defaults = { type = 'single', locked = true, autolock = 0, heading = 0, maxDistance = 2.5, price = 0,
                         doorRateSwing = 10.0, doorRateAuto = 0.0 },
            DoorTypes = {
                single = { autoDefault = false }, double = { autoDefault = false },
                garage = { autoDefault = true }, sliding = { autoDefault = true }, gate = { autoDefault = true },
            },
            AdminSystem = { acePermission = 'rde.doors.admin', oxGroups = { admin = true, superadmin = true } },
            Performance = { useStateBags = true },
            Lockpick = { items = {'lockpick'}, defaultDifficulty = {'easy','easy','medium'}, breakChanceOnFail = 0.2, breakChanceOnSuccess = 0.05, canPickUnlocked = false },
            Sounds = { lockDefault = {name='door_lock', set='dlc_vinewood_casino_door_sounds'}, unlockDefault = {name='door_unlock', set='dlc_vinewood_casino_door_sounds'} },
        }
        L = { doorNotFound = 'Door not found', accessDenied = 'Access denied', noPermission = 'No permission' }
    end

    debugPrint(3, '🔧 Initializing database (running auto-migration if needed)...')
    if InitializeDatabase() then
        Wait(500)
        if LoadDoors() and LoadDoorGroups() then
            local count, valid, lpCount, autoCount = 0, 0, 0, 0
            for _, door in pairs(doors) do
                count = count + 1
                if door.coords and type(door.coords.x) == 'number' then valid = valid + 1 end
                if door.lockpick then lpCount = lpCount + 1 end
                if door.auto then autoCount = autoCount + 1 end
            end
            debugPrint(3, '✅ Server ready with', count, 'doors (', valid, 'valid,', lpCount, 'lockpickable,', autoCount, 'auto) and', #doorGroups, 'groups')
            print('^2[RDE Doors v4.0.0] ✅ Ready^7 — ' .. count .. ' doors | ' .. lpCount .. ' lockpickable | ' .. autoCount .. ' automatic')
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
    doors = {}; doorGroups = {}; doorStateBags = {}; lastBroadcast = {}
    autolockTimers = {}; pickCooldown = {}
    initialized = false
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
    pickCooldown[source] = nil
end)

debugPrint(3, '✅ Server script loaded successfully')
print('^2[RDE | Doors | Server v4.0.0] 📜 Ready^7')
