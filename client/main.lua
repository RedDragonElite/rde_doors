-- ============================================
-- 🚪 RDE DOORS - CLIENT (ox_core 2025 Next-Level + Full CRUD + Admin/Owner Menus)
-- ============================================
-- Version: 6.2.0 (Full ox_doorlock Integration + CRUD + Admin/Owner Menus + Real-Time Sync)
-- Author: RDE | SerpentsByte
-- ============================================

local Ox, Config, L, json
local loadedDoors = {}
local doorEntities = {}
local doorTargets = {}
local doorGroups = {}
local isSelectingDoor = false
local selectionSphere = nil
local playerLoaded = false
local lastTargetUpdate = 0
local targetUpdateCooldown = 500
local activeTargets = 0
local MAX_ACTIVE_TARGETS = 20
local DEBUG_MODE = true

-- ============================================
-- 🎵 Sound Configuration (Fixed)
-- ============================================
local doorSounds = {
    lock = {name = 'door_lock', set = 'dlc_vinewood_casino_door_sounds'},
    unlock = {name = 'door_unlock', set = 'dlc_vinewood_casino_door_sounds'},
    knock = {name = 'knock_door', set = 'dlc_vinewood_casino_door_sounds'},
    bell = {name = 'apartment_doorbell', set = 'dlc_vinewood_casino_door_sounds'}
}

-- ============================================
-- 📝 UTILITY FUNCTIONS
-- ============================================
local function debugPrint(...)
    if DEBUG_MODE then
        print('[RDE Doors | Client]', ...)
    end
end

local function GetPlayerCharId()
    if LocalPlayer.state.charId then
        return LocalPlayer.state.charId
    end
    if Ox then
        local player = Ox.GetPlayer()
        if player and player.charId then
            return player.charId
        end
    end
    return nil
end

local function WaitForPlayerLoad()
    local attempts = 0
    while attempts < 100 do
        local charId = GetPlayerCharId()
        if charId then
            playerLoaded = true
            debugPrint('Player loaded - CharID:', charId)
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
        title = title,
        description = description,
        type = type,
        icon = type == 'success' and '✅' or (type == 'error' and '❌' or (type == 'warning' and '⚠️' or 'ℹ️')),
        iconAnimation = type == 'success' and 'beat' or nil
    })
end

local function Draw3DText(coords, text)
    if not coords or not Config or not Config.UI then return end
    local onScreen, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoord()
    local distance = #(vector3(coords.x, coords.y, coords.z) - camCoords)
    if distance > (Config.UI.textDistance or 5.0) then return end
    local scale = ((Config.UI.textScale or 0.35) / distance) * 2
    scale = math.max(0.2, math.min(scale, 0.5))
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
    if Config.UI.textShadow then
        SetTextDropShadow()
    end
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function CalculateDoorCenter(doorEntity)
    if not DoesEntityExist(doorEntity) then return nil end
    local doorCoords = GetEntityCoords(doorEntity)
    local model = GetEntityModel(doorEntity)
    local min, max = GetModelDimensions(model)
    if not min or not max then
        return vector3(doorCoords.x, doorCoords.y, doorCoords.z + 1.0)
    end
    local offsetX = (max.x + min.x) / 2.0
    local offsetY = (max.y + min.y) / 2.0
    local offsetZ = (max.z + min.z) / 2.0
    local heading = GetEntityHeading(doorEntity)
    local headingRad = math.rad(heading)
    local rotatedX = offsetX * math.cos(headingRad) - offsetY * math.sin(headingRad)
    local rotatedY = offsetX * math.sin(headingRad) + offsetY * math.cos(headingRad)
    return vector3(
        doorCoords.x + rotatedX,
        doorCoords.y + rotatedY,
        doorCoords.z + offsetZ
    )
end

local function IsValidDoorEntity(entity)
    if not DoesEntityExist(entity) then return false end
    if GetEntityType(entity) ~= 3 then return false end
    local min, max = GetModelDimensions(GetEntityModel(entity))
    if not min or not max then return false end
    local height = math.abs(max.z - min.z)
    local width = math.abs(max.x - min.x)
    local depth = math.abs(max.y - min.y)
    return height > 1.5 and (width < 3.0 or depth < 3.0)
end

local function GetDoorEntity(coords, model)
    if not coords then return 0, nil end
    local coordsVec = type(coords) == 'table' and vector3(coords.x, coords.y, coords.z) or coords
    if model then
        local hash = type(model) == 'string' and GetHashKey(model) or model
        local entity = GetClosestObjectOfType(coordsVec.x, coordsVec.y, coordsVec.z, 5.0, hash, false, false, false)
        if DoesEntityExist(entity) and IsValidDoorEntity(entity) then
            return entity, hash
        end
    end
    local closestEntity, closestHash, closestDist = 0, nil, 999999.0
    for _, entity in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(entity) and IsValidDoorEntity(entity) then
            local entityCoords = GetEntityCoords(entity)
            local dist = #(coordsVec - entityCoords)
            if dist < 5.0 and dist < closestDist then
                closestEntity = entity
                closestHash = GetEntityModel(entity)
                closestDist = dist
            end
        end
    end
    return closestEntity, closestHash
