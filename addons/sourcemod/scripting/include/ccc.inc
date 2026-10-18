/**
 * This is the include file for Custom Chat Colors
 * https://forums.alliedmods.net/showthread.php?t=186695
 * To check that Custom Chat Colors is installed and running, verify that the "ccc" library exists
 */

#if defined _ccc_included
  #endinput
#endif
#define _ccc_included

#define CCC_V_MAJOR   "8"
#define CCC_V_MINOR   "0"
#define CCC_V_PATCH   "8"

#define CCC_VERSION            CCC_V_MAJOR..."."...CCC_V_MINOR..."."...CCC_V_PATCH

enum CCC_ColorType {
	CCC_TagColor,
	CCC_NameColor,
	CCC_ChatColor
};

#define COLOR_NULL		-1
#define COLOR_NONE		-2
#define COLOR_CGREEN	-3 //0x40FF40
#define COLOR_OLIVE		-4 //0x99FF99
#define COLOR_TEAM		-5
#define COLOR_NORMAL	-6

/**
 * Resolves a color key to the color string used in chat.
 * A valid hexadecimal key (Source 2009 engines only) is copied as is, any other key is
 * looked up as a MultiColors color name.
 *
 * @param key			Color key: a hexadecimal value or a MultiColors color name
 * @param color			Buffer to store the resolved color in
 * @param size			Size of the color buffer
 * @return				True if the key was a hexadecimal value, false if it was resolved as a color name
 */
native bool CCC_GetColor(char key[32], char[] color, int size);

/**
 * Gets the color key currently set for a client: a hexadecimal value or a MultiColors
 * color name (for example "green", "olive" or "teamcolor").
 *
 * @param client		Client index
 * @param type			Color type to retrieve
 * @param color			Buffer to store the color key in
 * @param size			Size of the color buffer
 * @return				True if a valid color key is set for this client and type, false otherwise
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native bool CCC_GetColorKey(int client, CCC_ColorType type, char[] color, int size);

/**
 * Sets a client's color for the current session only (nothing is saved to the database).
 *
 * @param client		Client index
 * @param type			Color type to set
 * @param color			Integer representation of the color (use StringToInt(input, 16) to convert a hexadecimal string) or one of the COLOR_* defines
 * @param alpha			Is the color specified with an alpha channel (RRGGBBAA)?
 * @return				1 if the color was updated, 0 otherwise
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native int CCC_SetColor(int client, CCC_ColorType type, int color, bool alpha);

/**
 * Gets a client's tag
 *
 * @param client		Client index
 * @param buffer		Buffer to store the tag in
 * @param maxlen		Maximum buffer length
 * @return				1 on success
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native int CCC_GetTag(int client, char[] buffer, int maxlen);

/**
 * Sets a client's tag for the current session only (nothing is saved to the database).
 * Tags longer than 31 characters are truncated.
 *
 * @param client		Client index
 * @param tag			String containing the new tag
 * @noreturn
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native void CCC_SetTag(int client, const char[] tag);

/**
 * Resets a client's color to the value in the config file.
 *
 * @param client		Client index
 * @param type			Color type to restore
 * @return				1 on success
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native int CCC_ResetColor(int client, CCC_ColorType type);

/**
 * Resets a client's tag to the value in the config file.
 *
 * @param client		Client index
 * @return				1 on success
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native int CCC_ResetTag(int client);

/**
 * Loads a client's tag and colors from the config file and the database.
 * Does nothing if the client's data is already loaded or the database is not connected,
 * call CCC_UnLoadClient first to force a reload.
 *
 * @param client		Client index
 * @noreturn
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native void CCC_LoadClient(int client);

/**
 * Marks a client's data as unloaded so that a following CCC_LoadClient reloads it
 * from the config file and the database.
 *
 * @param client		Client index
 * @noreturn
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native void CCC_UnLoadClient(int client);

/**
 * Reloads the configuration for all clients
 *
 * @noreturn
 *
 * On error/errors:		Failed to reload config
 */
native void CCC_ReloadConfig();

/**
 * Checks if client has ccc enabled (requires the Generic or Custom1 admin flag and the
 * feature to be toggled on for this client)
 *
 * @param client        Client Index
 * @return   true if client has, false otherwise
 */
