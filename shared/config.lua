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
        -- v4.0.0 ─────────────────────────────────
        advancedSettings    = '⚙️ Advanced Settings',
        advancedSettingsDesc= 'Lockpick, passcode, autolock, sounds, etc.',
        passcode            = '🔢 Passcode',
        passcodePrompt      = 'Enter Passcode',
        passcodeIncorrect   = '🚫 Incorrect passcode',
        passcodeSet         = '🔢 Passcode updated',
        passcodeCleared     = '🔢 Passcode cleared',
        autolock            = '⏱️ Autolock (seconds)',
        autolockDesc        = '0 = disabled. Door re-locks after X seconds',
        autolockSet         = '⏱️ Autolock interval updated',
        interactDistance    = '📏 Interact Distance (meters)',
        interactDistanceDesc= 'How close player must be to use the door',
        doorRate            = '🌀 Door Rate (speed)',
        doorRateDesc        = '0.0 = instant (sliding) | 10.0 = swing default',
        autoFlag            = '🤖 Automatic Door',
        autoFlagDesc        = 'Sliding/garage/automatic — uses door rate',
        lockpickEnable      = '🔧 Lockpickable',
        lockpickEnableDesc  = 'Can be opened with a lockpick item',
        lockpickStarted     = '🔧 Picking lock...',
        lockpickSuccess     = '🔓 Lock picked successfully',
        lockpickFailed      = '🚫 Lockpick failed',
        lockpickBroke       = '💥 Lockpick broke',
        lockpickNoItem      = '🚫 You need a lockpick',
        lockpickDifficulty  = '🎯 Lockpick Difficulty',
        lockpickDifficultyDesc = 'easy / medium / hard or custom',
        pickLock            = '🔧 Pick Lock',
        hideUi              = '🙈 Hide UI',
        hideUiDesc          = 'Hide 3D text & sprite indicators',
        holdOpen            = '🚪 Hold Open',
        holdOpenDesc        = 'Keep door physically open when unlocked',
        lockSound           = '🔊 Lock Sound',
        unlockSound         = '🔊 Unlock Sound',
        soundReset          = '🔊 Sound reset to default',
        manageGroups        = '🏢 Manage Groups (Grade-based)',
        manageGroupsDesc    = 'Add groups with minimum grade requirement',
        addGroup            = 'Add Group',
        removeGroup         = 'Remove Group',
        groupName           = 'Group Name (e.g. police, ambulance)',
        groupGrade          = 'Minimum Grade (0 = all)',
        groupAdded          = '🏢 Group added',
        groupRemoved        = '🏢 Group removed',
        manageItems         = '📦 Manage Items (with Metadata)',
        manageItemsDesc     = 'Add items with optional metadata requirement',
        addItem             = 'Add Item',
        removeItem          = 'Remove Item',
        itemName            = 'Item Name',
        itemMetadata        = 'Metadata Type (optional)',
        itemRemoveOnUse     = 'Consume on use?',
        itemAdded           = '📦 Item requirement added',
        itemRemoved         = '📦 Item requirement removed',
        autoLockedTimer     = '⏱️ Door auto-locked',
        lockpickActive      = '🔧 Lockpicking — focus on the bar',
        clear               = 'Clear',
        toggle              = 'Toggle',
        on                  = 'On',
        off                 = 'Off',
    },
    ['de'] = {
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
        -- v4.0.0
        advancedSettings    = '⚙️ Erweiterte Einstellungen',
        advancedSettingsDesc= 'Lockpick, Passcode, Autolock, Sounds, etc.',
        passcode            = '🔢 Passcode',
        passcodePrompt      = 'Passcode eingeben',
        passcodeIncorrect   = '🚫 Falscher Passcode',
        passcodeSet         = '🔢 Passcode aktualisiert',
        passcodeCleared     = '🔢 Passcode entfernt',
        autolock            = '⏱️ Autolock (Sekunden)',
        autolockDesc        = '0 = deaktiviert. Tür sperrt sich nach X Sekunden',
        autolockSet         = '⏱️ Autolock-Intervall aktualisiert',
        interactDistance    = '📏 Interaktionsdistanz (Meter)',
        interactDistanceDesc= 'Wie nah der Spieler an der Tür sein muss',
        doorRate            = '🌀 Türgeschwindigkeit',
        doorRateDesc        = '0.0 = sofort (Sliding) | 10.0 = Schwingtür Standard',
        autoFlag            = '🤖 Automatische Tür',
        autoFlagDesc        = 'Sliding/Garage/Automatik — nutzt Türgeschwindigkeit',
        lockpickEnable      = '🔧 Lockpickbar',
        lockpickEnableDesc  = 'Kann mit Lockpick-Item geöffnet werden',
        lockpickStarted     = '🔧 Schloss wird geknackt...',
        lockpickSuccess     = '🔓 Schloss erfolgreich geknackt',
        lockpickFailed      = '🚫 Lockpick fehlgeschlagen',
        lockpickBroke       = '💥 Lockpick zerbrochen',
        lockpickNoItem      = '🚫 Du brauchst einen Lockpick',
        lockpickDifficulty  = '🎯 Lockpick-Schwierigkeit',
        lockpickDifficultyDesc = 'easy / medium / hard oder custom',
        pickLock            = '🔧 Schloss knacken',
        hideUi              = '🙈 UI ausblenden',
        hideUiDesc          = '3D-Text & Indikatoren verstecken',
        holdOpen            = '🚪 Offen halten',
        holdOpenDesc        = 'Tür bleibt physisch offen wenn entsperrt',
        lockSound           = '🔊 Sperr-Sound',
        unlockSound         = '🔊 Entsperr-Sound',
        soundReset          = '🔊 Sound zurückgesetzt',
        manageGroups        = '🏢 Gruppen verwalten (Grade-basiert)',
        manageGroupsDesc    = 'Gruppen mit minimalem Grade hinzufügen',
        addGroup            = 'Gruppe hinzufügen',
        removeGroup         = 'Gruppe entfernen',
        groupName           = 'Gruppenname (z.B. police, ambulance)',
        groupGrade          = 'Min. Grade (0 = alle)',
        groupAdded          = '🏢 Gruppe hinzugefügt',
        groupRemoved        = '🏢 Gruppe entfernt',
        manageItems         = '📦 Items verwalten (mit Metadata)',
        manageItemsDesc     = 'Items mit optionalem Metadata-Filter',
        addItem             = 'Item hinzufügen',
        removeItem          = 'Item entfernen',
        itemName            = 'Item-Name',
        itemMetadata        = 'Metadata-Typ (optional)',
        itemRemoveOnUse     = 'Bei Nutzung verbrauchen?',
        itemAdded           = '📦 Item-Anforderung hinzugefügt',
        itemRemoved         = '📦 Item-Anforderung entfernt',
        autoLockedTimer     = '⏱️ Tür automatisch gesperrt',
        lockpickActive      = '🔧 Schloss knacken — fokussiere auf die Leiste',
        clear               = 'Löschen',
        toggle              = 'Wechseln',
        on                  = 'An',
        off                 = 'Aus',
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
    -- v4.0.0
    advanced = '⚙️',
    passcode = '🔢',
    autolock = '⏱️',
    distance = '📏',
    rate = '🌀',
    auto = '🤖',
    lockpick = '🔧',
    hide_ui = '🙈',
    hold_open = '🚪',
    sound = '🔊',
    item = '📦',
    group = '🏢',
}

