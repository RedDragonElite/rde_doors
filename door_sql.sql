-- ============================================
-- RDE Doors - Database Schema v3.0.0
-- Compatible with ox_core v3
-- ============================================
-- ⚠️  This file is for REFERENCE only.
-- The resource creates and migrates the schema automatically on startup.
-- You do NOT need to run this manually on a fresh install.
--
-- For existing installs upgrading from v2.x:
-- The server will auto-add the 'double_door_data' column via ALTER TABLE.
-- Your existing 1100+ doors remain fully intact — zero data loss.
-- ============================================

CREATE TABLE IF NOT EXISTS `rde_owned_doors` (
    `id`               VARCHAR(50)  PRIMARY KEY,
    `type`             VARCHAR(20)  DEFAULT 'single',
    `name`             VARCHAR(100) NOT NULL,
    `coords`           LONGTEXT     NOT NULL,
    `model`            VARCHAR(100) NOT NULL DEFAULT '',
    `model_hash`       VARCHAR(50),
    `locked`           TINYINT(1)   DEFAULT 1,
    `auth`             LONGTEXT     DEFAULT '[]',
    `autolock`         INT          DEFAULT 0,
    `items`            LONGTEXT     DEFAULT '[]',
    `heading`          FLOAT        DEFAULT 0.0,
    `maxDistance`      FLOAT        DEFAULT 2.5,
    `owner_charid`     VARCHAR(50),
    `owner_name`       VARCHAR(100),
    `price`            INT          DEFAULT 0,
    `access_list`      LONGTEXT     DEFAULT '[]',
    `group_id`         VARCHAR(50),
    `double_door_data` LONGTEXT     DEFAULT NULL,  -- NEW in v3.0.0: JSON {door_a:{model,coords,heading}, door_b:{...}}
    `created_at`       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    `updated_at`       TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rde_door_groups` (
    `id`         VARCHAR(50)  PRIMARY KEY,
    `name`       VARCHAR(100) NOT NULL,
    `doors`      LONGTEXT     DEFAULT '[]',
    `created_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_owner_charid ON rde_owned_doors(owner_charid);
CREATE INDEX IF NOT EXISTS idx_locked       ON rde_owned_doors(locked);
CREATE INDEX IF NOT EXISTS idx_price        ON rde_owned_doors(price);
CREATE INDEX IF NOT EXISTS idx_type         ON rde_owned_doors(type);

-- ============================================
-- EXAMPLE DOORS (optional — uses INSERT IGNORE so safe to run multiple times)
-- ============================================

-- Single door example
INSERT IGNORE INTO `rde_owned_doors` (`id`, `name`, `coords`, `model`, `locked`, `auth`, `price`)
VALUES ('door_police_main', 'LSPD Main Entrance',
    '{"x":434.7,"y":-981.91,"z":30.69}', 'v_ilev_ph_gendoor004', 1, '["police"]', 0);

-- Double door example (door_a + door_b stored as JSON in double_door_data)
-- coords = midpoint between the two sub-doors
INSERT IGNORE INTO `rde_owned_doors`
    (`id`, `name`, `type`, `coords`, `model`, `locked`, `auth`, `price`, `double_door_data`)
VALUES (
    'door_bank_double_main',
    'Fleeca Bank Double Entrance',
    'double',
    '{"x":311.48,"y":-284.49,"z":54.16}',
    '',
    1, '[]', 0,
    '{"door_a":{"model":"v_ilev_bk_door","coords":{"x":311.28,"y":-284.49,"z":54.16},"heading":0.0},"door_b":{"model":"v_ilev_bk_door","coords":{"x":311.68,"y":-284.49,"z":54.16},"heading":180.0}}'
);
