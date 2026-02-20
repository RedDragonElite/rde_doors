Config = {}

-- ============================================
-- 🌐 Language System (English + German)
-- ============================================
Config.DefaultLanguage = 'en'

Config.Lang = {
    ['en'] = {
        -- Status
        success = '✅ Success',
        error = '❌ Error',
        warning = '⚠️ Warning',
        info = 'ℹ️ Information',
        -- Actions
        press_to_interact = 'Press [E] to interact',
        processing = '⏳ Processing...',
        cancelled = '🚫 Cancelled',
        completed = '✓ Completed',
        -- Permissions
        noPermission = '🚫 You do not have permission',
        admin_only = '👑 Admin privileges required',
        accessDenied = '🚫 Access denied',
        -- Economy
        not_enough_money = '💸 Insufficient funds',
        paid_amount = '💵 Paid: $%s',
        received_amount = '💰 Received: $%s',
        -- Items
        item_received = '📦 Received: %s x%s',
        item_removed = '📤 Removed: %s x%s',
        missing_items = '❌ Missing required items',
        -- Door Status
        locked = 'Locked',
        unlocked = 'Unlocked',
        doorName = '🚪 Name: ',
        owner = '👤 Owner: ',
        price = '💰 Price: $',
        -- Operations
        doorNotFound = '🚪 Door not found',
        doorCreated = '🚪 Door created successfully',
        doorUpdated = '🚪 Door updated successfully',
        doorDeleted = '🚪 Door deleted successfully',
        doorNotForSale = '🚪 This door is not for sale',
        purchaseSuccess = '💰 Door purchased successfully',
        accessUpdated = '🔑 Access list updated',
        priceUpdated = '💰 Price updated',
        doorRenamed = '🏷️ Door renamed',
        -- UI
        selectDoorType = 'Select Door Type',
        confirmSelection = 'Press [ATTACK/MOUSE1] to confirm selection',
        manage = '🔧 Manage',
        setPrice = '💰 Set Price',
        manageAccess = '👥 Manage Access',
        addPlayer = '👤 Add Player',
        removePlayer = '👤 Remove Player',
        rename = '✏️ Rename Door',
        editDoor = '🔧 Edit Door',
        deleteDoor = '🗑️ Delete Door',
        lock = '🔒 Lock',
        unlock = '🔓 Unlock',
        ringBell = '🔔 Ring Bell',
        knock = '👊 Knock',
        buy = '💰 Buy',
        teleport = '📍 Teleport',
        search = '🔍 Search...',
        -- Notifications
        SomeoneRinging = '🔔 Someone is ringing',
        SomeoneKnocking = '👊 Someone is knocking',
        selectingDoor = '🎯 Left Click = Select | Right Click = Cancel',
        doorSelectionCancelled = 'Door selection cancelled',
        noDoorFound = 'No door entity found',
        -- Descriptions
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
        -- Deutsche Übersetzungen (analog zu 'en', mit Unicode-Icons)
        success = '✅ Erfolg',
        error = '❌ Fehler',
        warning = '⚠️ Warnung',
        info = 'ℹ️ Information',
        press_to_interact = 'Drücke [E] zum Interagieren',
        processing = '⏳ Wird bearbeitet...',
        cancelled = '🚫 Abgebrochen',
        completed = '✓ Abgeschlossen',
        noPermission = '🚫 Keine Berechtigung',
        admin_only = '👑 Admin-Rechte erforderlich',
        accessDenied = '🚫 Zugriff verweigert',
        not_enough_money = '💸 Nicht genug Geld',
        paid_amount = '💵 Bezahlt: $%s',
        received_amount = '💰 Erhalten: $%s',
        item_received = '📦 Erhalten: %s x%s',
        item_removed = '📤 Entfernt: %s x%s',
        missing_items = '❌ Fehlende Items',
        locked = '🔒 Gesperrt',
        unlocked = '🔓 Entsperrt',
        doorName = '🚪 Name: ',
        owner = '👤 Besitzer: ',
        price = '💰 Preis: $',
        doorNotFound = '🚪 Tür nicht gefunden',
        doorCreated = '🚪 Tür erfolgreich erstellt',
        doorUpdated = '🚪 Tür erfolgreich aktualisiert',
        doorDeleted = '🚪 Tür erfolgreich gelöscht',
        doorNotForSale = '🚪 Tür nicht zum Verkauf',
        purchaseSuccess = '💰 Tür erfolgreich gekauft',
        accessUpdated = '🔑 Zugriffsliste aktualisiert',
        priceUpdated = '💰 Preis aktualisiert',
        doorRenamed = '🏷️ Tür umbenannt',
        selectDoorType = 'Türtyp auswählen',
        confirmSelection = 'Drücke [ATTACK/MOUSE1] um die Auswahl zu bestätigen',
        manage = '🔧 Verwalten',
        setPrice = '💰 Preis festlegen',
        manageAccess = '👥 Zugriff verwalten',
        addPlayer = '👤 Spieler hinzufügen',
        removePlayer = '👤 Spieler entfernen',
        rename = '✏️ Umbenennen',
        editDoor = '🔧 Tür bearbeiten',
        deleteDoor = '🗑️ Tür löschen',
        lock = '🔒 Sperren',
        unlock = '🔓 Entsperren',
        ringBell = '🔔 Klingeln',
        knock = '👊 Klopfen',
        buy = '💰 Kaufen',
        teleport = '📍 Teleportieren',
        search = '🔍 Suche...',
        SomeoneRinging = '🔔 Jemand klingelt',
        SomeoneKnocking = '👊 Jemand klopft',
        selectingDoor = '🎯 Linksklick = Auswählen | Rechtsklick = Abbrechen',
        doorSelectionCancelled = 'Auswahl abgebrochen',
        noDoorFound = 'Keine Tür gefunden',
        -- Descriptions (analog zu 'en')
        manageAccessDesc = 'Spieler zur Zugriffsliste hinzufügen oder entfernen',
        teleportDesc = 'Zur Tür teleportieren',
        notForSale = 'Nicht zum Verkauf',
        toggleLock = 'Sperrstatus ändern',
        teleported = 'Erfolgreich teleportiert',
        door = 'Tür',
        noOwner = 'Kein Besitzer',
        playersWithAccess = 'Spieler mit Zugriff',
        addPlayerDesc = 'Zugriff für nahen Spieler gewähren',
        removeAccess = 'Zugriff entfernen',
        revokeAccess = 'Klicken zum Entziehen',
        selectPlayer = 'Spieler auswählen',
        noPlayersNearby = 'Keine Spieler in der Nähe',
        accessManagement = 'Zugriffsverwaltung',
        deleteConfirm = 'Bist du sicher?',
        deleteDoorDesc = 'Tür endgültig löschen',
        createDoor = 'Tür erstellen',
        createDoorDesc = 'Tür in der Welt auswählen',
        refreshDoors = 'Türen aktualisieren',
        refreshDoorsDesc = 'Alle Türen aus der Datenbank neu laden',
        doorsRefreshed = 'Türen aktualisiert',
        name = 'Name',
        type = 'Typ',
        editDoorDesc = 'Tür-Eigenschaften bearbeiten',
        doorCreated = 'Tür erstellt',
        doorUpdated = 'Tür aktualisiert',
        doorDeleted = 'Tür gelöscht',
        newDoor = 'Neue Tür',
        invalidDoor = 'Ungültige Tür',
        doorGroupCreated = 'Türgruppe erstellt',
        doorGroupDeleted = 'Türgruppe gelöscht',
        doorAddedToGroup = 'Tür zur Gruppe hinzugefügt',
        doorRemovedFromGroup = 'Tür aus Gruppe entfernt',
        itemRequired = 'Benötigt: %s',
        itemConsumed = 'Verwendet: %s',
    }
}

