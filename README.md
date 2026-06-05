# 🚪 RDE Doors — Next-Level FiveM Door System

<div align="center">

![Version](https://img.shields.io/badge/version-4.0.0-brightgreen?style=for-the-badge&logo=github)
![Status](https://img.shields.io/badge/status-STABLE-green?style=for-the-badge)
![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)
![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=for-the-badge)
![ox_core](https://img.shields.io/badge/ox__core-Required-blue?style=for-the-badge)
![Free](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)

**Production-grade, fully database-backed door system for FiveM.**  
Built on ox_core · ox_inventory · ox_lib · Nostr logging · Triple admin verification

*Built by [Red Dragon Elite](https://rd-elite.com) | SerpentsByte · v4.0.0*

</div>

---

## 📖 Table of Contents

- [What's New in v4.0.0](#-whats-new-in-v400)
- [Why RDE Doors?](#-why-rde-doors)
- [Features](#-features)
- [Dependencies](#-dependencies)
- [Installation](#-installation)
- [Upgrading from v3.x / v2.x](#-upgrading-from-v3x--v2x-existing-servers)
- [Sliding & Automatic Doors](#-sliding--automatic-doors)
- [Lockpick System](#-lockpick-system)
- [Passcode System](#-passcode-system)
- [Configuration](#%EF%B8%8F-configuration)
- [Admin Commands](#-admin-commands)
- [Exports & Developer API](#-exports--developer-api)
- [Nostr Logging](#-nostr-logging-integration)
- [Database Schema](#-database-schema)
- [For Developers — How the Door System Works](#-for-developers--how-the-door-system-works)
- [Troubleshooting](#-troubleshooting)
- [License](#-license)

---

## 🆕 What's New in v4.0.0

Full ox_doorlock feature parity. Every feature from the ox_doorlock spec is now supported natively in RDE Doors — with persistence, ownership, Nostr logging, and all the v3 features intact.

### ✅ Sliding & Automatic Doors
Calls `DoorSystemSetAutomaticRate()` so sliding doors actually slide, garage doors roll up, and gates swing properly. Previously all doors used swing animation regardless of type. Configurable rate per door.

### ✅ Lockpick System
Players with a `lockpick` or `advancedlockpick` item can attempt to pick lockpick-enabled doors. Uses ox_lib skillcheck with configurable difficulty chains per door. Break chances on success/failure. Full animation.

### ✅ Passcode System
Set a numeric or text passcode on any door. Players without other access get prompted for the code. **The passcode is never sent to clients** — server-side validated only.

### ✅ Autolock Timers
Set a door to automatically re-lock N seconds after being unlocked. Manually re-locking cancels the pending timer.

### ✅ Per-Door Interact Distance
Each door can have a custom ox_target interaction radius instead of the global default.

### ✅ Group + Grade Authorization
`groups_data = {"police": 2, "sheriff": 3}` — minimum grade per group, not just group membership.

### ✅ Item Metadata
Filter item access by metadata. A badge with `metadata.type = "police_hq"` only opens doors that require exactly that metadata variant.

### ✅ Hide UI
Per-door flag to suppress 3D text and target indicators. Useful for ambient/world doors that should lock silently.

### ✅ Hold Open
Door physically stays open when unlocked using `DoorSystemSetHoldOpen`. Closes when locked.

### ✅ Custom Sounds Per Door
Override the default lock/unlock sound with any GTA audio string, per door.

### ✅ Advanced Settings Menu
Full in-game admin UI exposing all new fields — no config editing required.

### ✅ Client Exports (ox_doorlock-compatible)
`getClosestDoor()`, `useClosestDoor()`, `pickClosestDoor()` — drop-in compatible with scripts that call ox_doorlock exports.

### ✅ Server Exports
`getDoor()`, `getDoorFromName()`, `getAllDoors()`, `setDoorState()`, `editDoor()` — full programmatic control from other resources.

### ✅ Critical Bug Fix: Model Hash Resolution
All door types (v2 single doors, v3 double doors, v4 new doors) now correctly resolve their GTA model hash for `AddDoorToSystem`. Previously, doors created at runtime had their model hash stored incorrectly, causing `DoorSystemSetDoorState` to be a no-op — doors showed as "Locked" in the UI but were physically passable. This is now fixed for all existing and new doors.

---

## 🔥 Why RDE Doors?

| Feature | Config-based | ox_doorlock | RDE Doors v4 |
|---|---|---|---|
| Runtime door creation | ❌ | ✅ | ✅ |
| Double doors | ❌ | ✅ | ✅ |
| Sliding / automatic doors | ⚠️ | ✅ | ✅ **v4** |
| Lockpick system | ❌ | ✅ | ✅ **v4** |
| Passcode | ❌ | ✅ | ✅ **v4** |
| Autolock timers | ❌ | ✅ | ✅ **v4** |
| Per-door interact distance | ❌ | ✅ | ✅ **v4** |
| Group + Grade auth | ❌ | ✅ | ✅ **v4** |
| Item metadata | ❌ | ✅ | ✅ **v4** |
| Hide UI | ❌ | ✅ | ✅ **v4** |
| Hold open | ❌ | ✅ | ✅ **v4** |
| Custom sounds | ❌ | ✅ | ✅ **v4** |
| **Persistent ownership** | ❌ | ❌ | ✅ |
| **Per-player access lists** | ❌ | ❌ | ✅ |
| **Buyable doors** | ❌ | ❌ | ✅ |
| **Door groups** | ❌ | ❌ | ✅ |
| **Auto DB migration** | ❌ | ❌ | ✅ |
| **Nostr logging** | ❌ | ❌ | ✅ |
| **Bell / knock system** | ❌ | ❌ | ✅ |

---

## 🎯 Features

### Core
- Full CRUD — create, update, delete doors at runtime
- Single, double, sliding, garage, gate door types
- Database persistence via oxmysql
- Real-time state sync to all players
- GTA native door system integration

### Access Control (evaluated in order)
1. **Admin** — ACE / ox_core admin group
2. **Owner** — `owner_charid` match
3. **Access list** — per-character grant/revoke
4. **Legacy `auth`** — group name only (backward compat with v2/v3 doors)
5. **Group + Grade** — e.g. `police >= grade 2`
6. **Item + Metadata** — badge with specific metadata
7. **Item** — any matching item (legacy)
8. **Passcode** — anyone who knows the code

### Owner Features
- Set a sale price → door becomes buyable
- Manage access list (grant / revoke per character)
- Ring bell → owner notification
- Knock → owner notification + animation

### Admin Features
- Full door manager UI (`/doormanager`)
- Advanced settings panel (all v4 fields)
- Group + grade management
- Item + metadata management
- Door groups (collections)
- `/createdoor`, `/doorslist`, `/doorinfo`, `/resyncdoors`, `/cleandoors`

---

## 📦 Dependencies

| Resource | Required | Purpose |
|---|---|---|
| [ox_core](https://github.com/communityox/ox_core) | ✅ | Player / character system |
| [ox_lib](https://github.com/communityox/ox_lib) | ✅ | UI, skillcheck, notifications, callbacks |
| [ox_target](https://github.com/communityox/ox_target) | ✅ | Door interaction |
| [ox_inventory](https://github.com/communityox/ox_inventory) | ✅ | Item checks, lockpick items |
| [oxmysql](https://github.com/communityox/oxmysql) | ✅ | Database |
| [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) | ⬜ optional | Decentralized event logging |

---

## 🚀 Installation

### Fresh Install
```
1. Drop rde_doors into your resources folder
2. Add `ensure rde_doors` to server.cfg after all dependencies
3. Start — tables and schema are created automatically, no SQL needed
```

### server.cfg order
```
ensure oxmysql
ensure ox_core
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure rde_doors
```

---

## ⬆️ Upgrading from v3.x / v2.x (existing servers)

**Zero data loss. All existing doors are fully compatible.**

1. Replace the resource folder with v4.0.0
2. `restart rde_doors`
3. Done

On first start, auto-migration adds all missing columns to `rde_owned_doors`. Existing doors keep their exact data and behavior. v2 single doors, v3 double doors — all load and lock correctly.

Console output on successful migration:
```
[RDE Doors v4.0.0] ✅ Migration: 11 new column(s) added
[RDE Doors v4.0.0] ✅ Ready — 37 doors | 0 lockpickable | 2 automatic
```

### Downgrading back to v3
Safe — v3 ignores the new columns. Doors created with v4 features (lockpick, passcode etc.) revert to v3 behavior but remain functional. Zero data loss.

---

## ↔️ Sliding & Automatic Doors

GTA's door system has two modes: swing (standard hinged door) and automatic (sliding/garage/gate). The mode is controlled by `DoorSystemSetAutomaticRate(hash, rate)`.

RDE Doors v4 calls this automatically based on door type:

| Type | Default `auto` | Default `door_rate` | Effect |
|---|---|---|---|
| `single` | false | 10.0 | Normal swing |
| `double` | false | 10.0 | Normal swing |
| `sliding` | **true** | **0.0** | Instant slide |
| `garage` | **true** | **0.0** | Instant roll |
| `gate` | **true** | **0.0** | Instant swing |

Override per door in Advanced Settings:
- **Auto toggle** — switch between automatic and swing behavior
- **Door rate** — any float. `0.0` = instant. `10.0` = default swing speed. Leave empty to derive from `auto`.

---

## 🔧 Lockpick System

Enable lockpicking on a door via the Admin → Advanced Settings menu.

Players with a `lockpick` or `advancedlockpick` item (configurable) will see a **"Pick Lock"** option in the ox_target menu.

### Difficulty
Set a difficulty chain per door. Each entry is one skillcheck round:

| Preset | Description |
|---|---|
| `easy` | Large area, slow speed |
| `medium` | Medium area, medium speed |
| `hard` | Small area, fast speed |

Example chains: `"easy,easy,medium"` (default), `"hard,hard,hard"`, `"easy,medium,hard"`.

### Break Chances (configurable in `shared/config.lua`)
- On success: 5% chance the lockpick breaks
- On failure: 20% chance the lockpick breaks

---

## 🔢 Passcode System

Set a passcode via Admin → Advanced Settings.

**Security model:** The passcode is stored server-side only. The client receives `has_passcode = true` but never the actual code. Validation happens server-side on every attempt.

Players who already have access (owner, access list, group, item) skip the passcode prompt and toggle directly.

---

## ⚙️ Configuration

All settings in `shared/config.lua`:

```lua
Config.DefaultLanguage = 'en'  -- 'en' or 'de'

Config.UI = {
    use3DText             = true,
    textDistance          = 5.0,
    interactionDistance   = 2.5,
    proximityLoadDistance = 30.0,
}

Config.Defaults = {
    locked       = true,
    autolock     = 0,
    maxDistance  = 2.5,
    doorRateSwing = 10.0,   -- rate for swing doors (single/double)
    doorRateAuto  = 0.0,    -- rate for automatic doors (sliding/garage/gate)
}

Config.Lockpick = {
    items               = { 'lockpick', 'advancedlockpick' },
    defaultDifficulty   = { 'easy', 'easy', 'medium' },
    breakChanceOnFail   = 0.20,
    breakChanceOnSuccess= 0.05,
    canPickUnlocked     = false,
    cooldownMs          = 1500,
}

Config.AdminSystem = {
    acePermission = 'rde.doors.admin',
    oxGroups      = { ['admin'] = 0, ['superadmin'] = 0, ['management'] = 0 },
}
```

---

## 📊 Admin Commands

| Command | Description |
|---|---|
| `/createdoor` | Select door entity in-world (single or double) and register it |
| `/doormanager` | Open full door management UI |
| `/doorslist` | Print all doors to console with type labels |
| `/doorinfo` | Detailed info on nearest door (within 10m) |
| `/resyncdoors` | Reload from DB and resync all clients |
| `/cleandoors` | Remove doors with invalid coordinates |

---

## 🧩 Exports & Developer API

### Server
```lua
-- Get door by ID
local door = exports.rde_doors:getDoor('door_1770730495_619217')

-- Get door by name
local door = exports.rde_doors:getDoorFromName('Missionrow - Cells Frontdoor')

-- Get all doors (client-safe format, no passcodes)
local all = exports.rde_doors:getAllDoors()

-- Set lock state programmatically (bypasses auth, triggers broadcast + Nostr log)
exports.rde_doors:setDoorState('door_id', true,  'lockdown')   -- lock
exports.rde_doors:setDoorState('door_id', false, 'event_open') -- unlock

-- Edit any field
exports.rde_doors:editDoor('door_id', {
    autolock   = 30,
    lockpick   = true,
    passcode   = '1337',
    groups_data = { police = 2 },
})
```

### Client
```lua
-- Get closest door object
local door = exports.rde_doors:getClosestDoor()

-- Toggle lock on closest door (same as player interacting)
exports.rde_doors:useClosestDoor()

-- Start lockpick on closest lockpickable door
exports.rde_doors:pickClosestDoor()
```

### Events
```lua
-- Fires on every lock state change (server-side)
AddEventHandler('rde_doors:stateChanged', function(source, doorId, locked, reason)
    -- reason: 'owner' | 'access_list' | 'legacy_auth' | 'group_grade' |
    --         'item:NAME' | 'item_meta:NAME' | 'passcode' |
    --         'lockpick:lockpick' | 'lockpick:advancedlockpick' |
    --         'autolock' | 'admin'
    if reason and reason:find('lockpick') then
        -- trigger police dispatch etc.
    end
end)
```

---

## 📡 Nostr Logging Integration

If `rde_nostr_log` is running, all door events are published to Nostr relays automatically:

- Door created / updated / deleted
- Lock / unlock (with auth reason)
- Lockpick attempts (success, failure, broken pick)
- Autolock trigger
- Door purchased
- Access list changes
- DB migrations

No configuration needed — detection is automatic. If `rde_nostr_log` is absent, logging is silently skipped.

---

## 🗄️ Database Schema

Tables are created and migrated automatically. The `door_sql.sql` file is for reference only — **do not run it manually**.

### `rde_owned_doors`

| Column | Type | Description |
|---|---|---|
| `id` | VARCHAR(50) | Unique door ID (`door_{timestamp}_{random}`) |
| `type` | VARCHAR(20) | `single` / `double` / `sliding` / `garage` / `gate` |
| `name` | VARCHAR(100) | Display name |
| `coords` | LONGTEXT | JSON `{x,y,z}` — midpoint for double doors |
| `model` | VARCHAR(100) | GTA model hash integer (from `GetEntityModel`) |
| `model_hash` | VARCHAR(50) | Legacy field — not used for door system registration |
| `locked` | TINYINT(1) | 1 = locked |
| `auth` | LONGTEXT | JSON array of group names (legacy v2/v3 auth) |
| `autolock` | INT | Auto-relock delay in seconds (0 = disabled) |
| `items` | LONGTEXT | JSON array of item names (legacy) |
| `heading` | FLOAT | Entity heading |
| `maxDistance` | FLOAT | ox_target interaction radius |
| `owner_charid` | VARCHAR(50) | ox_core charId of owner |
| `owner_name` | VARCHAR(100) | Display name of owner |
| `price` | INT | Sale price (0 = not for sale) |
| `access_list` | LONGTEXT | JSON array of charIds with access |
| `group_id` | VARCHAR(50) | Door group membership |
| `double_door_data` | LONGTEXT | **v3** JSON `{door_a, door_b}` sub-door data |
| `passcode` | VARCHAR(100) | **v4** Passcode (server-side only, never sent to client) |
| `auto` | TINYINT(1) | **v4** Automatic door flag (sliding/garage/gate) |
| `door_rate` | FLOAT | **v4** Movement rate (NULL = derived from `auto`) |
| `lockpick` | TINYINT(1) | **v4** Door is lockpickable |
| `lockpick_difficulty` | LONGTEXT | **v4** JSON difficulty chain |
| `hide_ui` | TINYINT(1) | **v4** Hide 3D text and target indicators |
| `hold_open` | TINYINT(1) | **v4** Keep door physically open when unlocked |
| `lock_sound` | VARCHAR(100) | **v4** Custom lock sound name |
| `unlock_sound` | VARCHAR(100) | **v4** Custom unlock sound name |
| `groups_data` | LONGTEXT | **v4** JSON `{groupName: minGrade}` |
| `items_data` | LONGTEXT | **v4** JSON `[{name, metadata, remove}]` |

### `rde_door_groups`

| Column | Type | Description |
|---|---|---|
| `id` | VARCHAR(50) | Unique group ID |
| `name` | VARCHAR(100) | Group display name |
| `doors` | LONGTEXT | JSON array of door IDs |

---

## 🔬 For Developers — How the Door System Works

This section explains the internals for devs who want to understand or extend RDE Doors.

### Model Hash Resolution

GTA's `AddDoorToSystem(doorHash, modelHash, x, y, z, ...)` requires two hashes:

- **`doorHash`** — a custom identifier we generate via `joaat('rde_door_{id}')`. Unique per door, never conflicts with GTA's built-in doors.
- **`modelHash`** — the actual GTA model hash. **Must match the entity's model exactly.**

The correct model hash comes from `GetEntityModel(entity)` at door creation time, which returns an **integer**. This is stored in the `model` column as a VARCHAR integer string (e.g. `"631614199"`).

**Why not use model names?** Many GTA door entities have no registered model name — they exist only as hashed integers with no string representation. `GetHashKey("some_model")` only works if the model name is in GTA's name table.

The `model_hash` column is a legacy artifact from an earlier calculation that produced incorrect values. It is kept for schema compatibility but **not used** for door system registration.

### Door State Flow

```
Player presses E on door
    → ox_target onSelect fires
    → TriggerServerEvent('rde_doors:toggleLock', doorId)

Server: toggleLock
    → HasAccess() check (8 layers in order)
    → SetDoorState(doorId, newLocked, reason, source)
        → doors[doorId].locked = newLocked
        → saves to DB (MySQL.update)
        → BroadcastDoorUpdate(doorId, door)
            → TriggerClientEvent('rde_doors:doorUpdate', -1, ...)

All clients: doorUpdate
    → loadedDoors[doorId] = door  (new state)
    → if in range: PlayDoorSound()
    → SetDoorLockState(door, door.locked)  (if entities exist)
    → RemoveDoorTarget + CreateDoorTarget  (refresh label)
        → RegisterDoorsWithSystem(doorId, door)
            → AddDoorToSystem(doorHash, modelHash, x, y, z)
            → DoorSystemSetDoorState(doorHash, 4)        ← GTA reset
            → DoorSystemSetAutomaticRate(doorHash, rate)
            → DoorSystemSetDoorState(doorHash, locked ? 1 : 0)
```

### Why `DoorSystemSetDoorState(hash, 4)`?

State 4 is a GTA-internal reset signal that must be sent before changing the lock state on an already-registered door. Without it, `DoorSystemSetDoorState` is sometimes ignored by the engine. This was discovered empirically — it is not documented in any GTA native reference.

### Double Door Internals

```
DB record
├── type: "double"
├── coords: { midpoint }          ← 3D text anchor, proximity check
├── model: ""                     ← empty for double doors
└── double_door_data: JSON
    ├── door_a: { model (int), coords, heading }
    └── door_b: { model (int), coords, heading }

Client-side
├── joaat('rde_door_{id}_a') → hashA  → registered in GTA door system
├── joaat('rde_door_{id}_b') → hashB  → registered in GTA door system
└── ox_target on both entities → same option list
```

### Auth Evaluation Order (server-side)

```lua
1. IsAdmin(source)                  → ACE + ox_core group check
2. door.owner_charid == charId      → exact match
3. door.access_list contains charId → explicit grant
4. door.auth contains group name    → legacy v2/v3 group auth
5. door.groups_data[group] <= grade → v4 group+grade
6. items_data with metadata match   → v4 item+metadata
7. items_data without metadata      → v4 item (any)
8. passcode match                   → v4 passcode
```

If none match → deny, play error notification.

---

## 🐛 Troubleshooting

**Door shows "Locked" but player can walk through**
→ The model hash stored in the `model` column is likely `0` or incorrect. This happened on doors created before v4.0.0 where `GetEntityModel()` returned an integer that was not saved correctly. Fix: delete and recreate the door with v4.0.0, or manually update the `model` column in the DB with the correct GTA model hash integer.

**Sliding/garage door swings instead of slides**
→ Make sure `auto = 1` is set on the door (Admin → Advanced Settings → "Automatic Door"). For `sliding`/`garage`/`gate` types, this is set automatically on creation.

**Lockpick option not showing**
→ Door must have `lockpick = 1` (Advanced Settings) AND the player must have a `lockpick` or `advancedlockpick` item.

**Passcode prompt not appearing**
→ Only shown to players who have no other access. Admins, owners, access list members, and authorized group members go straight to toggle.

**Autolock not firing**
→ Autolock only triggers on unlock. Re-locking manually cancels the pending timer — this is intentional.

**Migration not running**
→ DB user needs `ALTER TABLE` and `SELECT on information_schema` privileges.

**Door target not appearing**
→ The `activeTargets` limit (default 20) may be hit. Increase `Config.Performance.maxActiveTargets` or move away and back to trigger re-registration.

---

## 📜 License

```
RDE Black Flag Source License v6.66
Free to use on your server. Do not sell. Keep credits.
See LICENSE file for full terms.
```

*Built with ☠️ by RDE | SerpentsByte*
