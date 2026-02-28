# 🚪 RDE Doors — Next-Level FiveM Door System
<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/88cd9964-eee7-4593-95e9-505b1b15b216" />

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.0--alpha-red?style=for-the-badge&logo=github)
![Status](https://img.shields.io/badge/status-EARLY%20ALPHA-orange?style=for-the-badge)
![License](https://img.shields.io/badge/license-RDE%20Black%20Flag%20v6.66-black?style=for-the-badge)
![FiveM](https://img.shields.io/badge/FiveM-Compatible-orange?style=for-the-badge)
![ox_core](https://img.shields.io/badge/ox__core-Required-blue?style=for-the-badge)
![Free](https://img.shields.io/badge/price-FREE%20FOREVER-brightgreen?style=for-the-badge)

**Production-grade, fully database-backed door system for FiveM.**
Built on ox_core · ox_inventory · ox_lib · Nostr logging · Triple admin verification

*Built by [Red Dragon Elite](https://rd-elite.com) | SerpentsByte · v1.0.0-alpha*

</div>

> [!WARNING]
> **🚧 EARLY ALPHA — ACTIVE DEVELOPMENT**
>
> This resource is fully functional for single doors and all core features listed below.
> However, it is still under active development and **not yet feature-complete**.
>
> **Known limitations in v1.0.0-alpha:**
> - ❌ **Double doors** — not working correctly yet (in progress)
> - ⚠️ API surface may change between alpha releases
> - ⚠️ Expect breaking changes before the stable 1.0.0 release
>
> Use in production at your own discretion. Bug reports and feedback welcome — that's exactly what alpha is for.

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

| Feature | Config-based scripts | RDE Doors |
|---|---|---|
| Runtime door creation | ❌ | ✅ |
| Persistent ownership | ❌ | ✅ Database-backed |
| Per-player access lists | ❌ | ✅ |
| Item-based access | ❌ | ✅ ox_inventory |
| Door groups | ❌ | ✅ |
| Decentralized logging | ❌ | ✅ Nostr |
| Admin triple verification | ❌ | ✅ ACE + ox_core + groups |
| Autolock timers | ❌ | ✅ |
| Bell & knock system | ❌ | ✅ |
| Price / buyable doors | ❌ | ✅ |

---

## 🎯 Features

### 🔒 Core Door System
- **Full CRUD** — Create, update, delete doors at runtime via events or admin commands
- **Database persistence** — All doors and groups survive server restarts (oxmysql)
- **Statebag sync** — Real-time door state broadcast to all players
- **Coordinate deduplication** — Prevents overlapping doors at the same position
- **Door validation** — Full server-side data validation on every operation

### 👤 Ownership & Access Control
- **Player ownership** — Doors can be owned per `charId`
- **Access lists** — Grant/revoke access to specific characters
- **Group-based auth** — Lock doors to ox_core groups (e.g. `police`, `mechanic`)
- **Item-based access** — Require an item from ox_inventory to open a door
- **Triple admin verification** — ACE permissions + ox_core groups + manual fallback
- **Buyable doors** — Set a price; players can purchase ownership in-game

### 🔔 Realism Features
- **Door bell** — Ring a doorbell; the owner gets notified via ox_lib
- **Knock** — Knock on a door; same notification system
- **Autolock** — Doors re-lock automatically after a configurable timeout
- **Max distance** — Per-door configurable interaction range

### 📊 Door Groups
- Create named groups containing multiple doors
- Lock/unlock an entire group at once
- Full group CRUD with persistent storage

### 🛡️ Admin Tools
- `/doorslist` — Print all doors to server console with validity status
- `/resyncdoors` — Force-resync all doors to all connected players
- `/cleandoors` — Scan and remove corrupted/invalid door entries from the DB
- `/doorinfo` — Get detailed info on the nearest door (within 10m)

### 📡 Nostr Logging
- Every significant action is broadcast to the Nostr network via `rde_nostr_log`
- Decentralized, permanent, uncensorable server logs
- See [Nostr Logging](#-nostr-logging-integration) section

---

## 📦 Dependencies

| Resource | Required | Notes |
|---|---|---|
| [oxmysql](https://github.com/communityox/oxmysql) | ✅ Required | Database layer |
| [ox_core](https://github.com/communityox/ox_core) | ✅ Required | Player/character framework |
| [ox_lib](https://github.com/communityox/ox_lib) | ✅ Required | Callbacks, commands, notifications |
| [ox_inventory](https://github.com/communityox/ox_inventory) | ✅ Required | Item-based door access |
| [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) | ⚠️ Optional | Decentralized logging — highly recommended |

---

## 🚀 Installation

### 1. Clone the repository

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_doors.git
```

### 2. Add to `server.cfg`

```cfg
ensure oxmysql
ensure ox_core
ensure ox_lib
ensure ox_inventory
ensure rde_nostr_log   # optional but recommended
ensure rde_doors
```

> **Order matters.** `rde_doors` must start **after** all its dependencies.

### 3. Start / Restart

```
start rde_doors
```

The database tables are created automatically on first start. No manual SQL import needed.

### 4. Verify

Check your server console — you should see:

```
[RDE Doors] ✅ Ready with X doors (X valid) and X groups
[RDE Doors] 📜 Server-side script ready
```

---

## ⚙️ Configuration

Edit `shared/config.lua`:

```lua
Config = {
    Debug = true,                       -- Enable verbose logging
    DefaultLanguage = 'en',             -- 'en' or 'de'

    Defaults = {
        type        = 'single',         -- Default door type
        locked      = true,             -- Doors start locked
        autolock    = 0,                -- 0 = disabled, seconds otherwise
        heading     = 0.0,              -- Default heading
        maxDistance = 2.5,              -- Default interaction range (meters)
        price       = 0,                -- 0 = not for sale
    },

    AdminSystem = {
        acePermission = 'rde.doors.admin',  -- ACE node
        oxGroups = {
            admin      = true,
            superadmin = true,
            management = true,
        },
    },

    Performance = {
        useStateBags = true,            -- Statebag-based sync
    },
}
```

### ACE Permissions (server.cfg)

```cfg
add_ace group.admin rde.doors.admin allow
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
    type        = 'single',         -- 'single' or 'double'
    locked      = true,
    auth        = { 'police' },     -- ox_core groups with access
    items       = { 'keycard_pd' }, -- ox_inventory items that grant access
    autolock    = 30,               -- seconds, 0 to disable
    heading     = 0.0,
    maxDistance = 2.5,
    price       = 0,
})
```

#### Toggle Lock
```lua
TriggerServerEvent('rde_doors:toggleLock', doorId)
```

#### Update a Door
```lua
TriggerServerEvent('rde_doors:updateDoor', doorId, {
    name  = 'New Name',
    price = 5000,
    auth  = { 'police', 'ambulance' },
})
```

#### Delete a Door
```lua
TriggerServerEvent('rde_doors:deleteDoor', doorId)
```

#### Manage Access
```lua
-- Grant access to a character
TriggerServerEvent('rde_doors:manageAccess', doorId, targetCharId, true)

-- Revoke access
TriggerServerEvent('rde_doors:manageAccess', doorId, targetCharId, false)
```

#### Door Groups
```lua
TriggerServerEvent('rde_doors:createGroup', 'Police HQ')
TriggerServerEvent('rde_doors:addToGroup', doorId, groupId)
TriggerServerEvent('rde_doors:removeFromGroup', doorId, groupId)
TriggerServerEvent('rde_doors:renameGroup', groupId, 'New Group Name')
TriggerServerEvent('rde_doors:deleteGroup', groupId)
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

-- Buy a door (deducts price from ox_inventory money)
lib.callback('rde_doors:buyDoor', false, function(success, message)
    print(success, message)
end, doorId)
```

### Client Events (listening)

```lua
-- Fired when all doors are synced to this client
AddEventHandler('rde_doors:syncDoors', function(doorArray, doorGroups)
    -- doorArray: table of all door objects
    -- doorGroups: table of all group objects
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
```

---

## 📋 Admin Commands

All commands require the `rde.doors.admin` ACE permission or an admin ox_core group.

| Command | Description |
|---|---|
| `/doorslist` | Lists all doors in the server console with validity info |
| `/resyncdoors` | Reloads all doors from DB and resyncs to every player |
| `/cleandoors` | Removes invalid/corrupted door records from the database |
| `/doorinfo` | Prints detailed info about the closest door (≤ 10m) to console |

---

## 📡 Nostr Logging Integration

RDE Doors integrates natively with [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) — the world's first decentralized FiveM logging system.

If `rde_nostr_log` is not running, logging is silently skipped — **no errors, no crashes**.

### Events Logged

| Event | Nostr Message |
|---|---|
| Player loaded | `👤 Player loaded: Name \| UserID: X \| CharID: X` |
| Player dropped | `👋 Player dropped: Name \| Reason: X` |
| Door locked/unlocked | `🔒 Door Locked/Unlocked \| Name \| By: Player` |
| Door created | `✅ Door created: Name \| By: Player` |
| Door updated | `🔄 Door updated: Name \| By: Player` |
| Door deleted | `🗑️ Door deleted: ID \| By: Player` |
| Price set | `💰 Price set: Name → $X \| By: Player` |
| Door renamed | `✏️ Door renamed: ID → NewName \| By: Player` |
| Access granted/revoked | `🔑 Access granted/revoked \| Name \| By: Player` |
| Door purchased | `💳 Door purchased: Name \| By: Player (CharID: X)` |
| Bell rung | `🔔 Bell rung at: Name \| By: Player` |
| Knock | `👊 Knock at: Name \| By: Player` |
| Group created | `✅ Group created: Name \| By: Player` |
| Group renamed | `✏️ Group renamed \| By: Player` |
| Group deleted | `🗑️ Group deleted \| By: Player` |
| Door added to group | `➕ Door added to group \| By: Player` |
| Door removed from group | `➖ Door removed from group \| By: Player` |

### Quick Setup

```bash
cd resources
git clone https://github.com/RedDragonElite/rde_nostr_log.git
cd rde_nostr_log
yarn install
```

```cfg
# server.cfg — ensure before rde_doors
ensure rde_nostr_log
```

---

## 🗄️ Database Schema

Tables are created automatically. For reference:

### `rde_owned_doors`

| Column | Type | Description |
|---|---|---|
| `id` | VARCHAR(50) | Unique door ID (generated) |
| `type` | VARCHAR(20) | `single` or `double` |
| `name` | VARCHAR(100) | Display name |
| `coords` | LONGTEXT | JSON `{x, y, z}` |
| `model` | VARCHAR(100) | Prop model name |
| `model_hash` | VARCHAR(50) | GetHashKey result |
| `locked` | TINYINT(1) | 1 = locked |
| `auth` | LONGTEXT | JSON array of group names |
| `autolock` | INT | Seconds until relock (0 = off) |
| `items` | LONGTEXT | JSON array of item names |
| `heading` | FLOAT | Door heading |
| `maxDistance` | FLOAT | Interaction range |
| `owner_charid` | VARCHAR(50) | Owning character ID |
| `owner_name` | VARCHAR(100) | Owning character name |
| `price` | INT | Purchase price (0 = not for sale) |
| `access_list` | LONGTEXT | JSON array of charIds with access |
| `group_id` | VARCHAR(50) | Door group ID (nullable) |
| `created_at` | TIMESTAMP | Creation time |
| `updated_at` | TIMESTAMP | Last update |

### `rde_door_groups`

| Column | Type | Description |
|---|---|---|
| `id` | VARCHAR(50) | Unique group ID |
| `name` | VARCHAR(100) | Group display name |
| `doors` | LONGTEXT | JSON array of door IDs |
| `created_at` | TIMESTAMP | Creation time |
| `updated_at` | TIMESTAMP | Last update |

---

## 🐛 Troubleshooting

### `attempt to index a number value (local 'player')` on `ox:playerLoaded`

This was a bug in older versions. The correct `ox:playerLoaded` server signature is:

```lua
-- CORRECT (v6.0.0+):
AddEventHandler('ox:playerLoaded', function(playerId, userId, charId)
    -- playerId = server source ID (number)
    -- userId   = user ID (number)
    -- charId   = character ID (number)
end)

-- WRONG (caused the crash):
AddEventHandler('ox:playerLoaded', function(source, player)
    player.charId  -- ❌ player is actually userId (a number), not a table!
end)
```

**Already fixed in this version.** If you see this error, make sure you're on the latest commit.

---

### `No such export log in resource rde_nostr_log`

The correct export name is `postLog`, not `log`:

```lua
-- CORRECT:
exports['rde_nostr_log']:postLog('Your message', {{'event', 'event_type'}})

-- WRONG:
exports['rde_nostr_log']:log(...)
```

Already fixed in v6.0.0+.

---

### Doors not syncing to players after restart

Run `/resyncdoors` in the server console. If doors still don't appear, check that `oxmysql` is fully started before `rde_doors` — adjust your `server.cfg` order.

---

### `MySQL not available` on startup

Ensure `oxmysql` is started before `rde_doors` in `server.cfg`:

```cfg
ensure oxmysql       # must come first
ensure rde_doors
```

---

### Door created but invisible in-game

The model must exist client-side. Double-check the `model` string matches an actual prop name (`prop_*` or a streamed custom model). Use `/doorinfo` while standing near the expected position to confirm the door was saved.

---

### Access always denied despite being admin

Verify your ACE setup:

```cfg
add_ace group.admin rde.doors.admin allow
add_principal identifier.steam:YOURSTEAMHEX group.admin
```

Or add your group to `Config.AdminSystem.oxGroups` in `config.lua`.

---

## 🗺️ Roadmap & Known Issues

This is an **alpha release**. The following is tracked and in active development:

### ❌ Known Issues (v1.0.0-alpha)

| Issue | Status |
|---|---|
| Double doors not syncing correctly | 🔧 In Progress |
| Autolock timer edge cases on server restart | 🔍 Investigating |

### 🔜 Planned for Stable Release

- ✅ Full double door support with correct heading sync
- ✅ Client-side door animation hooks
- ✅ ox_doorlock compatibility layer
- ✅ AETHER admin panel UI (NUI)
- ✅ Door sound effects (knock, bell, lock click)
- ✅ Expanded multi-language support

> Have a bug or feature request? [Open an issue](https://github.com/RedDragonElite/rde_doors/issues) — alpha feedback directly shapes the stable release.

---

## 📜 License

```
###################################################################################
#                                                                                 #
#      .:: RED DRAGON ELITE (RDE)  -  BLACK FLAG SOURCE LICENSE v6.66 ::.         #
#                                                                                 #
#   PROJECT:    RDE_DOORS v1.0.0-ALPHA (NEXT-LEVEL FIVEM DOOR SYSTEM)             #
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
|---|---|
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

<div align="center">

*"We build the future on the graves of paid resources."*

**REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**

🐉 Made with 🔥 by [Red Dragon Elite](https://rd-elite.com)

</div>
