# rde_doors

Door System Script for ESX Legacy
This script is designed to manage doors within an ESX Legacy framework, providing functionalities for creating, 
deleting, and interacting with doors. It includes features for admin management, player interactions, and debugging.

Features
Door Management: Create, delete, and manage doors.
Access Control: Control who can interact with doors based on ownership and admin rights.
Interaction: Players can interact with doors to view information, lock/unlock, buy, and manage access.
Debugging: Toggle debug mode to print detailed logs for troubleshooting.

Installation:

Place the script in your ESX server's resource directory.
Ensure you have the necessary dependencies like ox_target and lib.
Configure:

Update the Config.lua file with your server's specific settings.
Ensure the Config.AdminGroups and other configurations are set according to your server's requirements.

Start the Resource:

Add the resource to your server's configuration file.
Start the resource using your server's resource management commands.
Configuration
Config.lua

Config = {}

Config.DEBUG = false -- Set to true to enable debug mode
Config.AdminGroups = {
    ['admin'] = true,
    ['superadmin'] = true
}
Config.Strings = {
    ['set_door'] = 'Set Door Information',
    ['delete_door'] = 'Delete Door',
    ['manage_access'] = 'Manage Access',
    ['sell_door'] = 'Sell Door',
    ['buy_door'] = 'Buy Door'
}

Usage

Commands:

/createdoor: Admin command to create a door.
/debugdoors: Toggle debug mode.
/testdoors: Test command to scan and print nearby objects.

Events:

esx:playerLoaded: Loads player data and initializes doors.
esx:setPlayerData: Updates player data and reloads doors if necessary.
door_system:updateDoorTarget: Updates door target options.
door_system:updateDoors: Updates the list of doors.
door_system:setDoorState: Sets the door state (locked/unlocked).

Functions:

debugPrint(...): Prints debug messages if debug mode is active.
isDoorModel(modelName): Checks if a model name contains door/gate keywords.
getDoorInfo(entity): Gets door position and rotation from an entity.
ShowNotification(msg): Shows a notification to the player.
clearTargetZones(): Removes existing target zones.
hasAccess(door): Checks if the player has access to a door.
SetDoorState(doorId, state): Locks or unlocks the door object.
DrawText3D(x, y, z, text): Draws 3D text in the game world.
setupDoorTarget(): Sets up door target interactions.
CreateDoorTarget(doorId, coords, modelName, locked): Creates a target zone for a door.
LoadDoors(): Loads doors from the server.

Debugging:

Debug Mode: Toggle debug mode using the /debugdoors command to print detailed logs for troubleshooting.
Debug Prints: Detailed print statements are included throughout the script to help identify issues.

Release Notes:

Version v0.5.0 ALPHA
Initial release with door management features.
Admin commands for creating and deleting doors.
Player interactions for viewing door information, locking/unlocking, buying, and managing access.
Debug mode for troubleshooting.

Contributing:
Contributions are welcome! Please fork the repository and submit a pull request with your changes.

License
This project is licensed under the MIT License. See the LICENSE file for details.

Contact
For any questions or support, please contact [your email or support channel].