-- ============================================
-- 🚪 Door Types (mit Unicode-Icons)
-- ============================================
Config.DoorTypes = {
    ['single'] = {
        name = 'Single Door',
        description = 'Standard single door',
        icon = '🚪',
        color = '#3b82f6',
        autoDefault = false,
    },
    ['double'] = {
        name = 'Double Door',
        description = 'Double doors opening together',
        icon = '🚪🚪',
        color = '#10b981',
        autoDefault = false,
    },
    ['garage'] = {
        name = 'Garage Door',
        description = 'Large garage door (automatic)',
        icon = '🏭',
        color = '#f59e0b',
        autoDefault = true,  -- v4: garage doors are automatic by default
    },
    ['sliding'] = {
        name = 'Sliding Door',
        description = 'Automatic sliding door',
        icon = '↔️',
        color = '#ef4444',
        autoDefault = true,  -- v4: sliding doors are automatic by default
    },
    ['gate'] = {
        name = 'Gate',
        description = 'Large entrance gate (automatic)',
        icon = '🏗️',
        color = '#8b5cf6',
        autoDefault = true,  -- v4: gates are automatic by default
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
    -- v4.0.0
    doorRateSwing = 10.0,   -- Standard swing door rate (slow opening)
    doorRateAuto  = 0.0,    -- Standard automatic door rate (instant slide)
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
-- 🔧 v4.0.0 — Lockpick System
-- ============================================
Config.Lockpick = {
    -- Items, die als Lockpick fungieren (ox_inventory)
    items = { 'lockpick', 'advancedlockpick' },
    -- Default difficulty wenn die Tür keine custom hat
    defaultDifficulty = { 'easy', 'easy', 'medium' },
    -- Chance dass Lockpick bei Fehlversuch zerbricht (1 = 100%, 0.05 = 5%)
    breakChanceOnFail = 0.20,
    -- Chance dass Lockpick bei Erfolg zerbricht (1 = 100%, 0.01 = 1%)
    breakChanceOnSuccess = 0.05,
    -- Animation während des Pickens
    animDict = 'mp_common_heist',
    animName = 'pick_door',
    animDuration = -1,
    -- Kann unlocked doors gelockpicked werden? (für "lock-mode" lockpicks)
    canPickUnlocked = false,
    -- Cooldown zwischen Pick-Versuchen (ms)
    cooldownMs = 1500,
}

-- ============================================
-- 🔊 v4.0.0 — Sound Configuration
-- ============================================
Config.Sounds = {
    -- Standard-Sounds wenn die Tür keine custom hat
    lockDefault = {
        name = 'door_lock',
        set  = 'dlc_vinewood_casino_door_sounds',
    },
    unlockDefault = {
        name = 'door_unlock',
        set  = 'dlc_vinewood_casino_door_sounds',
    },
    -- Alternative Sound-Sets (für Custom Sound dropdown im Edit Menu)
    alternatives = {
        ['heavy_metal'] = {
            lock   = { name = 'shutter_door_close',  set = 'dlc_xm_facility_finale_sounds' },
            unlock = { name = 'shutter_door_open',   set = 'dlc_xm_facility_finale_sounds' },
        },
        ['vault']       = {
            lock   = { name = 'vault_door_close',    set = 'mp_heist_pacific_standard_sounds' },
            unlock = { name = 'vault_door_open',     set = 'mp_heist_pacific_standard_sounds' },
        },
    },
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
