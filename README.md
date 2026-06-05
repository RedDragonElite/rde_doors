# 🚪 RDE Doors — Next-Level FiveM Door System

[![Version](https://img.shields.io/badge/version-4.0.0-red?style=for-the-badge&logo=github)](https://github.com/RedDragonElite/rde_doors)
[![Status](https://img.shields.io/badge/status-STABLE-brightgreen?style=for-the-badge)](https://github.com/RedDragonElite/rde_doors)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)](https://github.com/RedDragonElite/BFS-License)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=for-the-badge)](https://fivem.net)
[![ox_core](https://img.shields.io/badge/ox__core-Required-blue?style=for-the-badge)](https://github.com/communityox/ox_core)
[![Free](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)](https://github.com/RedDragonElite/rde_doors)

**Production-grade, fully database-backed door system for FiveM.**  
Built on ox_core · ox_inventory · ox_lib · ox_target · Nostr logging · Triple admin verification

*Built by [Red Dragon Elite](https://rd-elite.com) | SerpentsByte · v4.0.0*

---

## 📖 Table of Contents

- [Why RDE Doors?](#-why-rde-doors)
- [Features](#-features)
- [Dependencies](#-dependencies)
- [Installation](#-installation)
- [Configuration](#%EF%B8%8F-configuration)
- [Exports & Developer API](#-exports--developer-api)
- [Admin Commands](#-admin-commands)
- [Nostr Logging](#-nostr-logging-integration)
- [Database Schema](#-database-schema)
- [Troubleshooting](#-troubleshooting)
- [License](#-license)

---

## 🔥 Why RDE Doors?

Most door scripts are static config files. You restart the server, you lose runtime changes. RDE Doors is different:

| Feature | Config-based scripts | RDE Doors v3 | RDE Doors v4 |
| --- | :---: | :---: | :---: |
| Runtime door creation | ❌ | ✅ | ✅ |
| Persistent ownership | ❌ | ✅ Database-backed | ✅ |
| Per-player access lists | ❌ | ✅ | ✅ |
| Item-based access | ❌ | ✅ ox_inventory | ✅ |
| Item access with metadata | ❌ | ❌ | ✅ **v4** |
| Group access with grade requirement | ❌ | ❌ | ✅ **v4** |
| Door groups | ❌ | ✅ | ✅ |
| Decentralized logging | ❌ | ✅ Nostr | ✅ |
| Admin triple verification | ❌ | ✅ ACE + ox_core + groups | ✅ |
| Autolock timers | ❌ | ✅ | ✅ |
| Bell & knock system | ❌ | ✅ | ✅ |
| Price / buyable doors | ❌ | ✅ | ✅ |
| Double doors | ❌ | ✅ | ✅ |
| Sliding / automatic doors | ❌ | ❌ | ✅ **v4** |
| Garage doors | ❌ | ❌ | ✅ **v4** |
| Gate type | ❌ | ❌ | ✅ **v4** |
| Lockpick system (skill check) | ❌ | ❌ | ✅ **v4** |
| Passcode unlock | ❌ | ❌ | ✅ **v4** |
| Per-door custom sounds | ❌ | ❌ | ✅ **v4** |
| Hide UI per door | ❌ | ❌ | ✅ **v4** |
| Hold open when unlocked | ❌ | ❌ | ✅ **v4** |
| Per-door interact distance | ❌ | ❌ | ✅ **v4** |
| Auto-migration (zero downtime) | ❌ | ❌ | ✅ **v4** |

---

## 🎯 Features

### 🚪 Door Types
- **Single** — Standard single door
- **Double** — Two entities that open and lock together, perfectly synchronized
- **Sliding** — Automatic sliding door (zero door-rate, instant open)
- **Garage** — Large garage door, automatic by default
- **Gate** — Large entrance gate, automatic by default

### 🔒 Core Door System
- **Full CRUD** — Create, update, delete doors at runtime via ox_target or admin commands
- **Database persistence** — All doors survive server restarts (oxmysql)
- **StateBag sync** — Real-time door state broadcast to all players
- **Coordinate deduplication** — Prevents overlapping doors at the same position
- **Server-side validation** — All input validated on the server; client is never trusted

### 👤 Ownership & Access Control (8-layer check in order)
1. **Admin** — Triple-verified (ACE permission + ox_core groups + Steam ID fallback)
2. **Owner** — The character who created or purchased the door
3. **Access list** — Per-character allowlist (granted by owner or admin)
4. **Legacy auth array** — Group name only, grade 0 (backward compatible)
5. **groups_data** — Group name + minimum grade requirement (v4)
6. **items_data** — Item name + optional metadata + consume-on-use flag (v4)
7. **Legacy items array** — Simple item check, no metadata (backward compatible)
8. **Passcode** — Anyone with the correct code can toggle (v4)

### 🔧 Lockpick System (v4)
- Configurable lockpick items (`lockpick`, `advancedlockpick`, or custom)
- Per-door difficulty: `easy`, `medium`, `hard` — or fully custom as JSON array
- ox_lib skill check mini-game with configurable keys
- Item break chance on both success and failure (configurable %)
- Server-side verification — client skillcheck result is still validated server-side
- Cooldown between pick attempts (anti-spam)

### 🔢 Passcode System (v4)
- Set a numeric or text passcode per door via admin menu
- Passcode is **never sent to the client** — only a `has_passcode` boolean is synced
- Players without group/item/owner access get prompted for the code when interacting

### ⏱️ Autolock (v4 — improved)
- Configurable per-door autolock timer (seconds)
- Cancel-safe: manually re-locking the door cancels the pending autolock
- Nostr-logged when autolock fires

### 🔔 Bell & Knock
- Ring doorbell → owner gets ox_lib notification with caller name and door name
- Knock → same notification system with knock animation

### 📊 Door Groups
- Create named groups containing multiple doors
- Lock/unlock an entire group at once
- Full group CRUD with persistent storage
- Group membership shown in 3D text overlay

### 🎵 Custom Sounds (v4)
- Per-door custom lock/unlock sounds (GTA audio set + sound name)
- Falls back to configured defaults when no custom sound is set
- Default: Vinewood Casino door sounds

### 🔊 Hold Open (v4)
- Per-door flag: keep door physically open when unlocked using `DoorSystemSetHoldOpen`
- Automatically closes (locks) when door is toggled back to locked state

### 🙈 Hide UI (v4)
- Per-door flag to suppress 3D text and ox_target indicators
- Useful for ambient world doors that should lock silently

### 🎯 ox_target Integration
All door interactions are handled exclusively through **ox_target** — no key prompts, no E-button, no NUI input required. Walking up to a door shows the ox_target crosshair with contextual options based on your access level:

| Player type | Options shown |
| --- | --- |
| Any player | Lock/Unlock (if access), Ring Bell, Knock, Buy (if for sale) |
| Player with lockpick item | Pick Lock (if door is lockpick-enabled) |
| Owner | + Manage (set price, access list, rename, teleport) |
| Admin | + Admin Menu (full edit, advanced settings, group management, delete) |

### 🛡️ Admin Tools
- `/createdoor` — Select a door entity in the world and register it (single or double)
- `/doormanager` — Open full door manager menu (lists all doors with lock state)
- `/doorslist` — Print all doors to server console with validity status and v4 flags
- `/resyncdoors` — Force-reload all doors from DB and resync to every player
- `/cleandoors` — Scan and remove corrupted/invalid door entries from the DB
- `/doorinfo` — Get detailed info on the nearest door (within 10m) in server console
- `/doordebug` (debug mode) — Print client-side door stats to F8 console

### 📡 Nostr Logging
Every significant door event is broadcast to the Nostr network via `rde_nostr_log` — decentralized, permanent, uncensorable. If `rde_nostr_log` is not running, logging is **silently skipped** — no errors, no crashes.

---

## 📦 Dependencies

| Resource | Required | Notes |
| --- | :---: | --- |
| [oxmysql](https://github.com/communityox/oxmysql) | ✅ | Database layer |
| [ox_core](https://github.com/communityox/ox_core) | ✅ | Player/character framework (v3+) |
| [ox_lib](https://github.com/communityox/ox_lib) | ✅ | Callbacks, commands, skill checks, notifications |
| [ox_target](https://github.com/communityox/ox_target) | ✅ | Door interaction (all interactions go through ox_target) |
| [ox_inventory](https://github.com/communityox/ox_inventory) | ✅ | Item-based access, lockpick items, money transactions |
| [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) | ⚠️ Optional | Decentralized logging — highly recommended |

---

## 🚀 Installation

### 1. Clone the repository

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_doors.git
```

### 2. Add to `server.cfg`

```
ensure oxmysql
ensure ox_core
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure rde_nostr_log   # optional but recommended
ensure rde_doors
```

> **Order matters.** `rde_doors` must start **after** all its dependencies.

### 3. Start / Restart

```
start rde_doors
```

The database tables are **created and migrated automatically** on first start. No manual SQL import needed.

### 4. Set ACE Permissions

```
# server.cfg
add_ace group.admin rde.doors.admin allow
add_principal identifier.steam:YOURSTEAMHEX group.admin
```

### 5. Verify

Check your server console — you should see:

```
[RDE Doors v4.0.0] ✅ Ready — X doors | X lockpickable | X automatic
[RDE | Doors | Server v4.0.0] 📜 Ready
```

---

## ⚙️ Configuration

Edit `shared/config.lua`:

```lua
Config.DefaultLanguage = 'en'   -- 'en' or 'de'
Config.Debug = true              -- verbose server console logging

Config.Defaults = {
    locked      = true,
    autolock    = 0,          -- 0 = disabled, seconds otherwise
    maxDistance = 2.5,        -- ox_target interaction radius (meters)
    heading     = 0,
    price       = 0,          -- 0 = not for sale
    type        = 'single',
    doorRateSwing = 10.0,     -- swing door speed (higher = slower)
    doorRateAuto  = 0.0,      -- automatic/sliding door speed (0 = instant)
}

Config.AdminSystem = {
    acePermission = 'rde.doors.admin',
    oxGroups = {
        ['admin']      = 0,
        ['superadmin'] = 0,
        ['management'] = 0,
    },
}

Config.Lockpick = {
    items             = { 'lockpick', 'advancedlockpick' },
    defaultDifficulty = { 'easy', 'easy', 'medium' },
    breakChanceOnFail    = 0.20,   -- 20% break on failed pick
    breakChanceOnSuccess = 0.05,   -- 5% break on successful pick
    animDict   = 'mp_common_heist',
    animName   = 'pick_door',
    canPickUnlocked = false,
    cooldownMs = 1500,
}

Config.Sounds = {
    lockDefault   = { name = 'door_lock',   set = 'dlc_vinewood_casino_door_sounds' },
    unlockDefault = { name = 'door_unlock', set = 'dlc_vinewood_casino_door_sounds' },
}
```

### Door Types & Automatic Behavior

Garage, sliding, and gate door types default to `auto = true` (instant open/close). You can override this per door in the admin menu.

```lua
Config.DoorTypes = {
    ['single']  = { name = 'Single Door',  autoDefault = false },
    ['double']  = { name = 'Double Door',  autoDefault = false },
    ['garage']  = { name = 'Garage Door',  autoDefault = true  },
    ['sliding'] = { name = 'Sliding Door', autoDefault = true  },
    ['gate']    = { name = 'Gate',         autoDefault = true  },
}
```

---

## 🔧 Exports & Developer API

### Server-side Events

#### Create a Door

```lua
TriggerEvent('rde_doors:createDoor', {
    name        = 'Police HQ Front Door',
    coords      = { x = 462.12, y = -993.47, z = 27.79 },
    model       = 'prop_door_01',
    type        = 'single',   -- single | double | sliding | garage | gate
    locked      = true,
    auth        = { 'police' },        -- legacy: group name only
    groups_data = { police = 2 },      -- v4: group + minimum grade
    items       = { 'keycard_pd' },    -- legacy: item name only
    items_data  = { { name = 'keycard_pd', metadata = 'hq', remove = false } }, -- v4
    autolock    = 30,
    heading     = 0.0,
    maxDistance = 2.5,
    price       = 0,
    auto        = false,
    door_rate   = nil,     -- nil = derived from auto flag
    lockpick    = false,
    passcode    = nil,
    hide_ui     = false,
    hold_open   = false,
})
```

#### Toggle Lock

```lua
TriggerServerEvent('rde_doors:toggleLock', doorId)
-- With passcode:
TriggerServerEvent('rde_doors:toggleLock', doorId, '1337')
```

#### Update a Door

```lua
TriggerServerEvent('rde_doors:updateDoor', doorId, {
    name        = 'New Name',
    price       = 5000,
    auth        = { 'police', 'ambulance' },
    -- v4 fields (admin only):
    autolock    = 60,
    lockpick    = true,
    passcode    = '9999',
    auto        = true,
    door_rate   = 0.0,
    hold_open   = true,
    hide_ui     = false,
    maxDistance = 3.0,
    lock_sound  = 'door_lock',
    unlock_sound = 'door_unlock',
    groups_data = { police = 2, sheriff = 3 },
    items_data  = { { name = 'badge', metadata = 'police_hq', remove = false } },
})
```

#### Delete a Door

```lua
TriggerServerEvent('rde_doors:deleteDoor', doorId)
```

#### Manage Access List

```lua
-- Grant access to a player (server ID)
TriggerServerEvent('rde_doors:manageAccess', doorId, targetServerId, true)

-- Revoke access by charId
TriggerServerEvent('rde_doors:manageAccess', doorId, charId, false)
```

#### Group + Grade Access (v4)

```lua
-- Add group with min grade
TriggerServerEvent('rde_doors:manageGroup', doorId, 'police', 2, true)

-- Remove group
TriggerServerEvent('rde_doors:manageGroup', doorId, 'police', 0, false)
```

#### Item + Metadata Access (v4)

```lua
-- Add item with metadata
TriggerServerEvent('rde_doors:manageItemData', doorId, 'badge', 'police_hq', false, true)
-- { itemName, metadata, removeOnUse, grantAccess }

-- Remove item
TriggerServerEvent('rde_doors:manageItemData', doorId, 'badge', 'police_hq', false, false)
```

#### Door Groups

```lua
TriggerServerEvent('rde_doors:createGroup', 'Police HQ')
TriggerServerEvent('rde_doors:addToGroup', doorId, groupId)
TriggerServerEvent('rde_doors:removeFromGroup', doorId, groupId)
TriggerServerEvent('rde_doors:renameGroup', groupId, 'New Group Name')
TriggerServerEvent('rde_doors:deleteGroup', groupId)
```

### Server-side Exports

```lua
-- Get a door object by ID
local door = exports.rde_doors:getDoor(doorId)

-- Get a door by name
local door = exports.rde_doors:getDoorFromName('Police HQ Front Door')

-- Get all doors (safe client representation, passcode excluded)
local doors = exports.rde_doors:getAllDoors()

-- Set door state programmatically (bypasses access checks)
exports.rde_doors:setDoorState(doorId, true)   -- true = locked
exports.rde_doors:setDoorState(doorId, false, 'my_script')  -- with reason

-- Edit door data programmatically (bypasses access checks)
exports.rde_doors:editDoor(doorId, { name = 'New Name', lockpick = true })
```

### External Event Hook

```lua
-- Listen for any lock state change (fired from server)
AddEventHandler('rde_doors:stateChanged', function(source, doorId, locked, reason)
    -- source: player source or nil if autolock
    -- reason: 'owner', 'access_list', 'group_grade', 'item_meta:badge', 'passcode', 'lockpick:lockpick', 'autolock', 'export'
    print('Door', doorId, 'is now', locked and 'locked' or 'unlocked', 'by', reason)
end)
```

### Callbacks (ox_lib)

```lua
-- Check if local player is admin
lib.callback('rde_doors:checkAdmin', false, function(isAdmin)
    print('Is admin:', isAdmin)
end)

-- Check if local player has access to a door
lib.callback('rde_doors:checkAccess', false, function(hasAccess)
    print('Has access:', hasAccess)
end, doorId)

-- Buy a door (deducts money item from ox_inventory)
lib.callback('rde_doors:buyDoor', false, function(success, message)
    if success then print('Purchased!') end
end, doorId)

-- Verify passcode (returns bool, does NOT toggle door state)
lib.callback('rde_doors:verifyPasscode', false, function(correct)
    print('Passcode correct:', correct)
end, doorId, '1337')
```

### Client Events (listening)

```lua
-- Fired when all doors are synced to this client
AddEventHandler('rde_doors:syncDoors', function(doorArray, doorGroups)
end)

-- Fired when a single door state changes
AddEventHandler('rde_doors:doorUpdate', function(doorId, doorData)
end)

-- Fired when a door is deleted
AddEventHandler('rde_doors:doorDeleted', function(doorId)
end)

-- Fired when a door group changes
AddEventHandler('rde_doors:doorGroupUpdate', function(groupId, groupData)
end)

-- Fired when a group is deleted
AddEventHandler('rde_doors:doorGroupDeleted', function(groupId)
end)

-- Feedback after any action (success/fail notification)
AddEventHandler('rde_doors:actionFeedback', function(success, message, doorId, action)
end)

-- Lockpick result (success/fail + broke)
AddEventHandler('rde_doors:lockpickResult', function(success, doorId, broken)
end)
```

### Client Exports (ox_doorlock-compatible)

```lua
-- Get closest door object
local door = exports.rde_doors:getClosestDoor()

-- Toggle closest door (if player has access)
exports.rde_doors:useClosestDoor()

-- Lockpick closest lockpickable door
exports.rde_doors:pickClosestDoor()
```

---

## 📋 Admin Commands

All in-game commands require the `rde.doors.admin` ACE permission or an admin ox_core group.

| Command | Where | Description |
| --- | --- | --- |
| `/createdoor` | In-game | Click a door entity in the world to register it (single or double) |
| `/doormanager` | In-game | Open full door manager UI (all doors listed with lock state) |
| `/doorslist` | Console / In-game | Print all doors to server console with validity and v4 flags |
| `/resyncdoors` | Console / In-game | Reload all doors from DB and push to every connected player |
| `/cleandoors` | Console / In-game | Remove corrupted/invalid door records from the database |
| `/doorinfo` | In-game | Print detailed info about the closest door (≤ 10m) to server console |
| `/doordebug` | In-game | F8 debug dump — loaded door count, double door count, active targets |

---

## 📡 Nostr Logging Integration

RDE Doors integrates natively with [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) — the world's first decentralized FiveM logging system.

If `rde_nostr_log` is not running, logging is **silently skipped** — no errors, no crashes.

### Events Logged

| Event | Message |
| --- | --- |
| Door locked/unlocked | `🔒 Door Locked/Unlocked \| Name \| By: Player \| Auth: reason` |
| Door created | `✅ Door created: Name (type) \| By: Player` |
| Door updated | `🔄 Door updated: Name \| By: Player` |
| Door deleted | `🗑️ Door deleted: ID \| By: Player` |
| Door purchased | `💳 Door purchased: Name \| By: Player (CharID: X)` |
| Lockpick success | `🔧 Lockpick: Name \| By: Player \| Item: lockpick` |
| Lockpick broke | `💥 Lockpick broke: Player \| Item: lockpick` |
| Autolock fired | `⏱️ Autolock: Door Name` |
| DB migration | `🔧 DB Migration: N column(s) added` |

### Quick Setup

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_nostr_log.git
cd rde_nostr_log
yarn install
```

Ensure before `rde_doors` in `server.cfg`:

```
ensure rde_nostr_log
```

---

## 🗄️ Database Schema

Tables are **created and migrated automatically**. The `door_sql.sql` file is included for reference only — you do not need to run it manually.

### Auto-Migration History

| Version | Columns Added |
| --- | --- |
| v2.x → v3.0.0 | `double_door_data` |
| v3.0.0 → v4.0.0 | `passcode`, `auto`, `door_rate`, `lockpick`, `lockpick_difficulty`, `hide_ui`, `hold_open`, `lock_sound`, `unlock_sound`, `groups_data`, `items_data` |

**Zero data loss guaranteed.** Downgrading from v4 to v3 is safe — v3 ignores the new columns.

### `rde_owned_doors`

| Column | Type | Description |
| --- | --- | --- |
| `id` | VARCHAR(50) | Unique door ID (auto-generated) |
| `type` | VARCHAR(20) | `single`, `double`, `sliding`, `garage`, `gate` |
| `name` | VARCHAR(100) | Display name |
| `coords` | LONGTEXT | JSON `{x, y, z}` — midpoint for double doors |
| `model` | VARCHAR(100) | Model name string (empty for double doors) |
| `model_hash` | VARCHAR(50) | Integer hash from `GetEntityModel()` |
| `locked` | TINYINT(1) | 1 = locked |
| `auth` | LONGTEXT | JSON array of group names (legacy) |
| `autolock` | INT | Seconds until relock (0 = off) |
| `items` | LONGTEXT | JSON array of item names (legacy) |
| `heading` | FLOAT | Door heading |
| `maxDistance` | FLOAT | ox_target interaction radius |
| `owner_charid` | VARCHAR(50) | Owning character ID |
| `owner_name` | VARCHAR(100) | Owning character name |
| `price` | INT | Purchase price (0 = not for sale) |
| `access_list` | LONGTEXT | JSON array of charIds with access |
| `group_id` | VARCHAR(50) | Door group membership |
| `double_door_data` | LONGTEXT | JSON `{door_a, door_b}` with model + coords + heading |
| `passcode` | VARCHAR(100) | v4: unlock passcode (never sent to client) |
| `auto` | TINYINT(1) | v4: 1 = automatic/sliding mode |
| `door_rate` | FLOAT | v4: movement speed (NULL = derived from auto flag) |
| `lockpick` | TINYINT(1) | v4: 1 = lockpickable |
| `lockpick_difficulty` | LONGTEXT | v4: JSON difficulty array e.g. `["easy","medium","hard"]` |
| `hide_ui` | TINYINT(1) | v4: 1 = suppress 3D text and target indicator |
| `hold_open` | TINYINT(1) | v4: 1 = keep door physically open when unlocked |
| `lock_sound` | VARCHAR(100) | v4: custom lock sound name |
| `unlock_sound` | VARCHAR(100) | v4: custom unlock sound name |
| `groups_data` | LONGTEXT | v4: JSON `{groupName: minGrade}` |
| `items_data` | LONGTEXT | v4: JSON `[{name, metadata, remove}]` |
| `created_at` | TIMESTAMP | Creation time |
| `updated_at` | TIMESTAMP | Last update |

### `rde_door_groups`

| Column | Type | Description |
| --- | --- | --- |
| `id` | VARCHAR(50) | Unique group ID |
| `name` | VARCHAR(100) | Group display name |
| `doors` | LONGTEXT | JSON array of door IDs |
| `created_at` | TIMESTAMP | Creation time |
| `updated_at` | TIMESTAMP | Last update |

---

## 🐛 Troubleshooting

### `attempt to index a number value (local 'player')` on `ox:playerLoaded`

The correct `ox:playerLoaded` server event signature for ox_core v3+ is:

```lua
-- CORRECT:
AddEventHandler('ox:playerLoaded', function(playerId, userId, charId)
    -- playerId = server source ID (number)
    -- userId   = user ID (number)
    -- charId   = character ID (number)
end)

-- WRONG — causes the crash:
AddEventHandler('ox:playerLoaded', function(source, player)
    player.charId  -- ❌ player is actually userId (a number), not a table
end)
```

Already fixed in v4.0.0.

---

### `No such export postLog in resource rde_nostr_log`

The correct export name is `postLog`:

```lua
-- CORRECT:
exports['rde_nostr_log']:postLog('Your message', {{'event', 'event_type'}})

-- WRONG:
exports['rde_nostr_log']:log(...)
```

---

### Doors not syncing to players after restart

Run `/resyncdoors` in the server console. If doors still don't appear, verify that `oxmysql` is fully started before `rde_doors` in `server.cfg`:

```
ensure oxmysql   # must come first
ensure ox_core
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure rde_doors
```

---

### `MySQL not available` on startup

Ensure `oxmysql` starts before `rde_doors`. The resource waits for oxmysql to be in `started` state before initializing.

---

### Door created but invisible in-game

The model must exist client-side. Verify the `model` string or `model_hash` matches an actual loaded prop. Use `/doorinfo` while standing near the expected position to confirm the door was saved with correct coordinates.

> **Note on model hashes:** RDE Doors stores the integer result of `GetEntityModel()` directly. This is the only value GTA's `AddDoorToSystem` accepts reliably — many door entities have no registered string name, so `GetHashKey("model_name")` is not used as primary source.

---

### Access always denied despite being admin

Verify your ACE setup in `server.cfg`:

```
add_ace group.admin rde.doors.admin allow
add_principal identifier.steam:YOURSTEAMHEX group.admin
```

Or add your ox_core group to `Config.AdminSystem.oxGroups` in `config.lua`.

---

### How does the door state flow work?

```
Player uses ox_target on door
    → onSelect fires
    → TriggerServerEvent('rde_doors:toggleLock', doorId)

Server: toggleLock
    → HasAccess() — 8-layer check in order
    → SetDoorState(doorId, newLocked, reason, source)
        → doors[doorId].locked = newLocked
        → SaveDoor() — async MySQL UPDATE
        → BroadcastDoorUpdate(-1, doorId, door)
            → TriggerClientEvent('rde_doors:doorUpdate', -1, ...)
                → Client: SetDoorLockState() — updates GTA door system
                → Client: refreshes ox_target options (lock/unlock label flips)
                → Client: plays lock/unlock sound
        → if autolock > 0 and unlocked: SetTimeout(autolock*1000, re-lock)
        → TriggerEvent('rde_doors:stateChanged', source, doorId, locked, reason)
        → NostrLog(...)
```

---

## 🗺️ Roadmap

### ✅ Completed in v4.0.0
- Full double door support with correct heading and entity sync
- Sliding / automatic door type (configurable door rate)
- Garage and gate door types
- Lockpick system with ox_lib skill check
- Passcode unlock (server-authoritative, never sent to client)
- Per-door custom sounds
- Hold open flag
- Hide UI flag
- Per-door interact distance
- Group + grade access system
- Item + metadata access system
- Auto-migration from v3 to v4 (zero downtime)
- ox_doorlock-compatible client exports

### 🔜 Planned
- AETHER admin panel NUI (visual door manager overlay)
- Expanded multi-language support

---

## 📜 License

```
###################################################################################
#                                                                                 #
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#                                                                                 #
#   PROJECT:    RDE_DOORS v4.0.0 (NEXT-LEVEL FIVEM DOOR SYSTEM)                  #
#   ARCHITECT:  .:: RDE ⧌ Shin [△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽] ::. | https://rd-elite.com     #
#   ORIGIN:     https://github.com/RedDragonElite                                 #
#                                                                                 #
#   WARNING: THIS CODE IS PROTECTED BY DIGITAL VOODOO AND PURE HATRED FOR LEAKERS #
#                                                                                 #
#   [ THE RULES OF THE GAME ]                                                     #
#                                                                                 #
#   1. // THE "FUCK GREED" PROTOCOL (FREE USE)                                    #
#      You are free to use, edit, and abuse this code on your server.             #
#      Learn from it. Break it. Fix it. That is the hacker way.                   #
#      Cost: 0.00€. If you paid for this, you got scammed by a rat.               #
#                                                                                 #
#   2. // THE TEBEX KILL SWITCH (COMMERCIAL SUICIDE)                              #
#      Listen closely, you parasites:                                             #
#      If I find this script on Tebex, Patreon, or in a paid "Premium Pack":      #
#      > I will DMCA your store into oblivion.                                    #
#      > I will publicly shame your community.                                    #
#      > I hope your server lag spikes to 9999ms every time you blink.            #
#      SELLING FREE WORK IS THEFT. AND I AM THE JUDGE.                            #
#                                                                                 #
#   3. // THE CREDIT OATH                                                         #
#      Keep this header. If you remove my name, you admit you have no skill.      #
#      You can add "Edited by [YourName]", but never erase the original creator.  #
#      Don't be a skid. Respect the architecture.                                 #
#                                                                                 #
#   4. // THE CURSE OF THE COPY-PASTE                                             #
#      This code uses advanced logic and cryptographic patterns.                  #
#      If you just copy-paste without reading, it WILL break.                     #
#      Don't come crying to my DMs. RTFM or learn to code.                        #
#                                                                                 #
#   --------------------------------------------------------------------------    #
#   "We build the future on the graves of paid resources."                        #
#   "REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY."                          #
#   --------------------------------------------------------------------------    #
###################################################################################
```

**TL;DR:**
- ✅ Free forever — use it, edit it, learn from it
- ✅ Keep the header — credit where it's due
- ❌ Don't sell it — commercial use = instant DMCA
- ❌ Don't be a skid — copy-paste without reading won't work anyway

---

## 🌐 Community & Support

| | |
| --- | --- |
| 🐙 GitHub | [RedDragonElite](https://github.com/RedDragonElite) |
| 🌍 Website | [rd-elite.com](https://rd-elite.com) |
| 🔵 Nostr | [npub1wr4e24zn6zzjqx8kvnelfvktf0pu6l2gx4gvw06zead2eqyn23sq9tsd94](https://nostr.band/npub1wr4e24zn6zzjqx8kvnelfvktf0pu6l2gx4gvw06zead2eqyn23sq9tsd94) |
| 🤖 RDE Nostr Log | [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) |

**When asking for help, always include:**
- Full error from server console (F8 or txAdmin)
- Your `server.cfg` resource order
- ox_core / ox_lib versions

**Please DON'T:**
- ❌ DM for basic setup questions — read the docs first
- ❌ Open issues without error logs
- ❌ Ask for paid support — this is free software

**Please DO:**
- ✅ Star the repo if it helped you
- ✅ Open issues with proper reproduction steps
- ✅ Share your setup — community feedback makes this better

---

*"We build the future on the graves of paid resources."*

**REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**

🐉 Made with 🔥 by [Red Dragon Elite](https://rd-elite.com)
