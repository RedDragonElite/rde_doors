serpentsbyte
△ ᛋᛅᚱᛒᛅᚾᛏᛋ ᛒᛁᛏᛅ ▽
· 2025-12-23

PREVIEW: https://www.instagram.com/p/DS6fpP1DuQ9/

🎮 What It Does (No Hype, Just Facts)

🔹 🔒 Real-Time Lock Sync – Doors lock/unlock instantly for all players. (Statebags + ox_core)

🔹 📋 Admin/Owner Menus – Full CRUD control with ox_lib UI and paging for 100+ doors.

🔹 🔑 Item-Based Access – Open doors with keys, keycards, or custom items (ox_inventory).

🔹 📁 Door Groups – Link doors (e.g., houses, businesses) and control them as one.

🔹 🔄 Real-Time Sync – All changes (locks, owners, prices) update instantly for everyone.

🔹 🔔 Knock/Ring System – NPCs/players react when you knock/ring (with sound effects).

🔹 📍 Teleport Function – Admins/owners teleport instantly to any door.

🔹 🏷 3D Text Labels – Floating owner, lock status, price, and group info above doors.

🔹 🛡 Triple Admin Check – ACE + ox_core groups + Steam IDs for security.

🔹 🔄 Auto-Lock/Unlock – Doors auto-lock after X seconds or unlock for specific groups.

🔹 ⚡️ Optimized Performance – Batched updates, proximity loading, and entity pooling for 200+ players
.
💻 How It Works (Tech Deep Dive)
📂 Clean File Structure
rde_doors/
├── fxmanifest.lua -- (ox_core, ox_lib, oxmysql)
├── config.lua -- (Settings, language, door types)
├── client.lua -- (UI, 3D text, ox_target menus)
└── server.lua -- (Logic, DB, statebags, permissions)

🗃 Smart Database
-- Doors (Auto-created)
CREATE TABLE rde_owned_doors (
id VARCHAR(50) PRIMARY KEY,
name VARCHAR(100) NOT NULL,
coords LONGTEXT NOT NULL, -- Serialized vector3
model VARCHAR(100) NOT NULL,
locked TINYINT(1) DEFAULT 1,
items LONGTEXT DEFAULT '[]' -- Required items (ox_inventory)
);

-- Door Groups (Auto-created)
CREATE TABLE rde_door_groups (
id VARCHAR(50) PRIMARY KEY,
name VARCHAR(100) NOT NULL,
doors LONGTEXT DEFAULT '[]' -- Array of door IDs
);

🔄 Instant Statebag Sync
-- Server → Client (Real-Time)
Entity(doorEntity).state.rde_door_data = {
locked = door.locked,
owner = door.owner_charid,
group = door.group_id
}

🛡 Secure Admin Checks
-- 3-Layer Security
if IsPlayerAceAllowed(source, 'rde.doors.admin') then return true end
if Ox.GetPlayer(source).getGroup('admin') then return true end
if steamId == Config.AdminSystem.steamIds[player] then return true end

🎮 Smooth ox_target Menus
exports.ox_target:addLocalEntity(doorEntity, {
{
name = 'door_admin_' .. doorId,
label = 'Admin Menu',
icon = 'fa-cog',
onSelect = function() OpenAdminMenu(doorId) end,
canInteract = function() return IsPlayerAdmin() end
}
})

⚡️ Performance First
Proximity Loading (Doors load only within 30m).
Batched Statebag Updates (Reduces network traffic).
Entity Pooling (Reuses door entities).
Debounced Events (Limits updates to 1 per second).
MySQL Caching (Reduces database queries).

📌 Current Status (2025)
✅ Core System (locks, statebags, permissions) – Stable
✅ Admin/Owner Menus (ox_lib + paging) – Tested
✅ Item & Group System – In Testing
✅ Real-Time Sync – Optimized
🔜 Knock/Ring NPC Reactions – Final Polish
🔜 Teleport & Physics – Refining

(No ETA. We release when it’s perfect.)

🎥"We’re building a FiveM door system so advanced, it’ll make you question reality. 🚪
✨ No release, no hype just pure dev passion. 👀"

#FiveM #GTARP #GameDev #ox_core #Statebags #RealTimeSync #NoPixel #GameTech #WIP #Coding #FiveMScripts #fy #fyp #foryou
