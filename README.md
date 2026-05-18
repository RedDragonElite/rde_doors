# 🚪 RDE Doors — Next-Level FiveM Door System

<div align="center">

![Version](https://img.shields.io/badge/version-3.0.0-brightgreen?style=for-the-badge&logo=github)
![Status](https://img.shields.io/badge/status-STABLE-green?style=for-the-badge)
![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)
![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=for-the-badge)
![ox_core](https://img.shields.io/badge/ox__core-Required-blue?style=for-the-badge)
![Free](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)

**Production-grade, fully database-backed door system for FiveM.**  
Built on ox_core · ox_inventory · ox_lib · Nostr logging · Triple admin verification

*Built by [Red Dragon Elite](https://rd-elite.com) | SerpentsByte · v3.0.0*

</div>

---

## 📖 Table of Contents

- [What's New in v3.0.0](#-whats-new-in-v300)
- [Why RDE Doors?](#-why-rde-doors)
- [Features](#-features)
- [Dependencies](#-dependencies)
- [Installation](#-installation)
- [Upgrading from v2.x](#-upgrading-from-v2x-existing-servers)
- [Double Door Setup](#-double-door-setup)
- [Configuration](#%EF%B8%8F-configuration)
- [Admin Commands](#-admin-commands)
- [Exports & Developer API](#-exports--developer-api)
- [Nostr Logging](#-nostr-logging-integration)
- [Database Schema](#-database-schema)
- [Troubleshooting](#-troubleshooting)
- [License](#-license)

---

## 🆕 What's New in v3.0.0

### ✅ Double Door Support
The feature that took 6-9 months is finally here. Two door entities that lock and unlock together as a single unit — fully persistent, fully synced.

- **Two-step entity selection** in-world with visual outline feedback
- **Midpoint 3D text** — the door name/status floats exactly between the two doors
- **Both entities registered** in GTA's native door system simultaneously
- **ox_target on both entities** — interact with either door leaf to get the menu
- **Backward compatible** — all existing single doors work exactly as before

### ✅ Auto Database Migration
No more manual `ALTER TABLE`. On first start after upgrading, the server automatically detects missing columns and adds them. Your existing doors are untouched.

### ✅ Cleaner Door Type Selection UI
The create door dialog now uses a proper dropdown instead of a confusing single-button alert.

---

## 🔥 Why RDE Doors?

Most door scripts are static config files. You restart the server, you lose runtime changes. RDE Doors is different:

| Feature | Config-based scripts | RDE Doors |
|---|---|---|
| Runtime door creation | ❌ | ✅ |
| **Double door support** | ❌ | ✅ **v3.0.0** |
| Persistent ownership | ❌ | ✅ Database-backed |
| Per-player access lists | ❌ | ✅ |
| Item-based access | ❌ | ✅ ox_inventory |
| Door groups | ❌ | ✅ |
| Auto DB migration | ❌ | ✅ **v3.0.0** |
| Decentralized logging | ❌ | ✅ Nostr |
| Admin triple verification | ❌ | ✅ ACE + ox_core + groups |
| Autolock timers | ❌ | ✅ |
| Bell & knock system | ❌ | ✅ |
| Price / buyable doors | ❌ | ✅ |

---

## 🎯 Features

### 🔒 Core Door System
- **Full CRUD** — Create, update, delete doors at runtime
- **Single & Double doors** — Both types fully supported
- **Database persistence** — All doors survive server restarts (oxmysql)
- **Statebag sync** — Real-time door state broadcast to all players
- **Coordinate deduplication** — Prevents overlapping doors
- **Door validation** — Full server-side validation on every operation

### 🚪🚪 Double Doors
- Select two entities in-world (step-by-step with visual outline)
- Both entities register in GTA's native door system
- Lock/unlock both leaves simultaneously
- 3D text anchored at the exact midpoint between the two doors
- ox_target on both leaves — either one opens the interaction menu
- Stored as JSON in `double_door_data` column (backward compatible)

### 👤 Ownership & Access Control
- **Player ownership** — Doors can be owned per `charId`
- **Access lists** — Grant/revoke individual player access
- **Auth groups** — ox_core group-based access (e.g. `"police"`)
- **Item-based access** — Require an item from ox_inventory

### 💰 Economy
- **Buyable doors** — Set a price, sell doors to players (cash item)
- **Owner menu** — Owners can set price, rename, manage access

### 🔔 Interactions
- **Bell system** — Ring the bell, owner gets notified
- **Knock system** — Knock animation + owner notification
- **Door groups** — Group multiple doors, manage them together

### 👑 Admin System
- **Triple verification**: ACE permissions + ox_core groups + Steam IDs
- **In-game door manager** (`/doormanager`) — full CRUD for all doors
- **Admin teleport** to any door
- **`/doorslist`** — list all doors with type labels `[SINGLE]` / `[DOUBLE]`
- **`/doorinfo`** — detailed info on nearest door
- **`/resyncdoors`** — hot-reload doors from database
- **`/cleandoors`** — remove invalid entries

---

## 📦 Dependencies

```
ox_core
ox_lib
ox_target
ox_inventory
oxmysql
```

Optional: `rde_nostr_log` (for decentralized event logging)

---

## 🚀 Installation

### Fresh Install

1. Drop `rde_doors` into your resources folder
2. Add `ensure rde_doors` to `server.cfg` **after** all dependencies
3. Start the server — tables are created automatically, no SQL needed

### Starting Order (server.cfg)
```
ensure oxmysql
ensure ox_core
ensure ox_lib
ensure ox_target
ensure ox_inventory
ensure rde_doors
```

---

## ⬆️ Upgrading from v2.x (existing servers)

> **Zero data loss. Your existing doors are fully compatible.**

1. Replace the resource files with v3.0.0
2. Start the server
3. The server auto-detects the missing `double_door_data` column and adds it via `ALTER TABLE`
4. All existing single doors load and work exactly as before
5. Done — no manual SQL required

You'll see this in the console on first start after upgrade:
```
[RDE | Doors | Server] [INFO] Migration applied: added column double_door_data
[RDE | Doors | Server] [INFO] Database ready (schema up to date)
```

---

## 🚪🚪 Double Door Setup

### Creating a Double Door In-Game

1. Run `/createdoor` (admin required)
2. The dialog asks: **Single Door** or **Double Door** — select `🚪🚪 Double Door`
3. A selection sphere follows your crosshair
4. **Left-click** on the first door entity (it gets outlined in white)
5. A notification confirms: *"Door 1/2 selected. Select door 2 now."*
6. **Left-click** on the second door entity
7. Enter the door name and price
8. Done — both doors are registered, locked together, and the 3D text appears at the midpoint

### Tips
- Stand close to the doors when selecting (within ~5m)
- The two entities should be the same model (matching double door pair)
- Use `/doorinfo` after creation to verify both sub-door models are stored correctly
- Right-click cancels the selection at any point

### How It Works Internally
```
double door record
├── coords: { midpoint between door_a and door_b }  ← used for proximity/3D text
├── door_a: { model, coords, heading }              ← stored in double_door_data JSON
└── door_b: { model, coords, heading }              ← stored in double_door_data JSON
```

Both sub-doors are registered independently in GTA's `DoorSystem` with unique hashes (`rde_door_{id}_a` / `rde_door_{id}_b`). When you toggle the lock, both states change simultaneously.

---

## ⚙️ Configuration

All settings live in `shared/config.lua`. Key options:

```lua
Config.DefaultLanguage = 'en'  -- or 'de'

Config.UI = {
    use3DText            = true,
    textDistance         = 5.0,       -- meters to show 3D text
    interactionDistance  = 2.5,       -- ox_target range
    proximityLoadDistance = 30.0,     -- load door targets within this range
}

Config.AdminSystem = {
    acePermission = 'rde.doors.admin',
    oxGroups = { ['admin'] = 0, ['superadmin'] = 0, ['management'] = 0 },
}
```

---

## 📊 Admin Commands

| Command | Description |
|---|---|
| `/createdoor` | Select a door entity in-world and register it (single or double) |
| `/doormanager` | Open the full door management UI |
| `/doorslist` | Print all doors to server console with `[SINGLE]`/`[DOUBLE]` labels |
| `/doorinfo` | Detailed info about the nearest door (within 10m) |
| `/resyncdoors` | Reload all doors from database and resync all players |
| `/cleandoors` | Remove doors with invalid coordinates from the database |
| `/doordebug` (client) | Debug info in F8 console (Debug mode only) |

---

## 🔌 Exports & Developer API

### Server Events

```lua
-- Toggle a door
TriggerServerEvent('rde_doors:toggleLock', doorId)

-- Create a single door
TriggerServerEvent('rde_doors:createDoor', {
    name    = 'My Door',
    model   = 'v_ilev_ph_gendoor004',
    coords  = { x = 0.0, y = 0.0, z = 0.0 },
    heading = 0.0,
    locked  = true,
    price   = 0,
    auth    = { 'police' },   -- optional group access
})

-- Create a double door
TriggerServerEvent('rde_doors:createDoor', {
    name   = 'My Double Door',
    type   = 'double',
    coords = { x = 0.0, y = 0.0, z = 0.0 },  -- midpoint
    locked = true,
    door_a = {
        model   = 'v_ilev_bk_door',
        coords  = { x = -0.3, y = 0.0, z = 0.0 },
        heading = 0.0,
    },
    door_b = {
        model   = 'v_ilev_bk_door',
        coords  = { x =  0.3, y = 0.0, z = 0.0 },
        heading = 180.0,
    },
})

-- Update door properties
TriggerServerEvent('rde_doors:updateDoor', doorId, { name='New Name', price=5000 })

-- Delete a door
TriggerServerEvent('rde_doors:deleteDoor', doorId)

-- Manage access
TriggerServerEvent('rde_doors:manageAccess', doorId, targetServerId, true)  -- grant
TriggerServerEvent('rde_doors:manageAccess', doorId, charId, false)         -- revoke
```

### Callbacks

```lua
-- Check if player is admin
lib.callback('rde_doors:checkAdmin', false, function(isAdmin) end)

-- Check if player has access to a door
lib.callback('rde_doors:checkAccess', false, function(hasAccess) end, doorId)
```

---

## 📡 Nostr Logging Integration

RDE Doors supports optional decentralized event logging via [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log).

When `rde_nostr_log` is started, the following events are logged automatically:
- Door created / updated / deleted
- Lock toggled
- Door purchased
- Access granted / revoked
- Bell rung / knock

If `rde_nostr_log` is not present, logging is silently skipped — no errors.

---

## 🗄️ Database Schema

Two tables are created automatically:

### `rde_owned_doors`
| Column | Type | Description |
|---|---|---|
| `id` | VARCHAR(50) | Unique door ID |
| `type` | VARCHAR(20) | `single` or `double` |
| `name` | VARCHAR(100) | Display name |
| `coords` | LONGTEXT | JSON `{x,y,z}` — midpoint for double doors |
| `model` | VARCHAR(100) | Model name (empty for double doors) |
| `double_door_data` | LONGTEXT | **v3.0.0** JSON with `door_a` and `door_b` sub-door data |
| `locked` | TINYINT(1) | 1 = locked |
| `auth` | LONGTEXT | JSON array of group names |
| `items` | LONGTEXT | JSON array of required item names |
| `owner_charid` | VARCHAR(50) | ox_core charId of owner |
| `access_list` | LONGTEXT | JSON array of charIds with access |
| `price` | INT | Sale price (0 = not for sale) |
| `group_id` | VARCHAR(50) | Door group membership |

### `rde_door_groups`
| Column | Type | Description |
|---|---|---|
| `id` | VARCHAR(50) | Unique group ID |
| `name` | VARCHAR(100) | Group name |
| `doors` | LONGTEXT | JSON array of door IDs |

---

## 🔧 Troubleshooting

### Double door entities not found after server restart
The server computes the midpoint at load time and each client looks up the physical entities by model + coords when they come into proximity. Make sure the `double_door_data` column was created (check console for migration log on startup). Run `/doorinfo` near the door to verify both models are stored.

### "Door already exists at this position"
The system checks within a 1m radius. If you're trying to register a door that was previously deleted from the database but the coordinates overlap, use `/cleandoors` first.

### Doors not showing after hot-restart
Run `/resyncdoors` or trigger `rde_doors:requestSync` from the client. The proximity loop also re-checks every second.

### Auto-migration not running
Ensure your database user has `ALTER TABLE` privileges. The migration check queries `information_schema.COLUMNS` — confirm the DB user has `SELECT` on `information_schema`.

---

## 📜 License

```
RDE Black Flag Source License v6.66
Free to use on your server. Do not sell. Keep credits.
See LICENSE file for full terms.
```

*Built with ☠️ by RDE | SerpentsByte*