-- ============================================
-- 🎨 Icons (Unicode/Markdown-kompatibel)
-- ============================================
Config.Icons = {
    lock = '🔒',
    unlock = '🔓',
    bell = '🔔',
    knock = '👊',
    buy = '💰',
    manage = '🔧',
    admin = '👑',
    user = '👤',
    user_plus = '👤➕',
    user_minus = '👤➖',
    user_xmark = '👤❌',
    dollar_sign = '💲',
    pen = '✏️',
    pen_square = '✏️',
    trash = '🗑️',
    map_pin = '📍',
    plus = '➕',
    rotate = '🔄',
    door_closed = '🚪',
    door_open = '🚪',
    warehouse = '🏭',
    arrows_left_right = '↔️',
    archway = '🏗️',
    check = '✅',
    x = '❌',
    info = 'ℹ️',
    warning = '⚠️',
    error = '❌',
    door_group = '📁',
}

-- ============================================
-- 🚪 Door Types (mit Unicode-Icons)
-- ============================================
Config.DoorTypes = {
    ['single'] = {
        name = 'Single Door',
        description = 'Standard single door',
        icon = '🚪',
        color = '#3b82f6'
    },
    ['double'] = {
        name = 'Double Door',
        description = 'Double doors opening together',
        icon = '🚪🚪',
        color = '#10b981'
    },
    ['garage'] = {
        name = 'Garage Door',
        description = 'Large garage door',
        icon = '🏭',
        color = '#f59e0b'
    },
    ['sliding'] = {
        name = 'Sliding Door',
        description = 'Automatic sliding door',
        icon = '↔️',
        color = '#ef4444'
    },
    ['gate'] = {
        name = 'Gate',
        description = 'Large entrance gate',
        icon = '🏗️',
        color = '#8b5cf6'
    }
}