end

local function SetDoorState(doorEntity, locked, doorType)
    if not DoesEntityExist(doorEntity) then return end
    local doorHash = GetEntityModel(doorEntity)
    local doorCoords = GetEntityCoords(doorEntity)
    if locked then
        DoorSystemSetDoorState(doorHash, doorCoords.x, doorCoords.y, doorCoords.z, 1, false, false)
        FreezeEntityPosition(doorEntity, true)
        PlaySoundFromEntity(-1, doorSounds.lock.name, doorEntity, doorSounds.lock.set, false, 0)
    else
        DoorSystemSetDoorState(doorHash, doorCoords.x, doorCoords.y, doorCoords.z, 0, false, false)
        FreezeEntityPosition(doorEntity, false)
        PlaySoundFromEntity(-1, doorSounds.unlock.name, doorEntity, doorSounds.unlock.set, false, 0)
    end
    if Config.Performance.useStateBags then
        Entity(doorEntity).state.rde_door_locked = locked
    end
end

local function RemoveDoorTarget(doorId)
    if not doorTargets[doorId] then return end
    local doorEntity = doorEntities[doorId]
    if doorEntity and DoesEntityExist(doorEntity) then
        if exports.ox_target then
            exports.ox_target:removeLocalEntity(doorEntity)
        end
    end
    doorTargets[doorId] = nil
    activeTargets = math.max(0, activeTargets - 1)
end

local function CanCreateMoreTargets()
    return activeTargets < MAX_ACTIVE_TARGETS
end

local function PlayAnimation(dict, anim, duration, flag)
    lib.requestAnimDict(dict, 5000)
    TaskPlayAnim(cache.ped, dict, anim, 8.0, -8.0, duration, flag or 1, 0, false, false, false)
    RemoveAnimDict(dict)
end

local function PlaySoundAtCoords(coords, soundName, soundSet, range)
    PlaySoundFromCoord(-1, soundName, coords.x, coords.y, coords.z, soundSet, false, range or 10.0, false)
end

local function IsPlayerAdmin()
    local groups = LocalPlayer.state.groups
    if groups and (groups.admin or groups.superadmin) then
        return true
    end
    if Ox then
        local player = Ox.GetPlayer()
        if player then
            local playerGroups = player.getGroups and player.getGroups() or {}
            if playerGroups.admin or playerGroups.superadmin then
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
    return false
end

-- ============================================
-- 🎯 TARGET SYSTEM (mit Door Groups und ox_inventory Support)
-- ============================================
local function CreateDoorTarget(doorId, door)
    if not doorId or not door or not door.coords or not L then return false end
    if doorTargets[doorId] then RemoveDoorTarget(doorId) end
    if not CanCreateMoreTargets() then return false end
    local doorEntity = GetDoorEntity(door.coords, door.model)
    if not DoesEntityExist(doorEntity) then return false end
    SetDoorState(doorEntity, door.locked, door.type)
    doorEntities[doorId] = doorEntity
    local options = {
        {
            name = 'door_toggle_' .. doorId,
            label = door.locked and L.unlock or L.lock,
            icon = door.locked and Config.Icons.unlock or Config.Icons.lock,
            distance = Config.UI.interactionDistance or 2.5,
            onSelect = function()
                TriggerServerEvent('rde_doors:toggleLock', doorId)
            end
        },
        {
            name = 'door_ring_' .. doorId,
            label = L.ringBell,
            icon = Config.Icons.bell,
            distance = Config.UI.interactionDistance or 2.5,
            onSelect = function()
                TriggerServerEvent('rde_doors:ringBell', doorId)
                PlaySoundAtCoords(door.coords, doorSounds.bell.name, doorSounds.bell.set, 10.0)
            end,
            canInteract = function()
                return door.owner_charid ~= nil
            end
        },
        {
            name = 'door_knock_' .. doorId,
            label = L.knock,
            icon = Config.Icons.knock,
            distance = Config.UI.interactionDistance or 2.5,
            onSelect = function()
                PlayAnimation('timetable@jimmy@doorknock@', 'knockdoor_idle', 1500, 48)
                TriggerServerEvent('rde_doors:knock', doorId)
                PlaySoundAtCoords(door.coords, doorSounds.knock.name, doorSounds.knock.set, 10.0)
            end,
            canInteract = function()
                return door.owner_charid ~= nil
            end
        },
        {
            name = 'door_buy_' .. doorId,
            label = (L.buy or 'Buy') .. ' ($' .. (door.price or 0) .. ')',
            icon = Config.Icons.buy,
            distance = Config.UI.interactionDistance or 2.5,
            onSelect = function()
                lib.callback('rde_doors:buyDoor', false, function(success, message)
                    if not success then
                        ShowNotification(L.error, message, 'error')
                    end
                end, doorId)
            end,
            canInteract = function()
                return door.price and door.price > 0 and not door.owner_charid
            end
        }
    }

    -- Owner Menu Option
    if HasAccess(door, cache.playerId) then
        table.insert(options, {
            name = 'door_owner_' .. doorId,
            label = L.manage,
            icon = Config.Icons.manage,
            distance = Config.UI.interactionDistance or 2.5,
            onSelect = function()
                OpenOwnerMenu(doorId)
            end
        })
    end

    -- Admin Menu Option
    if IsPlayerAdmin() then
        table.insert(options, {
            name = 'door_admin_' .. doorId,
            label = 'Admin Menu',
            icon = Config.Icons.admin,
            distance = Config.UI.interactionDistance or 2.5,
            onSelect = function()
                OpenAdminMenu(doorId)
            end
        })
    end

    -- Door Group Option
    if door.group_id then
        table.insert(options, {
            name = 'door_group_' .. doorId,
            label = '📁 ' .. (doorGroups[door.group_id] and doorGroups[door.group_id].name or 'Unknown'),
            icon = Config.Icons.door_group,
            distance = Config.UI.interactionDistance or 2.5,
            onSelect = function()
                OpenDoorGroupMenu(door.group_id)
            end
        })
    end

    -- ox_inventory Item Support
    if door.items and #door.items > 0 then
        for _, item in ipairs(door.items) do
            table.insert(options, {
                name = 'door_use_item_' .. doorId .. '_' .. item,
                label = string.format(L.itemRequired, item),
                icon = '📦',
                distance = Config.UI.interactionDistance or 2.5,
                onSelect = function()
                    lib.callback('rde_doors:useItem', false, function(success, message)
                        if success then
                            ShowNotification(L.success, string.format(L.itemConsumed, item), 'success')
                        else
                            ShowNotification(L.error, message, 'error')
                        end
                    end, doorId, item)
                end,
                canInteract = function()
                    return exports.ox_inventory:GetItemCount(cache.playerId, item) > 0
                end
            })
        end
    end

    -- Teleport Option (Admin Only)
    if IsPlayerAdmin() then
        table.insert(options, {
            name = 'door_teleport_' .. doorId,
            label = L.teleport,
            icon = Config.Icons.map_pin,
            distance = Config.UI.interactionDistance or 2.5,
            onSelect = function()
                local ped = PlayerPedId()
                DoScreenFadeOut(500)
                Wait(500)
                SetEntityCoords(ped, door.coords.x, door.coords.y, door.coords.z, false, false, false, false)
                DoScreenFadeIn(500)
                ShowNotification(L.success, L.teleported, 'success')
            end
        })
    end

    local success = pcall(function()
        if exports.ox_target then
            exports.ox_target:addLocalEntity(doorEntity, options)
        end
    end)
    if success then
        doorTargets[doorId] = true
        activeTargets = activeTargets + 1
        return true
    end
    return false
