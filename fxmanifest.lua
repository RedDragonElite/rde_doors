fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rde_doors'
author 'RDE Development | SerpentsByte'
version '4.0.0'
description 'Advanced Door Management System — Double Doors, Sliding/Automatic Doors, Lockpick, Passcode, Autolock, Group+Grade Auth, Item Metadata, Custom Sounds, Hold Open, Hide UI, StateBags & Proximity Loading (ox_core v3)'

shared_scripts {
    '@ox_lib/init.lua',
    '@ox_core/lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_core',
    'ox_lib',
    'ox_target',
    'ox_inventory',
    'oxmysql'
}

-- Auto-Migration:
-- v3.0.0 → v4.0.0 wird automatisch beim Serverstart durchgeführt.
-- Alle neuen Spalten werden via ALTER TABLE hinzugefügt (Defaults).
-- Bestehende Türen funktionieren ohne Änderung weiter.
-- Downgrade v4.0.0 → v3.0.0 ist möglich: neue Spalten werden von v3 ignoriert.