-- ============================================
-- ⚙️ UI Configuration
-- ============================================
Config.UI = {
    use3DText = true,
    textScale = 0.35,
    textDistance = 5.0,
    interactionDistance = 2.5,
    proximityLoadDistance = 30.0,
    proximityUnloadDistance = 35.0,
    proximityCheckInterval = 1000,
    textFont = 4,
    textColor = {r = 255, g = 255, b = 255, a = 255},
    textOutline = true,
    textShadow = true,
    targetUpdateCooldown = 500,
}

-- ============================================
-- ⚡ Performance Settings
-- ============================================
Config.Performance = {
    useStateBags = true,
    stateBagUpdateDelay = 50,
    doorLoadBatchSize = 10,
    doorVerificationInterval = 5000,
    entityCheckInterval = 2000,
    cleanupInterval = 30000,
    maxEntityDistance = 50.0,
    maxActiveTargets = 20,
}

-- ============================================
-- 🔧 Default Values
-- ============================================
Config.Defaults = {
    locked = true,
    autolock = 0,
    maxDistance = 2.5,
    heading = 0,
    price = 0,
    type = 'single',
}

-- ============================================
-- 🔍 Door Detection
-- ============================================
Config.DoorDetection = {
    maxDistance = 5.0,
    raycastDistance = 15.0,
    raycastFlags = -1,
    modelKeywords = {
        'door', 'gate', 'garage', 'barrier', 'shutter',
        'tür', 'tor', 'garagentor', 'schranke', 'rolltor'
    },
}

-- ============================================
-- 🛡️ Admin System
-- ============================================
Config.AdminSystem = {
    acePermission = 'rde.doors.admin',
    steamIds = {
        -- Beispiel: 'steam:110000101605859', -- SerpentsByte
    },
    oxGroups = {
        ['admin'] = 0,
        ['superadmin'] = 0,
        ['management'] = 0,
    },
    checkOrder = {'ace', 'oxcore', 'steam'}
}

-- ============================================
-- 🐛 Debug Settings
-- ============================================
Config.Debug = true
Config.DebugLevel = {
    ERROR = 1,
    WARNING = 2,
    INFO = 3,
    VERBOSE = 4
}
Config.CurrentDebugLevel = Config.DebugLevel.INFO

-- ============================================
-- 📊 StateBag Keys
-- ============================================
Config.StateBagKeys = {
    doorData = 'rde_door_data',
    doorLocked = 'rde_door_locked',
    doorOwner = 'rde_door_owner',
}

-- ============================================
-- 🎯 Helper Functions
-- ============================================
function GetLanguageString(key)
    local lang = Config.Lang[Config.DefaultLanguage]
    return lang[key] or key
end

return Config