end

-- ============================================
-- 📋 MENU FUNCTIONS (CRUD + Admin/Owner Menus)
-- ============================================
function OpenOwnerMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    lib.registerContext({
        id = 'door_owner_menu_' .. doorId,
        title = door.name or L.door,
        options = {
            {
                title = L.setPrice,
                description = door.price and door.price > 0 and ('Current: $' .. door.price) or L.notForSale,
                icon = Config.Icons.dollar_sign,
                onSelect = function()
                    local input = lib.inputDialog(L.setPrice, {
                        { type = 'number', label = L.price, default = door.price or 0, min = 0, max = 999999 }
                    })
                    if input then
                        TriggerServerEvent('rde_doors:setPrice', doorId, input[1])
                    end
                end
            },
            {
                title = L.manageAccess,
                description = L.manageAccessDesc,
                icon = Config.Icons.user,
                onSelect = function()
                    OpenAccessMenu(doorId)
                end
            },
            {
                title = L.rename,
                description = 'Current: ' .. (door.name or 'Unnamed'),
                icon = Config.Icons.pen,
                onSelect = function()
                    local input = lib.inputDialog(L.rename, {
                        { type = 'input', label = L.name, default = door.name, required = true, min = 3, max = 50 }
                    })
                    if input then
                        TriggerServerEvent('rde_doors:rename', doorId, input[1])
                    end
                end
            },
            {
                title = door.locked and L.unlock or L.lock,
                description = L.toggleLock,
                icon = door.locked and Config.Icons.lock or Config.Icons.unlock,
                onSelect = function()
                    TriggerServerEvent('rde_doors:toggleLock', doorId)
                end
            },
            {
                title = L.teleport,
                description = L.teleportDesc,
                icon = Config.Icons.map_pin,
                onSelect = function()
                    local ped = PlayerPedId()
                    DoScreenFadeOut(500)
                    Wait(500)
                    SetEntityCoords(ped, door.coords.x, door.coords.y, door.coords.z, false, false, false, false)
                    DoScreenFadeIn(500)
                    ShowNotification(L.success, L.teleported, 'success')
                end
            }
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
            icon = Config.Icons.user_plus,
            onSelect = function()
                local nearbyPlayers = lib.getNearbyPlayers(GetEntityCoords(PlayerPedId()), 10.0, true)
                if #nearbyPlayers == 0 then
                    ShowNotification(L.error, L.noPlayersNearby, 'error')
                    return
                end
                local playerOptions = {}
                for _, player in ipairs(nearbyPlayers) do
                    table.insert(playerOptions, {
                        title = GetPlayerName(player.id) or 'Unknown',
                        description = 'ID: ' .. GetPlayerServerId(player.id),
                        icon = Config.Icons.user,
                        onSelect = function()
                            TriggerServerEvent('rde_doors:manageAccess', doorId, GetPlayerServerId(player.id), true)
                        end
                    })
                end
                lib.registerContext({
                    id = 'add_player_menu_' .. doorId,
                    title = L.selectPlayer,
                    options = playerOptions
                })
                lib.showContext('add_player_menu_' .. doorId)
            end
        }
    }
    if door.access_list and #door.access_list > 0 then
        table.insert(options, {
            title = L.removePlayer,
            description = #door.access_list .. ' ' .. L.playersWithAccess,
            icon = Config.Icons.user_minus,
            onSelect = function()
                local removeOptions = {}
                for _, charId in ipairs(door.access_list) do
                    table.insert(removeOptions, {
                        title = 'CharID: ' .. charId,
                        description = L.revokeAccess,
                        icon = Config.Icons.user_xmark,
                        onSelect = function()
                            TriggerServerEvent('rde_doors:manageAccess', doorId, charId, false)
                        end
                    })
                end
                lib.registerContext({
                    id = 'remove_player_menu_' .. doorId,
                    title = L.removeAccess,
                    options = removeOptions
                })
                lib.showContext('remove_player_menu_' .. doorId)
            end
        })
    end
    lib.registerContext({
        id = 'access_menu_' .. doorId,
        title = L.accessManagement,
        options = options
    })
    lib.showContext('access_menu_' .. doorId)
end

function OpenAdminMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    local typeOptions = {}
    for typeKey, typeData in pairs(Config.DoorTypes or {}) do
        table.insert(typeOptions, { value = typeKey, label = typeData.name })
    end
    lib.registerContext({
        id = 'door_admin_menu_' .. doorId,
        title = 'Admin - ' .. (door.name or L.door),
        options = {
            {
                title = L.editDoor,
                description = L.editDoorDesc,
                icon = Config.Icons.pen_square,
                onSelect = function()
                    local input = lib.inputDialog(L.editDoor, {
                        { type = 'input', label = L.name, default = door.name, required = true },
                        { type = 'number', label = L.price, default = door.price or 0, min = 0, max = 999999 },
                        { type = 'select', label = L.type, options = typeOptions, default = door.type }
                    })
                    if input then
                        TriggerServerEvent('rde_doors:updateDoor', doorId, {
                            name = input[1],
                            price = input[2],
                            type = input[3]
                        })
                    end
                end
            },
            {
                title = L.deleteDoor,
                description = L.deleteDoorDesc,
                icon = Config.Icons.trash,
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = L.deleteDoor,
                        content = (L.deleteConfirm or 'Are you sure?') .. '\n\n' .. (door.name or 'Unnamed'),
                        centered = true,
                        cancel = true
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('rde_doors:deleteDoor', doorId)
                    end
                end
            },
            {
                title = L.teleport,
                description = L.teleportDesc,
                icon = Config.Icons.map_pin,
                onSelect = function()
                    local ped = PlayerPedId()
                    DoScreenFadeOut(500)
                    Wait(500)
                    SetEntityCoords(ped, door.coords.x, door.coords.y, door.coords.z, false, false, false, false)
                    DoScreenFadeIn(500)
                    ShowNotification(L.success, L.teleported, 'success')
                end
            },
            {
                title = 'Door Group Management',
                description = 'Add or remove door from groups',
                icon = Config.Icons.door_group,
                onSelect = function()
                    OpenDoorGroupAdminMenu(doorId)
                end
            },
            {
                title = 'Set Required Items',
                description = 'Manage items required to open this door',
                icon = '📦',
                onSelect = function()
                    OpenDoorItemsMenu(doorId)
                end
            }
        }
    })
    lib.showContext('door_admin_menu_' .. doorId)
end

function OpenDoorGroupMenu(groupId)
    local group = doorGroups[groupId]
    if not group or not L then return end
    lib.registerContext({
        id = 'door_group_menu_' .. groupId,
        title = '📁 ' .. group.name,
        options = {
            {
                title = 'Rename Group',
                description = 'Change the name of this group',
                icon = Config.Icons.pen,
                onSelect = function()
                    local input = lib.inputDialog('Rename Group', {
                        { type = 'input', label = 'Name', default = group.name, required = true, min = 3, max = 50 }
                    })
                    if input then
                        TriggerServerEvent('rde_doors:renameGroup', groupId, input[1])
                    end
                end
            },
            {
                title = 'Delete Group',
                description = 'Permanently delete this group',
                icon = Config.Icons.trash,
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Delete Group',
                        content = 'Are you sure you want to delete this group?\n\n' .. group.name,
                        centered = true,
                        cancel = true
                    })
                    if confirm == 'confirm' then
                        TriggerServerEvent('rde_doors:deleteGroup', groupId)
                    end
                end
            },
            {
                title = 'Manage Group Doors',
                description = 'View and manage doors in this group',
                icon = Config.Icons.door_group,
                onSelect = function()
                    OpenGroupDoorsMenu(groupId)
                end
            }
        }
    })
    lib.showContext('door_group_menu_' .. groupId)