native bool CCC_IsClientEnabled(int client);

/**
 * Called when a cilent's name is about to be colored
 * DO NOT START A NEW USERMESSAGE (i.e. PrintToChat, PrintToChatAll) WITHIN THIS FORWARD
 *
 * @param client		Client index
 * @return				Plugin_Handled to prevent coloring, Plugin_Continue to allow coloring
 */
//#pragma deprecated Use CCC_OnColor instead
//forward Action:CCC_OnNameColor(client);

/**
 * Called when a client's chat is about to be colored
 * DO NOT START A NEW USERMESSAGE (i.e. PrintToChat, PrintToChatAll) WITHIN THIS FORWARD
 *
 * @param client		Client index
 * @return				Plugin_Handled to prevent coloring, Plugin_Continue to allow coloring
 */
//#pragma deprecated Use CCC_OnColor instead
//forward Action:CCC_OnChatColor(client);

/**
 * Called when a client's name is about to be tagged
 * DO NOT START A NEW USERMESSAGE (i.e. PrintToChat, PrintToChatAll) WITHIN THIS FORWARD
 *
 * @param client		Client index
 * @return				Plugin_Handled to prevent tagging, Plugin_Continue to allow tagging
 */
//#pragma deprecated Use CCC_OnColor instead
//forward Action:CCC_OnTagApplied(client);

/**
 * Called when a client's name is about to be tagged
 * DO NOT START A NEW USERMESSAGE (i.e. PrintToChat, PrintToChatAll) WITHIN THIS FORWARD
 *
 * @param client		Client index
 * @param message		Chat message that will be printed
 * @param type			What type of color will be applied. If this is CCC_TagColor, it controls whether the tag will be applied at all, not whether the tag will be colored.
 * @return				Plugin_Handled to prevent coloring, Plugin_Continue to allow coloring
 */
//forward Action:CCC_OnColor(client, const String:message[], CCC_ColorType:type);

/**
 * Called when a message has been fully colored and will be sent, unless further plugins modify it through Simple Chat Processor
 *
 * @param client		Recieving client index
 * @param author		Author client index
 * @param message		Message
 * @return				Plugin_Handled to block message, Plugin_Continue to allow message
 */
forward Action CCC_OnChatMessage(int client, int author, const char[] message);

/**
 * Called when a client's colors and tag are about to be loaded from the config file
 * At this point, the client has NO COLORS
 *
 * @param client		Client index
 * @return				Plugin_Handled or Plugin_Stop to prevent loading, Plugin_Continue or Plugin_Changed to allow
 */
forward Action CCC_OnUserConfigPreLoaded(int client);

/**
 * Called when a client's colors and tag have been loaded from the config file
 *
 * @param client		Client index
 * @noreturn
 */
forward void CCC_OnUserConfigLoaded(int client);

/**
 * Called when the configuration file is reloaded with the sm_reloadccc command
 *
 * @noreturn
 */
forward void CCC_OnConfigReloaded();

/**
 * Sets Ignored value of a specific client to a specific target, this will ignore chat messages.
 *
 * @param client		The client index
 * @param target		The target index
 * @param ignored		The ignorance value, true/false
 * @noreturn
 *
 * On error/errors:		Client or target is invalid
 */
native void CCC_SetIgnored(int client, int target, bool ignored);

public SharedPlugin __pl_ccc =
{
	name = "ccc",
	file = "CustomChatColors.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_ccc_SetNTVOptional() {
	MarkNativeAsOptional("CCC_UnLoadClient");
	MarkNativeAsOptional("CCC_LoadClient");
	MarkNativeAsOptional("CCC_ReloadConfig");
	MarkNativeAsOptional("CCC_GetColor");
	MarkNativeAsOptional("CCC_GetColorKey");
	MarkNativeAsOptional("CCC_SetColor");
	MarkNativeAsOptional("CCC_GetTag");
	MarkNativeAsOptional("CCC_SetTag");
	MarkNativeAsOptional("CCC_ResetColor");
	MarkNativeAsOptional("CCC_ResetTag");
	MarkNativeAsOptional("CCC_SetIgnored");
	MarkNativeAsOptional("CCC_IsClientEnabled");
}
#endif
