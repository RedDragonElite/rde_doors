fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rde_doors'
author 'RDE Development'
version '2.0.0'
description 'Advanced Door Management System with State Bags and Proximity Loading for ox_core v3'

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

-- State Bags werden automatisch synchronisiert
-- Keine zusätzliche Konfiguration nötig