end

function OpenDoorGroupAdminMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    local groupOptions = {}
    for groupId, group in pairs(doorGroups) do
        table.insert(groupOptions, {
            title = '📁 ' .. group.name,
            description = 'Click to add/remove door',
            icon = Config.Icons.door_group,
            onSelect = function()
                local isInGroup = door.group_id == groupId
                if isInGroup then
                    TriggerServerEvent('rde_doors:removeFromGroup', doorId, groupId)
                else
                    TriggerServerEvent('rde_doors:addToGroup', doorId, groupId)
                end
            end
        })
    end
    table.insert(groupOptions, {
        title = 'Create New Group',
        description = 'Create a new door group',
        icon = Config.Icons.plus,
        onSelect = function()
            local input = lib.inputDialog('Create Door Group', {
                { type = 'input', label = 'Name', required = true, min = 3, max = 50 }
            })
            if input then
                TriggerServerEvent('rde_doors:createGroup', input[1])
            end
        end
    })
    lib.registerContext({
        id = 'door_group_admin_menu_' .. doorId,
        title = 'Door Group Management',
        options = groupOptions
    })
    lib.showContext('door_group_admin_menu_' .. doorId)
end

function OpenGroupDoorsMenu(groupId)
    local group = doorGroups[groupId]
    if not group or not L then return end
    local options = {}
    for _, doorId in ipairs(group.doors) do
        local door = loadedDoors[doorId]
        if door then
            table.insert(options, {
                title = (door.locked and '🔒 ' or '🔓 ') .. (door.name or 'Unnamed Door'),
                description = 'ID: ' .. doorId,
                icon = door.locked and Config.Icons.lock or Config.Icons.unlock,
                onSelect = function()
                    OpenAdminMenu(doorId)
                end
            })
        end
    end
    lib.registerContext({
        id = 'group_doors_menu_' .. groupId,
        title = 'Doors in ' .. group.name,
        options = options
    })
    lib.showContext('group_doors_menu_' .. groupId)
