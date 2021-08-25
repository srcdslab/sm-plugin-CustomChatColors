/**
 * This is the include file for Custom Chat Colors
 * https://forums.alliedmods.net/showthread.php?t=186695
 * To check that Custom Chat Colors is installed and running, verify that the "ccc" library exists
 */

#if defined _ccc_included
  #endinput
#endif
#define _ccc_included

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
 * Gets a client's color as a hexadecimal integer.
 *
 * @param client		Client index
 * @param type			Color type to retreive
 * @param color			Color string buffer
 * @param size			Size of color string buffer
 * @return				Is the color an hex value
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native bool CCC_GetColor(char key[32], char[] color, int size);

/**
 * Gets a client's color as a hexadecimal integer.
 *
 * @param client		Client index
 * @param type			Color type to retreive
 * @param color			Color string buffer
 * @param size			Size of color string buffer
 * @return				Is a key set for this client
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native bool CCC_GetColorKey(int client, CCC_ColorType type, char[] color, int size);

/**
 * Sets a client's color as a hexadecimal integer.
 *
 * @param client		Client index
 * @param type			Color type to set
 * @param color			Integer representation of the color (use StringToInt(input, 16) to convert a hexadecimal string) or one of the color defines
 * @param alpha			Are you specifying a color with alpha?
 * @return				True if the color is updated successfully, false otherwise
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
 * @noreturn
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native int CCC_GetTag(int client, char[] buffer, int maxlen);

/**
 * Sets a client's tag
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
 * @noreturn
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native int CCC_ResetColor(int client, CCC_ColorType type);

/**
 * Resets a client's tag to the value in the config file.
 *
 * @param client		Client index
 * @noreturn
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native int CCC_ResetTag(int client);

/**
 * Sets a client's tag
 *
 * @param client		Client index
 * @noreturn
 *
 * On error/errors:		Invalid client index or client is not in game
 */
native void CCC_LoadClient(int client);

/**
 * Unsets a client's tag
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

native int CCC_UpdateIgnoredArray(bool IgnoredArray[(MAXPLAYERS + 1) * (MAXPLAYERS + 1)]);

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
	MarkNativeAsOptional("CCC_GetColor");
	MarkNativeAsOptional("CCC_SetColor");
	MarkNativeAsOptional("CCC_GetTag");
	MarkNativeAsOptional("CCC_ResetTag");
	MarkNativeAsOptional("CCC_ResetColor");
	MarkNativeAsOptional("CCC_ResetTag");
	MarkNativeAsOptional("CCC_UpdateIgnoredArray");
}
#endif