end

function OpenDoorItemsMenu(doorId)
    local door = loadedDoors[doorId]
    if not door or not L then return end
    local options = {
        {
            title = 'Add Required Item',
            description = 'Add an item required to open this door',
            icon = '📦',
            onSelect = function()
                local input = lib.inputDialog('Add Required Item', {
                    { type = 'input', label = 'Item Name', required = true }
                })
                if input then
                    TriggerServerEvent('rde_doors:addDoorItem', doorId, input[1])
                end
            end
        }
    }
    if door.items and #door.items > 0 then
        for _, item in ipairs(door.items) do
            table.insert(options, {
                title = item,
                description = 'Click to remove this item',
                icon = '🗑️',
                onSelect = function()
                    TriggerServerEvent('rde_doors:removeDoorItem', doorId, item)
                end
            })
        end
    end
    lib.registerContext({
        id = 'door_items_menu_' .. doorId,
        title = 'Required Items for ' .. (door.name or 'Door'),
        options = options
    })
    lib.showContext('door_items_menu_' .. doorId)
end

function OpenDoorManagerMenu()
    if not L then return end
    local options = {
        {
            title = L.createDoor,
            description = L.createDoorDesc,
            icon = Config.Icons.plus,
            onSelect = function()
                TriggerEvent('rde_doors:startDoorSelection')
            end
        },
        {
            title = L.refreshDoors,
            description = L.refreshDoorsDesc,
            icon = Config.Icons.rotate,
            onSelect = function()
                TriggerServerEvent('rde_doors:requestSync')
                ShowNotification(L.success, L.doorsRefreshed, 'success')
            end
        },
        {
            title = 'Door Group Manager',
            description = 'Manage door groups',
            icon = Config.Icons.door_group,
            onSelect = function()
                OpenDoorGroupManagerMenu()
            end
        }
    }
    local doorCount = 0
    for doorId, door in pairs(loadedDoors) do
        doorCount = doorCount + 1
        local doorType = (Config.DoorTypes and Config.DoorTypes[door.type]) or { name = 'Single Door' }
        table.insert(options, {
            title = (door.locked and '🔒 ' or '🔓 ') .. (door.name or L.door),
            description = doorType.name .. ' | ' .. (door.owner_name or 'No Owner') .. ' | $' .. (door.price or 0),
            icon = door.locked and Config.Icons.lock or Config.Icons.unlock,
            onSelect = function()
                OpenAdminMenu(doorId)
            end
        })
    end
    lib.registerContext({
        id = 'door_manager_menu',
        title = 'Door Manager (' .. doorCount .. ')',
        options = options
    })
    lib.showContext('door_manager_menu')
end

function OpenDoorGroupManagerMenu()
    if not L then return end
    local options = {
        {
            title = 'Create New Group',
            description = 'Create a new door group',
            icon = Config.Icons.plus,
            onSelect = function()
                local input = lib.inputDialog('Create Door Group', {
                    { type = 'input', label = 'Name', required = true, min = 3, max = 50 }
                })
                if input then
                    TriggerServerEvent('rde_doors:createGroup', input[1])
                end
            end
        }
    }
    for groupId, group in pairs(doorGroups) do
        table.insert(options, {
            title = '📁 ' .. group.name,
            description = #group.doors .. ' doors in group',
            icon = Config.Icons.door_group,
            onSelect = function()
                OpenDoorGroupMenu(groupId)
            end
        })
    end
    lib.registerContext({
        id = 'door_group_manager_menu',
        title = 'Door Group Manager (' .. #options - 1 .. ' groups)',
        options = options
    })
    lib.showContext('door_group_manager_menu')
end

-- ============================================
-- 🎯 DOOR SELECTION
-- ============================================
local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

RegisterNetEvent('rde_doors:startDoorSelection', function()
    if isSelectingDoor or not L then return end
    isSelectingDoor = true
    selectionSphere = CreateObject(GetHashKey('prop_tennis_ball'), 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(selectionSphere, 100, false)
    SetEntityCollision(selectionSphere, false, false)
    FreezeEntityPosition(selectionSphere, true)
    ShowNotification(L.selectingDoor, L.confirmSelection, 'inform')
    CreateThread(function()
        while isSelectingDoor do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            local camCoords = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            local direction = RotationToDirection(camRot)
            local dest = camCoords + (direction * 10.0)
            local ray = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, dest.x, dest.y, dest.z, -1, -1, 0)
            local _, hit, endCoords, _, entityHit = GetShapeTestResult(ray)
            if DoesEntityExist(selectionSphere) then
                SetEntityCoords(selectionSphere, endCoords.x, endCoords.y, endCoords.z, false, false, false, false)
            end
            Draw3DText(endCoords, L.confirmSelection)
            if IsDisabledControlJustPressed(0, 24) and hit and DoesEntityExist(entityHit) then
                local doorCoords = GetEntityCoords(entityHit)
                local doorHeading = GetEntityHeading(entityHit)
                local model = GetEntityModel(entityHit)
                if not IsValidDoorEntity(entityHit) then
                    ShowNotification(L.error, L.invalidDoor, 'error')
                else
                    local input = lib.inputDialog(L.createDoor, {
                        { type = 'input', label = L.name, default = L.newDoor, required = true, min = 3, max = 50 },
                        { type = 'number', label = L.price, default = 0, min = 0, max = 999999 }
                    })
                    if input then
                        TriggerServerEvent('rde_doors:createDoor', {
                            name = input[1],
                            model = model,
                            coords = { x = doorCoords.x, y = doorCoords.y, z = doorCoords.z },
                            heading = doorHeading,
                            locked = true,
                            price = input[2]
                        })
                    end
                end
                isSelectingDoor = false
                if DoesEntityExist(selectionSphere) then
                    DeleteEntity(selectionSphere)
                end
            end
            if IsControlJustPressed(0, 25) then
                isSelectingDoor = false
                if DoesEntityExist(selectionSphere) then
                    DeleteEntity(selectionSphere)
                end
                ShowNotification(L.cancelled, L.doorSelectionCancelled, 'inform')
            end
        end
    end)
end)

-- ============================================
-- 📡 NETWORK EVENTS
-- ============================================
RegisterNetEvent('rde_doors:syncDoors', function(serverDoors, serverGroups)
    if not serverDoors then return end
    for doorId in pairs(doorTargets) do
        RemoveDoorTarget(doorId)
    end
    doorTargets = {}
    loadedDoors = {}
    doorEntities = {}
    doorGroups = serverGroups or {}
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
    if not doorId or not door or not Config or not Config.UI then return end
    loadedDoors[doorId] = door
    local playerCoords = GetEntityCoords(PlayerPedId())
    local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
    if dist <= (Config.UI.proximityLoadDistance or 30.0) then
        if doorTargets[doorId] then RemoveDoorTarget(doorId) end
        CreateDoorTarget(doorId, door)
    else
        RemoveDoorTarget(doorId)
    end
end)

RegisterNetEvent('rde_doors:doorDeleted', function(doorId)
    RemoveDoorTarget(doorId)
    loadedDoors[doorId] = nil
    doorEntities[doorId] = nil
end)

RegisterNetEvent('rde_doors:actionFeedback', function(success, message, doorId, action)
    if not L then return end
    if success then
        if action == 'create' then
            ShowNotification(L.success, L.doorCreated, 'success')
        elseif action == 'update' then
            ShowNotification(L.success, L.doorUpdated, 'success')
        elseif action == 'delete' then
            ShowNotification(L.success, L.doorDeleted, 'success')
        elseif action == 'group_create' then
            ShowNotification(L.success, L.doorGroupCreated, 'success')
        elseif action == 'group_delete' then
            ShowNotification(L.success, L.doorGroupDeleted, 'success')
        elseif action == 'add_to_group' then
            ShowNotification(L.success, L.doorAddedToGroup, 'success')
        elseif action == 'remove_from_group' then
            ShowNotification(L.success, L.doorRemovedFromGroup, 'success')
        end
    else
        ShowNotification(L.error, message or (L.saveError or 'Save error'), 'error')
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
        local currentTime = GetGameTimer()
        if currentTime - lastTargetUpdate < targetUpdateCooldown then goto continue end
        lastTargetUpdate = currentTime
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

CreateThread(function()
    while true do
        Wait(Config and Config.Performance and Config.Performance.entityCheckInterval or 5000)
        if not playerLoaded then goto continue end
        for doorId, doorEntity in pairs(doorEntities) do
            if not DoesEntityExist(doorEntity) then
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
        local renderedAny = false
        for doorId, door in pairs(loadedDoors) do
            if door.coords then
                local dist = #(playerCoords - vector3(door.coords.x, door.coords.y, door.coords.z))
                if dist < (Config.UI.textDistance or 5.0) then
                    local doorEntity = doorEntities[doorId]
                    if doorEntity and DoesEntityExist(doorEntity) then
                        local centerPoint = CalculateDoorCenter(doorEntity)
                        if centerPoint then
                            local text = string.format('%s\n%s\n%s',
                                door.name or (L.door or 'Door'),
                                door.locked and ('🔒 ' .. L.locked) or ('🔓 ' .. L.unlocked),
                                door.owner_name or (L.noOwner or 'No Owner')
                            )
                            if door.price and door.price > 0 then
                                text = text .. '\n' .. L.price .. tostring(door.price)
                            end
                            if door.group_id then
                                text = text .. '\n📁 ' .. (doorGroups[door.group_id] and doorGroups[door.group_id].name or 'Unknown')
                            end
                            if door.items and #door.items > 0 then
                                text = text .. '\n📦 ' .. table.concat(door.items, ', ')
                            end
                            Draw3DText(centerPoint, text)
                            renderedAny = true
                        end
                    end
                end
            end
        end
        if not renderedAny then
            Wait(500)
        end
        ::continue::
    end
end)

-- ============================================
-- 🚀 INITIALIZATION
-- ============================================
CreateThread(function()
    json = json or require('json')
    while GetResourceState('ox_core') ~= 'started' do
        Wait(100)
    end
    local success, result = pcall(require, '@ox_core/lib/init')
    if success and result then
        Ox = result
        debugPrint('ox_core loaded successfully')
    else
        debugPrint('ox_core load failed, using fallback')
    end
    success, result = pcall(require, 'shared.config')
    if success and result then
        Config = result
        L = Config.Lang[Config.DefaultLanguage or 'en']
        MAX_ACTIVE_TARGETS = Config.Performance and Config.Performance.maxActiveTargets or 20
        targetUpdateCooldown = Config.UI and Config.UI.targetUpdateCooldown or 500
        DEBUG_MODE = Config.Debug or true
        debugPrint('Config loaded')
    else
        debugPrint('Config load failed, using fallback')
        Config = {
            UI = {
                interactionDistance = 2.5,
                proximityLoadDistance = 30.0,
                proximityUnloadDistance = 35.0,
                proximityCheckInterval = 1000,
                use3DText = true,
                textDistance = 5.0,
                textScale = 0.35,
                textFont = 4,
                textOutline = true,
                textShadow = true
            },
            Performance = {
                entityCheckInterval = 5000,
                maxActiveTargets = 20
            },
            DoorTypes = {
                single = { name = 'Single Door' },
                double = { name = 'Double Door' },
                garage = { name = 'Garage Door' },
                sliding = { name = 'Sliding Door' },
                gate = { name = 'Gate' }
            },
            Lang = {
                ['en'] = {
                    success = 'Success',
                    error = 'Error',
                    warning = 'Warning',
                    info = 'Information',
                    press_to_interact = 'Press [E] to interact',
                    processing = 'Processing...',
                    cancelled = 'Cancelled',
                    completed = 'Completed',
                    noPermission = 'You do not have permission',
                    admin_only = 'Admin privileges required',
                    accessDenied = 'Access denied',
                    not_enough_money = 'Insufficient funds',
                    paid_amount = 'Paid: $%s',
                    received_amount = 'Received: $%s',
                    item_received = 'Received: %s x%s',
                    item_removed = 'Removed: %s x%s',
                    missing_items = 'Missing required items',
                    locked = 'Locked',
                    unlocked = 'Unlocked',
                    doorName = 'Name: ',
                    owner = 'Owner: ',
                    price = 'Price: $',
                    doorNotFound = 'Door not found',
                    doorCreated = 'Door created successfully',
                    doorUpdated = 'Door updated successfully',
                    doorDeleted = 'Door deleted successfully',
                    doorNotForSale = 'This door is not for sale',
                    purchaseSuccess = 'Door purchased successfully',
                    accessUpdated = 'Access list updated',
                    priceUpdated = 'Price updated',
                    doorRenamed = 'Door renamed',
                    selectDoorType = 'Select Door Type',
                    confirmSelection = 'Press [ATTACK/MOUSE1] to confirm selection',
                    manage = 'Manage',
                    setPrice = 'Set Price',
                    manageAccess = 'Manage Access',
                    addPlayer = 'Add Player',
                    removePlayer = 'Remove Player',
                    rename = 'Rename Door',
                    editDoor = 'Edit Door',
                    deleteDoor = 'Delete Door',
                    lock = 'Lock',
                    unlock = 'Unlock',
                    ringBell = 'Ring Bell',
                    knock = 'Knock',
                    buy = 'Buy',
                    teleport = 'Teleport',
                    search = 'Search...',
                    SomeoneRinging = 'Someone is ringing',
                    SomeoneKnocking = 'Someone is knocking',
                    selectingDoor = 'Left Click = Select | Right Click = Cancel',
                    doorSelectionCancelled = 'Door selection cancelled',
                    noDoorFound = 'No door entity found',
                    manageAccessDesc = 'Add or remove players from the access list',
                    teleportDesc = 'Teleport to the door location',
                    notForSale = 'Not for sale',
                    toggleLock = 'Toggle lock status',
                    teleported = 'Teleported successfully',
                    door = 'Door',
                    noOwner = 'No Owner',
                    playersWithAccess = 'players with access',
                    addPlayerDesc = 'Grant access to a nearby player',
                    removeAccess = 'Remove Access',
                    revokeAccess = 'Click to revoke access',
                    selectPlayer = 'Select Player',
                    noPlayersNearby = 'No players nearby',
                    accessManagement = 'Access Management',
                    deleteConfirm = 'Are you sure?',
                    deleteDoorDesc = 'Permanently delete this door',
                    createDoor = 'Create Door',
                    createDoorDesc = 'Select a door in the world',
                    refreshDoors = 'Refresh Doors',
                    refreshDoorsDesc = 'Reload all doors from the database',
                    doorsRefreshed = 'Doors refreshed',
                    name = 'Name',
                    type = 'Type',
                    editDoorDesc = 'Edit door properties',
                    doorCreated = 'Door created',
                    doorUpdated = 'Door updated',
                    doorDeleted = 'Door deleted',
                    newDoor = 'New Door',
                    invalidDoor = 'Invalid door',
                    doorGroupCreated = 'Door group created',
                    doorGroupDeleted = 'Door group deleted',
                    doorAddedToGroup = 'Door added to group',
                    doorRemovedFromGroup = 'Door removed from group',
                    itemRequired = 'Requires: %s',
                    itemConsumed = 'Used: %s',
                },
                ['de'] = {
                    -- Deutsche Übersetzungen (analog zu 'en')
                }
            },
            Icons = {},
            AdminSystem = {
                acePermission = 'rde.doors.admin',
                steamIds = {},
                oxGroups = { ['admin'] = 0, ['superadmin'] = 0, ['management'] = 0 },
                checkOrder = {'ace', 'oxcore', 'steam'}
            },
            Debug = true
        }
        L = Config.Lang[Config.DefaultLanguage or 'en']
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
    for doorId in pairs(doorTargets) do
        RemoveDoorTarget(doorId)
    end
    if selectionSphere and DoesEntityExist(selectionSphere) then
        DeleteEntity(selectionSphere)
    end
    debugPrint('Cleanup complete')
end)

AddEventHandler('ox:playerLoaded', function()
    debugPrint('Player loaded event triggered')
    if not playerLoaded then
        WaitForPlayerLoad()
    end
    Wait(500)
    TriggerServerEvent('rde_doors:requestSync')
end)

AddEventHandler('ox:playerLogout', function()
    debugPrint('Player logout event triggered')
    playerLoaded = false
    for doorId in pairs(doorTargets) do
        RemoveDoorTarget(doorId)
    end
end)

-- ============================================
-- 💬 COMMANDS
-- ============================================
RegisterCommand('createdoor', function()
    if not playerLoaded then
        ShowNotification('Error', 'Please wait for game to fully load', 'error')
        return
    end
    lib.callback('rde_doors:checkAdmin', false, function(isAdmin)
        if isAdmin then
            TriggerEvent('rde_doors:startDoorSelection')
        else
            ShowNotification(L.error, L.noPermission, 'error')
        end
    end)
end, false)

RegisterCommand('doormanager', function()
    if not playerLoaded then
        ShowNotification('Error', 'Please wait for game to fully load', 'error')
        return
    end
    lib.callback('rde_doors:checkAdmin', false, function(isAdmin)
        if isAdmin then
            OpenDoorManagerMenu()
        else
            ShowNotification(L.error, L.noPermission, 'error')
        end
    end)
end, false)

if DEBUG_MODE then
    RegisterCommand('doordebug', function()
        local charId = GetPlayerCharId()
        local groups = LocalPlayer.state.groups
        debugPrint('=== DOOR DEBUG INFO ===')
        debugPrint('Player Loaded:', playerLoaded)
        debugPrint('CharID:', charId)
        debugPrint('Groups:', json and json.encode(groups or {}) or 'N/A')
        local doorCount = 0
        for _ in pairs(loadedDoors) do doorCount = doorCount + 1 end
        debugPrint('Loaded Doors:', doorCount)
        debugPrint('Active Targets:', activeTargets)
        local entityCount = 0
        for _ in pairs(doorEntities) do entityCount = entityCount + 1 end
        debugPrint('Door Entities:', entityCount)
        debugPrint('========================')
        ShowNotification('Debug', 'Check F8 console for details', 'info')
    end, false)
end

debugPrint('Client initialized successfully')
