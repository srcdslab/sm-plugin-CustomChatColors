#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <regex>
#include <multicolors>
#include <adminmenu>
#include <basecomm>
#include <clientprefs>
#include <ccc>

#undef REQUIRE_PLUGIN
#tryinclude <SelfMute>
#tryinclude <sourcecomms>
#tryinclude <DynamicChannels>
#define REQUIRE_PLUGIN

#define DATABASE_NAME					"ccc"

#define MAX_CHAT_TRIGGER_LENGTH			32
#define MAX_CHAT_LENGTH					256

#define REPLACE_LIST_MAX_LENGTH			255

#define MAX_SQL_QUERY_LENGTH			1024

#define CHAT_SYMBOL '@'

public Plugin myinfo =
{
	name        = "Custom Chat Colors & Tags & Allchat",
	author      = "Dr. McKay, edit by id/Obus, BotoX, maxime1907, .Rushaway",
	description = "Processes chat and provides colors & custom tags & allchat & chat ignoring",
	version     = CCC_VERSION,
	url         = "http://www.doctormckay.com"
};

Handle preLoadedForward;
Handle loadedForward;
Handle configReloadedForward;

ConVar g_cvar_GreenText;
ConVar g_cvar_ReplaceText;

ConVar g_cvar_SQLRetryTime;
ConVar g_cvar_SQLMaxRetries;

ConVar g_cSmCategoryColor;
ConVar g_cSmNameColor;
ConVar g_cSmChatColor;
ConVar g_cvPsayCooldown;
ConVar g_cvPsayPrivacy;
ConVar g_cvHUDChannel;

ConVar g_Cvar_Chatmode;

ConVar g_cvar_DBConnectDelay;

char g_sSmCategoryColor[32];
char g_sSmNameColor[32];
char g_sSmChatColor[32];

char g_sReplaceList[REPLACE_LIST_MAX_LENGTH][2][MAX_CHAT_LENGTH];
int g_iReplaceListSize = 0;

char g_sClientSID[MAXPLAYERS + 1][32];
char g_sSteamIDs[MAXPLAYERS + 1][MAX_AUTHID_LENGTH];

int g_iClientEnable[MAXPLAYERS + 1] = { 1, ...};
char g_sClientTag[MAXPLAYERS + 1][64];
char g_sClientTagColor[MAXPLAYERS + 1][32];
char g_sClientNameColor[MAXPLAYERS + 1][32];
char g_sClientChatColor[MAXPLAYERS + 1][32];

int g_iDefaultClientEnable[MAXPLAYERS + 1] = { 1, ... };
char g_sDefaultClientTag[MAXPLAYERS + 1][32];
char g_sDefaultClientTagColor[MAXPLAYERS + 1][12];
char g_sDefaultClientNameColor[MAXPLAYERS + 1][12];
char g_sDefaultClientChatColor[MAXPLAYERS + 1][12];

ArrayList g_sColorsArray = null;

int g_iClientBanned[MAXPLAYERS + 1] = { -1, ...};
bool g_bWaitingForChatInput[MAXPLAYERS + 1];
char g_sReceivedChatInput[MAXPLAYERS + 1][64];
char g_sInputType[MAXPLAYERS + 1][32];
char g_sATargetSID[MAXPLAYERS + 1][64];
int g_iATarget[MAXPLAYERS + 1];

/* Database connection state */
enum DatabaseState {
	DatabaseState_Disconnected = 0,
	DatabaseState_Wait,
	DatabaseState_Connecting,
	DatabaseState_Connected,
}
DatabaseState g_DatabaseState;

Handle g_hReconnectTimer = null;
Database g_hDatabase;
int g_iConnectLock = 0;
int g_iSequence = 0;

int g_msgAuthor;
bool g_msgIsChat;
char g_msgName[128];
char g_msgSender[128];
char g_msgText[MAX_CHAT_LENGTH];
char g_msgFinal[255];
bool g_msgIsTeammate;

bool g_Ignored[(MAXPLAYERS + 1) * (MAXPLAYERS + 1)] = {false, ...};

int g_bSQLSelectReplaceRetry = 0;
int g_bSQLInsertReplaceRetry[MAXPLAYERS + 1] = { 0, ... };
int g_bSQLDeleteReplaceRetry[MAXPLAYERS + 1] = { 0, ... };

int g_bSQLSelectBanRetry[MAXPLAYERS + 1] = { 0, ... };
int g_bSQLInsertBanRetry[MAXPLAYERS + 1] = { 0, ... };
int g_bSQLDeleteBanRetry[MAXPLAYERS + 1] = { 0, ... };

int g_bSQLSelectTagGroupRetry[MAXPLAYERS + 1] = { 0, ... };
int g_bSQLSelectTagRetry[MAXPLAYERS + 1] = { 0, ... };
int g_bSQLUpdateTagRetry[MAXPLAYERS + 1] = { 0, ... };
int g_bSQLInsertTagRetry[MAXPLAYERS + 1] = { 0, ... };
int g_bSQLDeleteTagRetry[MAXPLAYERS + 1] = { 0, ... };

char g_ColorNames[13][10] = {"White", "Red", "Green", "Blue", "Yellow", "Purple", "Cyan", "Orange", "Pink", "Olive", "Lime", "Violet", "Lightblue"};
int g_Colors[13][3] = {{255,255,255},{255,0,0},{0,255,0},{0,0,255},{255,255,0},{255,0,255},{0,255,255},{255,128,0},{255,0,128},{128,255,0},{0,255,128},{128,0,255},{0,128,255}};

bool g_bSQLite = true;
bool g_bLate = false;
bool g_bPlugin_DynamicChannels = false;
bool g_bDynamicNative = false;
bool g_bPlugin_SelfMute = false;
bool g_bSelfMuteNative = false;
bool g_bPlugin_SourceComms = false;
bool g_bSourceCommsNative = false;

bool g_bProto;

Handle g_hCookie_DisablePsay;
int g_iClientPsayCooldown[MAXPLAYERS + 1] = { 0, ... };
int g_iClientFastReply[MAXPLAYERS + 1] = { 0, ... };
bool g_bDisablePsay[MAXPLAYERS + 1];

bool g_bDBConnectDelayActive = false;
bool g_bClientDataLoaded[MAXPLAYERS + 1] = {false, ...};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Updater_AddPlugin");

	CreateNative("CCC_UnLoadClient", Native_UnLoadClient);
	CreateNative("CCC_LoadClient", Native_LoadClient);
	CreateNative("CCC_ReloadConfig", Native_ReloadConfig);

	CreateNative("CCC_GetColorKey", Native_GetColorKey);
	CreateNative("CCC_GetColor", Native_GetColor);
	CreateNative("CCC_SetColor", Native_SetColor);
	CreateNative("CCC_GetTag", Native_GetTag);
	CreateNative("CCC_SetTag", Native_SetTag);
	CreateNative("CCC_ResetColor", Native_ResetColor);
	CreateNative("CCC_ResetTag", Native_ResetTag);

	CreateNative("CCC_UpdateIgnoredArray", Native_UpdateIgnoredArray);
	CreateNative("CCC_IsClientEnabled", Native_IsClientEnabled);

	RegPluginLibrary("ccc");

	g_bLate = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("allchat.phrases");

	UserMsg SayText2 = GetUserMessageId("SayText2");

	if (SayText2 == INVALID_MESSAGE_ID)
	{
		SetFailState("This game doesn't support SayText2 user messages.");
	}

	HookUserMessage(SayText2, Hook_UserMessage, true);
	HookEvent("player_say", Event_PlayerSay);

	RegAdminCmd("sm_cccimportreplacefile", Command_CCCImportReplaceFile, ADMFLAG_CONFIG, "Import a chat replace config from file");
	RegAdminCmd("sm_cccaddtag", Command_CCCAddTag, ADMFLAG_CONFIG, "Adds a tag entry");
	RegAdminCmd("sm_cccdeletetag", Command_CCCDeleteTag, ADMFLAG_CONFIG, "Deletes a tag entry");
	RegAdminCmd("sm_cccaddtrigger", Command_CCCAddTrigger, ADMFLAG_CONFIG, "Adds a chat trigger (Example: \":lenny:\"");
	RegAdminCmd("sm_cccdeletetrigger", Command_CCCDeleteTrigger, ADMFLAG_CONFIG, "Deletes a chat trigger (Example: \":lenny:\"");
	RegAdminCmd("sm_reloadccc", Command_ReloadConfig, ADMFLAG_CONFIG, "Reloads Custom Chat Colors config file");
	RegAdminCmd("sm_forcetag", Command_ForceTag, ADMFLAG_CHEATS, "Forcefully changes a clients custom tag");
	RegAdminCmd("sm_forcetagcolor", Command_ForceTagColor, ADMFLAG_CHEATS, "Forcefully changes a clients custom tag color");
	RegAdminCmd("sm_forcenamecolor", Command_ForceNameColor, ADMFLAG_CHEATS, "Forcefully changes a clients name color");
	RegAdminCmd("sm_forcetextcolor", Command_ForceTextColor, ADMFLAG_CHEATS, "Forcefully changes a clients chat text color");
	RegAdminCmd("sm_cccreset", Command_CCCReset, ADMFLAG_SLAY, "Resets a users custom tag, tag color, name color and chat text color");
	RegAdminCmd("sm_cccban", Command_CCCBan, ADMFLAG_SLAY, "Bans a user from changing his custom tag, tag color, name color and chat text color");
	RegAdminCmd("sm_cccunban", Command_CCCUnban, ADMFLAG_SLAY, "Unbans a user and allows for change of his tag, tag color, name color and chat text color");
	RegAdminCmd("sm_tagmenu", Command_TagMenu, ADMFLAG_CUSTOM1, "Shows the main \"tag & colors\" menu");
	RegAdminCmd("sm_tag", Command_SetTag, ADMFLAG_CUSTOM1, "Changes your custom tag");
	RegAdminCmd("sm_tags", Command_TagMenu, ADMFLAG_CUSTOM1, "Shows the main \"tag & colors\" menu");
	RegAdminCmd("sm_cleartag", Command_ClearTag, ADMFLAG_CUSTOM1, "Clears your custom tag");
	RegAdminCmd("sm_tagcolor", Command_SetTagColor, ADMFLAG_CUSTOM1, "Changes the color of your custom tag");
	RegAdminCmd("sm_cleartagcolor", Command_ClearTagColor, ADMFLAG_CUSTOM1, "Clears the color from your custom tag");
	RegAdminCmd("sm_namecolor", Command_SetNameColor, ADMFLAG_CUSTOM1, "Changes the color of your name");
	RegAdminCmd("sm_clearnamecolor", Command_ClearNameColor, ADMFLAG_CUSTOM1, "Clears the color from your name");
	RegAdminCmd("sm_textcolor", Command_SetTextColor, ADMFLAG_CUSTOM1, "Changes the color of your chat text");
	RegAdminCmd("sm_chatcolor", Command_SetTextColor, ADMFLAG_CUSTOM1, "Changes the color of your chat text");
	RegAdminCmd("sm_cleartextcolor", Command_ClearTextColor, ADMFLAG_CUSTOM1, "Clears the color from your chat text");
	RegAdminCmd("sm_clearchatcolor", Command_ClearTextColor, ADMFLAG_CUSTOM1, "Clears the color from your chat text");
	RegAdminCmd("sm_toggletag", Command_ToggleTag, ADMFLAG_CUSTOM1, "Toggles whether or not your tag and colors show in the chat");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	g_hCookie_DisablePsay = RegClientCookie("disable_psay", "", CookieAccess_Private);
	RegConsoleCmd("sm_enablepsay", OnToggleCCCSettings);
	RegConsoleCmd("sm_disablepsay", OnToggleCCCSettings);
	SetCookieMenuItem(MenuHandler_CookieMenu, 0, "CustomChatColors");

	// Override base chat
	g_Cvar_Chatmode = CreateConVar("sm_chat_mode", "1", "Allows player's to send messages to admin chat.", 0, true, 0.0, true, 1.0);

	RegAdminCmd("sm_say", Command_SmSay, ADMFLAG_CHAT, "sm_say <message> - sends message to all players");
	RegAdminCmd("sm_csay", Command_SmCsay, ADMFLAG_CHAT, "sm_csay <message> - sends centered message to all players");

	/* HintText does not work on Dark Messiah */
	if (GetEngineVersion() != Engine_DarkMessiah)
		RegAdminCmd("sm_hsay", Command_SmHsay, ADMFLAG_CHAT, "sm_hsay <message> - sends hint message to all players");

	RegAdminCmd("sm_dsay", Command_SmDsay, ADMFLAG_CHAT, "sm_dsay <message> - sends hud message to all players");
	RegAdminCmd("sm_tsay", Command_SmTsay, ADMFLAG_CHAT, "sm_tsay [color] <message> - sends top-left message to all players");
	RegAdminCmd("sm_chat", Command_SmChat, ADMFLAG_CHAT, "sm_chat <message> - sends message to admins");
	RegAdminCmd("sm_psay", Command_SmPsay, ADMFLAG_CHAT, "sm_psay <name or #userid> <message> - sends private message");
	RegAdminCmd("sm_pstatus", Command_PsayStatus, ADMFLAG_CHAT, "sm_pstatus <name or #userid> - check private message status");
	RegAdminCmd("sm_r", Command_SmPsayReply, ADMFLAG_CHAT, "sm_psay <message> - reply to your latest private message");
	RegAdminCmd("sm_msay", Command_SmMsay, ADMFLAG_CHAT, "sm_msay <message> - sends message as a menu panel");

	g_cvar_GreenText = CreateConVar("sm_ccc_green_text", "1", "Enables greentexting (First chat character must be \">\")", FCVAR_REPLICATED);
	g_cvar_ReplaceText = CreateConVar("sm_ccc_replace", "1", "Enables text replacing", FCVAR_REPLICATED);

	g_cvar_DBConnectDelay = CreateConVar("sm_ccc_db_connect_delay", "0.0", "Delay in seconds before connecting to the database (0.0 = instant, max 60.0)", FCVAR_NONE, true, 0.0, true, 60.0);
	g_cvar_SQLRetryTime = CreateConVar("sm_ccc_sql_retry_time", "10.0", "Number of seconds to wait before a new retry on a failed query", FCVAR_REPLICATED);
	g_cvar_SQLMaxRetries = CreateConVar("sm_ccc_sql_max_retries", "1", "Number of sql retries on all queries if one fails", FCVAR_REPLICATED);

	g_cSmCategoryColor = CreateConVar("sm_ccc_sm_category_color", "{green}", "Color used for SM categories (ADMINS, ALL, Private to)", FCVAR_REPLICATED);
	g_cSmNameColor = CreateConVar("sm_ccc_sm_name_color", "{fullred}", "Color used for SM player name", FCVAR_REPLICATED);
	g_cSmChatColor = CreateConVar("sm_ccc_sm_chat_color", "{cyan}", "Color used for SM chat", FCVAR_REPLICATED);
	g_cvPsayCooldown = CreateConVar("sm_ccc_psay_cooldown", "4", "Cooldown between two usage of sm_psay", FCVAR_REPLICATED);
	g_cvPsayPrivacy = CreateConVar("sm_ccc_psay_privacy", "1", "Hide to admins all usage of sm_psay", FCVAR_PROTECTED);
	g_cvHUDChannel = CreateConVar("sm_ccc_hud_channel", "0", "The channel for the hud if using DynamicChannels", _, true, 0.0, true, 5.0);

	preLoadedForward = CreateGlobalForward("CCC_OnUserConfigPreLoaded", ET_Event, Param_Cell);
	loadedForward = CreateGlobalForward("CCC_OnUserConfigLoaded", ET_Ignore, Param_Cell);
	configReloadedForward = CreateGlobalForward("CCC_OnConfigReloaded", ET_Ignore);

	g_bProto = CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf;

	AutoExecConfig(true);

	ResetReplace();
	LoadColorArray();

	if (g_bLate)
		LateLoad();
}

public void OnPluginEnd()
{
	// Clean up on map end just so we can start a fresh connection when we need it later.
	if (g_hDatabase != null)
	{
		delete g_hDatabase;
		g_hDatabase = null;
	}
	if (g_sColorsArray != null)
		delete g_sColorsArray;

	g_DatabaseState = DatabaseState_Disconnected;
	g_hDatabase = null;
	g_hReconnectTimer = null;
	g_bDBConnectDelayActive = false;
}

public void OnAllPluginsLoaded()
{
	g_bPlugin_SelfMute = LibraryExists("SelfMute");
	g_bPlugin_SourceComms = LibraryExists("sourcecomms++");
	g_bPlugin_DynamicChannels = LibraryExists("DynamicChannels");
	VerifyNatives();

	// We dont need basechat as we already implemented our version with color support
	char sBaseChatPlugin[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sBaseChatPlugin, sizeof(sBaseChatPlugin), "plugins/basechat.smx");
	if (!FileExists(sBaseChatPlugin))
		return;

	ServerCommand("sm plugins unload basechat");

	char sBaseChatPluginDisabled[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sBaseChatPluginDisabled, sizeof(sBaseChatPluginDisabled), "plugins/disabled/basechat.smx");

	RenameFile(sBaseChatPluginDisabled, sBaseChatPlugin);
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "SelfMute", false) == 0)
	{
		g_bPlugin_SelfMute = true;
		VerifyNative_SelfMute();
	}
	else if (strcmp(name, "sourcecomms++", false) == 0)
	{
		g_bPlugin_SourceComms = true;
		VerifyNative_SourceCommsPP();
	}
	else if (strcmp(name, "DynamicChannels", false) == 0)
	{
		g_bPlugin_DynamicChannels = true;
		VerifyNative_DynamicChannel();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "SelfMute", false) == 0)
	{
		g_bPlugin_SelfMute = false;
		VerifyNative_SelfMute();
	}
	else if (strcmp(name, "sourcecomms++", false) == 0)
	{
		g_bPlugin_SourceComms = false;
		VerifyNative_SourceCommsPP();
	}
	else if (strcmp(name, "DynamicChannels", false) == 0)
	{
		g_bPlugin_DynamicChannels = false;
		VerifyNative_DynamicChannel();
	}
}

stock void VerifyNatives()
{
	VerifyNative_SelfMute();
	VerifyNative_SourceCommsPP();
	VerifyNative_DynamicChannel();
}

stock void VerifyNative_SelfMute()
{
	g_bSelfMuteNative = g_bPlugin_SelfMute && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SelfMute_GetSelfMute") == FeatureStatus_Available;
}

stock void VerifyNative_SourceCommsPP()
{
	g_bSourceCommsNative = g_bPlugin_SourceComms && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SourceComms_GetClientGagType") == FeatureStatus_Available;
}

stock void VerifyNative_DynamicChannel()
{
	g_bDynamicNative = g_bPlugin_DynamicChannels && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetDynamicChannel") == FeatureStatus_Available;
}

public void OnConfigsExecuted()
{
	float fDelay = g_cvar_DBConnectDelay.FloatValue;
	if (fDelay > 0.0)
	{
		g_bDBConnectDelayActive = true;
		CreateTimer(fDelay, Timer_DelayedDBConnectCCC, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		g_bDBConnectDelayActive = false;
		DB_Connect();
	}

	g_cSmCategoryColor.GetString(g_sSmCategoryColor, sizeof(g_sSmCategoryColor));
	g_cSmNameColor.GetString(g_sSmNameColor, sizeof(g_sSmNameColor));
	g_cSmChatColor.GetString(g_sSmChatColor, sizeof(g_sSmChatColor));
}

public void OnClientDisconnect(int client)
{
	g_bClientDataLoaded[client] = false;
	g_iClientPsayCooldown[client] = 0;
	g_iClientFastReply[client] = -1;
	g_sSteamIDs[client][0] = '\0';
}

public void OnClientPostAdminCheck(int client)
{
	if (g_bClientDataLoaded[client])
		return;

	if (g_DatabaseState != DatabaseState_Connected)
		return;

	ResetClient(client);

	char auth[MAX_AUTHID_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
	FormatEx(g_sSteamIDs[client], sizeof(g_sSteamIDs[]), "%s", auth);

	ConfigForward(client);

	if (HasFlag(client, Admin_Custom1))
	{
		SQLSelect_TagClient(GetClientUserId(client));
		DataPack banPack = new DataPack();
		banPack.WriteCell(GetClientUserId(client));
		banPack.WriteString(g_sSteamIDs[client]);
		SQLSelect_Ban(INVALID_HANDLE, banPack);
	}
	else if (HasFlag(client, Admin_Generic))
	{
		char sClientFlagString[64];
		GetClientFlagString(client, sClientFlagString, sizeof(sClientFlagString));

		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(g_sSteamIDs[client]);
		pack.WriteString(sClientFlagString);

		SQLSelect_TagGroup(INVALID_HANDLE, pack);
	}
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
		return;

	char sBuffer[16];
	GetClientCookie(client, g_hCookie_DisablePsay, sBuffer, sizeof(sBuffer));
	g_bDisablePsay[client] = StringToInt(sBuffer) != 0;
}

stock void LateLoad()
{
	ResetReplace();

	SQLSelect_Replace(INVALID_HANDLE);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (AreClientCookiesCached(i))
			OnClientCookiesCached(i);

		OnClientPostAdminCheck(i);
	}
}

stock void LoadColorArray()
{
	StringMap smTrie = CGetTrie();
	StringMapSnapshot smTrieSnapshot = smTrie.Snapshot();
	if (smTrie != null)
	{
		if (g_sColorsArray != null)
			delete g_sColorsArray;

		g_sColorsArray = new ArrayList(smTrie.Size);

		for (int i = 0; i < smTrie.Size; i++)
		{
			char key[64];

			smTrieSnapshot.GetKey(i, key, sizeof(key));

			g_sColorsArray.PushString(key);
		}
	}
	SortColors();
}

stock void SortColors()
{
	if (g_sColorsArray == null)
		return;

	char temp[64];

	// Sorting strings using bubble sort
	for (int j = 0; j < g_sColorsArray.Length - 1; j++)
	{
		for (int i = j + 1; i < g_sColorsArray.Length; i++)
		{
			char keyJ[64];
			char keyI[64];
			g_sColorsArray.GetString(j, keyJ, sizeof(keyJ));
			g_sColorsArray.GetString(i, keyI, sizeof(keyI));
			if (strcmp(keyJ, keyI) > 0)
			{
				Format(temp, sizeof(temp), "%s", keyJ);
				Format(keyJ, sizeof(keyJ), "%s", keyI);
				Format(keyI, sizeof(keyI), "%s", temp);
				g_sColorsArray.SetString(j, keyJ);
				g_sColorsArray.SetString(i, keyI);
			}
		}
	}
}

stock void ResetReplace()
{
	for (int i = 0; i < REPLACE_LIST_MAX_LENGTH; i++)
	{
		g_sReplaceList[i][0] = "";
		g_sReplaceList[i][1] = "";
	}
	g_iReplaceListSize = 0;
}

///////////
/// SQL ///
///////////

stock bool DB_Connect()
{
	if (g_bDBConnectDelayActive)
		return false;

	//PrintToServer("DB_Connect(handle %d, state %d, lock %d)", g_hDatabase, g_DatabaseState, g_iConnectLock);

	if (g_hDatabase != null && g_DatabaseState == DatabaseState_Connected)
		return true;

	// 100500 connections in a minute is bad idea..
	if (g_DatabaseState == DatabaseState_Wait)
		return false;

	if (g_DatabaseState != DatabaseState_Connecting)
	{
		if (!SQL_CheckConfig(DATABASE_NAME))
			SetFailState("Could not find \"%s\" entry in databases.cfg.", DATABASE_NAME);

		g_DatabaseState = DatabaseState_Connecting;
		g_iConnectLock = ++g_iSequence;
		Database.Connect(OnSQLConnected, DATABASE_NAME, g_iConnectLock);
	}

	return false;
}

stock void OnSQLConnected(Database db, const char[] err, any data)
{
	// See if the connection is valid.
	if (db == null)
	{
		LogError("Connecting to database \"%s\" failed: %s", DATABASE_NAME, err);
		return;
	}

	LogMessage("Connected to database.");

	// If this happens to be an old connection request, ignore it.
	if (data != g_iConnectLock || (g_hDatabase != null && g_DatabaseState == DatabaseState_Connected))
	{
		if (db)
			delete db;
		return;
	}

	g_iConnectLock = 0;
	g_DatabaseState = DatabaseState_Connected;
	g_hDatabase = db;

	char sDriver[16];
	SQL_GetDriverIdent(SQL_ReadDriver(g_hDatabase), sDriver, sizeof(sDriver));

	if (!strncmp(sDriver, "my", 2, false))
		g_bSQLite = false;
	else
		g_bSQLite = true;

	SQLSetNames(INVALID_HANDLE);

	SQLTableCreation_Tag(INVALID_HANDLE);
	SQLTableCreation_Ban(INVALID_HANDLE);
	SQLTableCreation_Replace(INVALID_HANDLE);
}

stock bool SQL_Conn_Lost(DBResultSet db)
{
	if (db == null)
	{
		if (g_hDatabase != null)
		{
			LogError("Lost connection to DB. Reconnect after delay.");
			delete g_hDatabase;
			g_hDatabase = null;
		}

		if (g_DatabaseState != DatabaseState_Wait && g_hReconnectTimer == null)
		{
			g_DatabaseState = DatabaseState_Wait;
			g_hReconnectTimer = CreateTimer(9.0, SQLReconnect, _, TIMER_FLAG_NO_MAPCHANGE);
		}

		return true;
	}

	return false;
}

stock Action SQLReconnect(Handle hTimer)
{
	g_hReconnectTimer = null;
	if (g_DatabaseState == DatabaseState_Disconnected || g_DatabaseState == DatabaseState_Wait)
	{
		g_DatabaseState = DatabaseState_Disconnected;
		DB_Connect();
	}
	return Plugin_Continue;
}

stock Action SQLSetNames(Handle timer)
{
	if (!DB_Connect())
		return Plugin_Stop;

	if (!g_bSQLite)
		SQL_TQuery(g_hDatabase, OnSqlSetNames, "SET NAMES \"UTF8MB4\"");
	return Plugin_Continue;
}

stock Action SQLTableCreation_Tag(Handle timer)
{
	if (!DB_Connect())
		return Plugin_Stop;

	if (g_bSQLite)
		SQL_TQuery(g_hDatabase, OnSQLTableCreated_Tag, "CREATE TABLE IF NOT EXISTS `ccc_tag` (`steamid` TEXT NOT NULL, `enable` INTEGER NOT NULL DEFAULT 1, `name` TEXT NOT NULL, `flag` VARCHAR(32), `tag` TEXT, `tag_color` TEXT, `name_color` TEXT, `chat_color` TEXT, PRIMARY KEY(`steamid`));");
	else
		SQL_TQuery(g_hDatabase, OnSQLTableCreated_Tag, "CREATE TABLE IF NOT EXISTS `ccc_tag` (`steamid` VARCHAR(32) NOT NULL, `enable` INT NOT NULL DEFAULT 1, `name` VARCHAR(32) NOT NULL, `flag` VARCHAR(32), `tag` VARCHAR(32), `tag_color` VARCHAR(32), `name_color` VARCHAR(32), `chat_color` VARCHAR(32), PRIMARY KEY(`steamid`)) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
	return Plugin_Stop;
}

stock Action SQLTableCreation_Ban(Handle timer)
{
	if (!DB_Connect())
		return Plugin_Stop;

	if (g_bSQLite)
		SQL_TQuery(g_hDatabase, OnSQLTableCreated_Ban, "CREATE TABLE IF NOT EXISTS `ccc_ban` (`steamid` TEXT NOT NULL, `name` TEXT NOT NULL, `issuer_steamid` TEXT NOT NULL, `issuer_name` TEXT NOT NULL, `length` INTEGER NOT NULL, PRIMARY KEY(`steamid`));");
	else
		SQL_TQuery(g_hDatabase, OnSQLTableCreated_Ban, "CREATE TABLE IF NOT EXISTS `ccc_ban` (`steamid` VARCHAR(32) NOT NULL, `name` VARCHAR(32) NOT NULL, `issuer_steamid` VARCHAR(32) NOT NULL, `issuer_name` VARCHAR(32) NOT NULL, `length` INT NOT NULL, PRIMARY KEY(`steamid`)) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
	return Plugin_Stop;
}

stock Action SQLTableCreation_Replace(Handle timer)
{
	if (!DB_Connect())
		return Plugin_Stop;

	if (g_bSQLite)
		SQL_TQuery(g_hDatabase, OnSQLTableCreated_Replace, "CREATE TABLE IF NOT EXISTS `ccc_replace` (`trigger` TEXT NOT NULL, `value` TEXT NOT NULL, PRIMARY KEY(`trigger`));");
	else
		SQL_TQuery(g_hDatabase, OnSQLTableCreated_Replace, "CREATE TABLE IF NOT EXISTS `ccc_replace` (`trigger` VARCHAR(32) NOT NULL, `value` VARCHAR(255) NOT NULL, PRIMARY KEY(`trigger`)) CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;");
	return Plugin_Stop;
}

stock Action SQLSelect_Replace(Handle timer)
{
	if (!DB_Connect())
		return Plugin_Stop;

	char sQuery[MAX_SQL_QUERY_LENGTH];

	FormatEx(sQuery, sizeof(sQuery), "SELECT `trigger`, `value` FROM `ccc_replace`;");
	SQL_TQuery(g_hDatabase, OnSQLSelect_Replace, sQuery, 0, DBPrio_High);
	return Plugin_Stop;
}

stock Action SQLSelect_Ban(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	pack.ReadCell();
	char steamId[64];
	pack.ReadString(steamId, sizeof(steamId));

	char sQuery[MAX_SQL_QUERY_LENGTH];
	FormatEx(sQuery, sizeof(sQuery), "SELECT `length` FROM `ccc_ban` WHERE `steamid` = '%s';", steamId);
	SQL_TQuery(g_hDatabase, OnSQLSelect_Ban, sQuery, data, DBPrio_Low);
	return Plugin_Stop;
}

stock Action SQLSelect_TagGroup(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	char sFlagList[64];

	pack.ReadCell();
	pack.ReadString("", 0);
	pack.ReadString(sFlagList, sizeof(sFlagList));

	char sQuery[512];

	FormatEx(sQuery, sizeof(sQuery), "SELECT `steamid`, `enable`, `tag`, `tag_color`, `name_color`, `chat_color`, `flag` FROM `ccc_tag` WHERE `steamid` NOT LIKE 'STEAM_%' and `flag` IS NOT NULL and `flag` != '' and `flag` IN (%s) ORDER BY `flag` DESC;", sFlagList);
	SQL_TQuery(g_hDatabase, OnSQLSelect_TagGroup, sQuery, data, DBPrio_Low);
	return Plugin_Stop;
}

stock void GetClientFlagString(int client, char[] sClientFlagString, int maxSize)
{
	sClientFlagString[0] = '\0';

	AdminId aid = GetUserAdmin(client);

	AdminFlag admFlags[32];
	int iFlagsBits = GetAdminFlags(aid, Access_Real);
	iFlagsBits |= GetAdminFlags(aid, Access_Effective);
	int iAdmFlagsSize = FlagBitsToArray(iFlagsBits, admFlags, sizeof(admFlags));

	for (int i = 0; i < iAdmFlagsSize; i++)
	{
		int cFlag;
		if (FindFlagChar(admFlags[i], cFlag))
		{
			char sBuffer[64];
			Format(sBuffer, sizeof(sBuffer), "%s\"%c\",", sClientFlagString, cFlag);
			Format(sClientFlagString, maxSize, "%s", sBuffer);
		}
	}

	if (sClientFlagString[strlen(sClientFlagString) - 1] == ',')
		sClientFlagString[strlen(sClientFlagString) - 1] = '\0';

	if (sClientFlagString[0] == '\0')
	{
		sClientFlagString[0] = '\"';
		sClientFlagString[1] = '\"';
		sClientFlagString[2] = '\0';
	}
}

stock Action SQLSelect_TagClient(int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;

	char sClientFlagString[64];
	GetClientFlagString(client, sClientFlagString, sizeof(sClientFlagString));

	DataPack pack = new DataPack();
	pack.WriteCell(userid);
	pack.WriteString(g_sSteamIDs[client]);
	pack.WriteString(sClientFlagString);

	SQLSelect_Tag(INVALID_HANDLE, pack);

	return Plugin_Stop;
}

stock Action SQLSelect_Tag(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	char sClientSteamID[32];

	pack.ReadCell();
	pack.ReadString(sClientSteamID, sizeof(sClientSteamID));

	char sQuery[MAX_SQL_QUERY_LENGTH];

	FormatEx(sQuery, sizeof(sQuery), "SELECT `steamid`, `enable`, `tag`, `tag_color`, `name_color`, `chat_color` FROM `ccc_tag` WHERE `steamid` = '%s';", sClientSteamID);
	SQL_TQuery(g_hDatabase, OnSQLSelect_Tag, sQuery, data, DBPrio_Low);
	return Plugin_Stop;
}

stock Action SQLInsert_Replace(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	char sQuery[MAX_SQL_QUERY_LENGTH];
	char sTrigger[MAX_CHAT_TRIGGER_LENGTH];
	char sTriggerEscaped[2*MAX_CHAT_TRIGGER_LENGTH+1];
	char sValue[MAX_CHAT_LENGTH];
	char sValueEscaped[2*MAX_CHAT_LENGTH+1];

	pack.ReadCell();
	pack.ReadString(sTrigger, sizeof(sTrigger));
	pack.ReadString(sValue, sizeof(sValue));

	SQL_EscapeString(g_hDatabase, sTrigger, sTriggerEscaped, sizeof(sTriggerEscaped));
	SQL_EscapeString(g_hDatabase, sValue, sValueEscaped, sizeof(sValueEscaped));

	if (g_bSQLite)
	{
		FormatEx(
			sQuery,
			sizeof(sQuery),
			"REPLACE INTO `ccc_replace` (`trigger`, `value`) VALUES ('%s', '%s');",
			sTriggerEscaped, sValueEscaped
		);
	}
	else
	{
		FormatEx(
			sQuery,
			sizeof(sQuery),
			"INSERT INTO `ccc_replace` (`trigger`, `value`) VALUES ('%s', '%s') \
			ON DUPLICATE KEY UPDATE `trigger` = '%s', `value` = '%s';",
			sTriggerEscaped, sValueEscaped,
			sTriggerEscaped, sValueEscaped
		);
	}
	SQL_TQuery(g_hDatabase, OnSQLInsert_Replace, sQuery, data);
	return Plugin_Stop;
}

stock Action SQLDelete_Replace(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	char sQuery[MAX_SQL_QUERY_LENGTH];
	char sTrigger[MAX_CHAT_TRIGGER_LENGTH];

	pack.ReadCell();
	pack.ReadString(sTrigger, sizeof(sTrigger));

	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `ccc_replace` WHERE `trigger` = '%s';", sTrigger);
	SQL_TQuery(g_hDatabase, OnSQLDelete_Replace, sQuery, data);
	return Plugin_Stop;
}

stock Action SQLInsert_TagClient(int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;

	char sClientName[32];
	GetClientName(client, sClientName, sizeof(sClientName));

	DataPack pack = new DataPack();
	pack.WriteCell(userid);
	pack.WriteString(g_sSteamIDs[client]);
	pack.WriteCell(g_iClientEnable[client]);
	pack.WriteString(sClientName);
	pack.WriteString("");
	pack.WriteString(g_sClientTag[client]);
	pack.WriteString(g_sClientTagColor[client]);
	pack.WriteString(g_sClientNameColor[client]);
	pack.WriteString(g_sClientChatColor[client]);

	SQLInsert_Tag(INVALID_HANDLE, pack);

	return Plugin_Stop;
}

stock Action SQLInsert_Tag(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	char sSteamID[64];
	char sName[32];
	char sNameEscaped[32+1];
	char sFlag[32];
	char sTag[32];
	char sTagEscaped[2*32+1];
	char sTagColor[32];
	char sNameColor[32];
	char sChatColor[32];

	pack.ReadCell();
	pack.ReadString(sSteamID, sizeof(sSteamID));
	int iEnable = pack.ReadCell();
	pack.ReadString(sName, sizeof(sName));
	pack.ReadString(sFlag, sizeof(sFlag));
	pack.ReadString(sTag, sizeof(sTag));
	pack.ReadString(sTagColor, sizeof(sTagColor));
	pack.ReadString(sNameColor, sizeof(sNameColor));
	pack.ReadString(sChatColor, sizeof(sChatColor));

	SQL_EscapeString(g_hDatabase, sName, sNameEscaped, sizeof(sNameEscaped));
	SQL_EscapeString(g_hDatabase, sTag, sTagEscaped, sizeof(sTagEscaped));

	char sQuery[MAX_SQL_QUERY_LENGTH];

	if (g_bSQLite)
	{
		FormatEx(
			sQuery,
			sizeof(sQuery),
			"REPLACE INTO `ccc_tag` (`steamid`, `name`, `enable`, `flag`, `tag`, `tag_color`, `name_color`, `chat_color`) VALUES ('%s', '%s', '%d', '%s', '%s', '%s', '%s', '%s');",
			sSteamID, sNameEscaped, iEnable, sFlag, sTagEscaped, sTagColor, sNameColor, sChatColor
		);
	}
	else
	{
		FormatEx(
			sQuery,
			sizeof(sQuery),
			"INSERT INTO `ccc_tag` (`steamid`, `name`, `enable`, `flag`, `tag`, `tag_color`, `name_color`, `chat_color`) VALUES ('%s', '%s', '%d', '%s', '%s', '%s', '%s', '%s') \
			ON DUPLICATE KEY UPDATE `steamid` = '%s', `name` = '%s', `enable` = '%d', `flag` = '%s', `tag` = '%s', `tag_color` = '%s', `name_color` = '%s', `chat_color` = '%s';",
			sSteamID, sNameEscaped, iEnable, sFlag, sTagEscaped, sTagColor, sNameColor, sChatColor,
			sSteamID, sNameEscaped, iEnable, sFlag, sTagEscaped, sTagColor, sNameColor, sChatColor
		);
	}
	SQL_TQuery(g_hDatabase, OnSQLInsert_Tag, sQuery, data);
	return Plugin_Stop;
}

stock Action SQLUpdate_TagClient(int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;

	char sClientName[32];
	GetClientName(client, sClientName, sizeof(sClientName));

	DataPack pack = new DataPack();
	pack.WriteCell(userid);
	pack.WriteString(g_sSteamIDs[client]);
	pack.WriteCell(g_iClientEnable[client]);
	pack.WriteString(sClientName);
	pack.WriteString("");
	pack.WriteString(g_sClientTag[client]);
	pack.WriteString(g_sClientTagColor[client]);
	pack.WriteString(g_sClientNameColor[client]);
	pack.WriteString(g_sClientChatColor[client]);

	SQLUpdate_Tag(INVALID_HANDLE, pack);

	return Plugin_Stop;
}

stock Action SQLUpdate_Tag(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	char sSteamID[64];
	char sName[32];
	char sNameEscaped[32+1];
	char sFlag[32];
	char sTag[32];
	char sTagEscaped[2*32+1];
	char sTagColor[32];
	char sNameColor[32];
	char sChatColor[32];

	pack.ReadCell();
	pack.ReadString(sSteamID, sizeof(sSteamID));
	int iEnable = pack.ReadCell();
	pack.ReadString(sName, sizeof(sName));
	pack.ReadString(sFlag, sizeof(sFlag));
	pack.ReadString(sTag, sizeof(sTag));
	pack.ReadString(sTagColor, sizeof(sTagColor));
	pack.ReadString(sNameColor, sizeof(sNameColor));
	pack.ReadString(sChatColor, sizeof(sChatColor));

	SQL_EscapeString(g_hDatabase, sName, sNameEscaped, sizeof(sNameEscaped));
	SQL_EscapeString(g_hDatabase, sTag, sTagEscaped, sizeof(sTagEscaped));

	char sQuery[MAX_SQL_QUERY_LENGTH];

	FormatEx(
		sQuery,
		sizeof(sQuery),
		"UPDATE `ccc_tag` SET `name` = '%s', `enable` = '%d', `flag` = '%s', `tag` = '%s', `tag_color` = '%s', `name_color` = '%s', `chat_color` = '%s' WHERE `steamid` = '%s';",
		sNameEscaped, iEnable, sFlag, sTagEscaped, sTagColor, sNameColor, sChatColor, sSteamID
	);
	SQL_TQuery(g_hDatabase, OnSQLUpdate_Tag, sQuery, data);
	return Plugin_Stop;
}

stock Action SQLDelete_Tag(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	char sSteamID[64];

	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return Plugin_Stop;
	}

	pack.ReadString(sSteamID, sizeof(sSteamID));

	char sQuery[MAX_SQL_QUERY_LENGTH];

	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `ccc_tag` WHERE `steamid` = '%s';", sSteamID);
	SQL_TQuery(g_hDatabase, OnSQLDelete_Tag, sQuery, data);

	return Plugin_Stop;
}

stock void OnSqlSetNames(Database db, DBResultSet results, const char[] err, DataPack data)
{
	if (SQL_Conn_Lost(results))
	{
		LogError("Database error while setting names as utf8, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);
		CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLSetNames);

		return;
	}
	SQLSelect_Replace(INVALID_HANDLE);
}

public void OnSQLDelete_Tag(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return;
	}

	if (SQL_Conn_Lost(results))
	{
		if (g_bSQLDeleteTagRetry[client] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLDeleteTagRetry[client]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLDelete_Tag, data);
			return;
		}
	}

	g_bSQLDeleteTagRetry[client] = 0;

	delete pack;
}

stock Action SQLInsert_Ban(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	int client = GetClientOfUserId(pack.ReadCell());
	int target = GetClientOfUserId(pack.ReadCell());
	if (!client || !target)
	{
		delete pack;
		return Plugin_Stop;
	}

	char sTime[128];
	pack.ReadString(sTime, sizeof(sTime));
	char targetSid[64];
	char clientSid[64];
	char sTargetNameSnap[32];
	char sClientNameSnap[32];
	pack.ReadString(targetSid, sizeof(targetSid));
	pack.ReadString(clientSid, sizeof(clientSid));
	pack.ReadString(sTargetNameSnap, sizeof(sTargetNameSnap));
	pack.ReadString(sClientNameSnap, sizeof(sClientNameSnap));


	int time = StringToInt(sTime);
	time = GetTime() + (time * 60);

	if (StringToInt(sTime) == 0)
	{
		time = 0;
	}

	char sQuery[MAX_SQL_QUERY_LENGTH];
	char sClientName[32];
	char sTargetName[32];
	// Prefer snapshots; if empty (older pack), fallback to live names
	if (sClientNameSnap[0] != '\0')
		strcopy(sClientName, sizeof(sClientName), sClientNameSnap);
	else
		GetClientName(client, sClientName, sizeof(sClientName));
	if (sTargetNameSnap[0] != '\0')
		strcopy(sTargetName, sizeof(sTargetName), sTargetNameSnap);
	else
		GetClientName(target, sTargetName, sizeof(sTargetName));

	char sClientNameEscaped[32+1];
	char sTargetNameEscaped[32+1];
	SQL_EscapeString(g_hDatabase, sClientName, sClientNameEscaped, sizeof(sClientNameEscaped));
	SQL_EscapeString(g_hDatabase, sTargetName, sTargetNameEscaped, sizeof(sTargetNameEscaped));

	if (g_bSQLite)
	{
		FormatEx(
			sQuery,
			sizeof(sQuery),
			"REPLACE INTO `ccc_ban` (`steamid`, `name`, `issuer_steamid`, `issuer_name`, `length`) VALUES ('%s', '%s', '%s', '%s', '%d');",
			targetSid[0] ? targetSid : g_sSteamIDs[target], sTargetNameEscaped, clientSid[0] ? clientSid : g_sSteamIDs[client], sClientNameEscaped, time
		);
	}
	else
	{
		FormatEx(
			sQuery,
			sizeof(sQuery),
			"INSERT INTO `ccc_ban` (`steamid`, `name`, `issuer_steamid`, `issuer_name`, `length`) VALUES ('%s', '%s', '%s', '%s', '%d') \
			ON DUPLICATE KEY UPDATE `steamid` = '%s', `name` = '%s', `issuer_steamid` = '%s', `issuer_name` = '%s', `length` = '%d';",
			targetSid[0] ? targetSid : g_sSteamIDs[target], sTargetNameEscaped, clientSid[0] ? clientSid : g_sSteamIDs[client], sClientNameEscaped, time,
			targetSid[0] ? targetSid : g_sSteamIDs[target], sTargetNameEscaped, clientSid[0] ? clientSid : g_sSteamIDs[client], sClientNameEscaped, time
		);
	}
	SQL_TQuery(g_hDatabase, OnSQLInsert_Ban, sQuery, data);

	return Plugin_Stop;
}

stock Action SQLDelete_Ban(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	if (!DB_Connect())
	{
		delete pack;
		return Plugin_Stop;
	}

	int client = GetClientOfUserId(pack.ReadCell());
	int target = GetClientOfUserId(pack.ReadCell());
	if (!client || !target)
	{
		delete pack;
		return Plugin_Stop;
	}

	char targetSid[64];
	pack.ReadString(targetSid, sizeof(targetSid));

	char sQuery[MAX_SQL_QUERY_LENGTH];

	FormatEx(sQuery, sizeof(sQuery), "DELETE FROM `ccc_ban` WHERE `steamid` = '%s';", targetSid[0] ? targetSid : g_sSteamIDs[target]);
	SQL_TQuery(g_hDatabase, OnSQLDelete_Ban, sQuery, data);

	return Plugin_Stop;
}

public void OnSQLTableCreated_Tag(Database db, DBResultSet results, const char[] err, DataPack data)
{
	if (SQL_Conn_Lost(results))
	{
		LogError("Database error while creating/checking for \"ccc_tag\" table, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);
		CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLTableCreation_Tag);

		return;
	}
}

public void OnSQLTableCreated_Ban(Database db, DBResultSet results, const char[] err, DataPack data)
{
	if (SQL_Conn_Lost(results))
	{
		LogError("Database error while creating/checking for \"ccc_ban\" table, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);
		CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLTableCreation_Ban);

		return;
	}
}

public void OnSQLTableCreated_Replace(Database db, DBResultSet results, const char[] err, DataPack data)
{
	if (SQL_Conn_Lost(results))
	{
		LogError("Database error while creating/checking for \"ccc_replace\" table, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);
		CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLTableCreation_Replace);

		return;
	}
}

public void OnSQLSelect_Replace(Database db, DBResultSet results, const char[] err, any client)
{
	if (SQL_Conn_Lost(results))
	{
		LogError("An error occurred while querying the database for the replace list, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);

		if (g_bSQLSelectReplaceRetry + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLSelectReplaceRetry++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLSelect_Replace, client);
			return;
		}
	}
	else
	{
		while (SQL_FetchRow(results))
		{
			SQL_FetchString(results, 0, g_sReplaceList[g_iReplaceListSize][0], sizeof(g_sReplaceList[][]));
			SQL_FetchString(results, 1, g_sReplaceList[g_iReplaceListSize][1], sizeof(g_sReplaceList[][]));
			ReplaceString(g_sReplaceList[g_iReplaceListSize][1], sizeof(g_sReplaceList[][]), "\r\n", "\n");
			g_iReplaceListSize++;
		}
	}

	g_bSQLSelectReplaceRetry = 0;
}

public void OnSQLSelect_Ban(Database db, DBResultSet results, const char[] err, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();
	int userid = pack.ReadCell();
	char steamId[64];
	pack.ReadString(steamId, sizeof(steamId));

	int client = GetClientOfUserId(userid);
	if (!client)
	{
		delete pack;
		return;
	}

	if (SQL_Conn_Lost(results))
	{
		LogError("An error occurred while querying the database for the user tag, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);

		if (g_bSQLSelectBanRetry[client] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLSelectBanRetry[client]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLSelect_Ban, data);
			return;
		}
	}
	else if (SQL_FetchRow(results))
	{
		g_iClientBanned[client] = SQL_FetchInt(results, 0);
	}

	g_bSQLSelectBanRetry[client] = 0;

	delete pack;
}

stock void OnSQLSelect_TagGroup(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return;
	}

	g_sClientSID[client] = "";

	if (SQL_Conn_Lost(results))
	{
		LogError("An error occurred while querying the database for the user group tag, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);

		if (g_bSQLSelectTagGroupRetry[client] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLSelectTagGroupRetry[client]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLSelect_TagGroup, data);
			return;
		}
	}
	else if (SQL_FetchRow(results))
	{
		g_iClientEnable[client] = SQL_FetchInt(results, 1);
		SQL_FetchString(results, 2, g_sClientTag[client], sizeof(g_sClientTag[]));
		SQL_FetchString(results, 3, g_sClientTagColor[client], sizeof(g_sClientTagColor[]));
		SQL_FetchString(results, 4, g_sClientNameColor[client], sizeof(g_sClientNameColor[]));
		SQL_FetchString(results, 5, g_sClientChatColor[client], sizeof(g_sClientChatColor[]));

		g_iDefaultClientEnable[client] = g_iClientEnable[client];
		if (strlen(g_sClientTag[client]) > 31)
			g_sClientTag[client][31] = '\0';
		strcopy(g_sDefaultClientTag[client], sizeof(g_sDefaultClientTag[]), g_sClientTag[client]);
		strcopy(g_sDefaultClientTagColor[client], sizeof(g_sDefaultClientTagColor[]), g_sClientTagColor[client]);
		strcopy(g_sDefaultClientNameColor[client], sizeof(g_sDefaultClientNameColor[]), g_sClientNameColor[client]);
		strcopy(g_sDefaultClientChatColor[client], sizeof(g_sDefaultClientChatColor[]), g_sClientChatColor[client]);

		g_bClientDataLoaded[client] = true;
	}

	g_bSQLSelectTagGroupRetry[client] = 0;

	delete pack;
}

public void OnSQLSelect_Tag(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return;
	}

	g_sClientSID[client] = "";

	if (SQL_Conn_Lost(results))
	{
		LogError("An error occurred while querying the database for the user tag, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);

		if (g_bSQLSelectTagRetry[client] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLSelectTagRetry[client]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLSelect_Tag, data);
			return;
		}
	}
	else if (SQL_FetchRow(results))
	{
		SQL_FetchString(results, 0, g_sClientSID[client], sizeof(g_sClientSID[]));
		g_iClientEnable[client] = SQL_FetchInt(results, 1);
		SQL_FetchString(results, 2, g_sClientTag[client], sizeof(g_sClientTag[]));
		SQL_FetchString(results, 3, g_sClientTagColor[client], sizeof(g_sClientTagColor[]));
		SQL_FetchString(results, 4, g_sClientNameColor[client], sizeof(g_sClientNameColor[]));
		SQL_FetchString(results, 5, g_sClientChatColor[client], sizeof(g_sClientChatColor[]));

		g_iDefaultClientEnable[client] = g_iClientEnable[client];
		if (strlen(g_sClientTag[client]) > 31)
			g_sClientTag[client][31] = '\0';
		strcopy(g_sDefaultClientTag[client], sizeof(g_sDefaultClientTag[]), g_sClientTag[client]);
		strcopy(g_sDefaultClientTagColor[client], sizeof(g_sDefaultClientTagColor[]), g_sClientTagColor[client]);
		strcopy(g_sDefaultClientNameColor[client], sizeof(g_sDefaultClientNameColor[]), g_sClientNameColor[client]);
		strcopy(g_sDefaultClientChatColor[client], sizeof(g_sDefaultClientChatColor[]), g_sClientChatColor[client]);

		Call_StartForward(loadedForward);
		Call_PushCell(client);
		Call_Finish();

		g_bClientDataLoaded[client] = true;
	}
	else
	{
		g_bSQLSelectTagRetry[client] = 0;
		SQLSelect_TagGroup(INVALID_HANDLE, data);
		return;
	}

	g_bSQLSelectTagRetry[client] = 0;

	delete pack;
}

public void OnSQLUpdate_Tag(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return;
	}

	if (SQL_Conn_Lost(results))
	{
		LogError("An error occurred while updating an user tag, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);

		if (g_bSQLUpdateTagRetry[client] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLUpdateTagRetry[client]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLUpdate_Tag, data);
			return;
		}
	}

	// Do not reset the client here; it clears SteamID and runtime state.
	// Instead, snapshot current values as defaults so we don't trigger writes on disconnect.
	g_iDefaultClientEnable[client] = g_iClientEnable[client];
	if (strlen(g_sClientTag[client]) > 31)
		g_sClientTag[client][31] = '\0';
	strcopy(g_sDefaultClientTag[client], sizeof(g_sDefaultClientTag[]), g_sClientTag[client]);
	strcopy(g_sDefaultClientTagColor[client], sizeof(g_sDefaultClientTagColor[]), g_sClientTagColor[client]);
	strcopy(g_sDefaultClientNameColor[client], sizeof(g_sDefaultClientNameColor[]), g_sClientNameColor[client]);
	strcopy(g_sDefaultClientChatColor[client], sizeof(g_sDefaultClientChatColor[]), g_sClientChatColor[client]);
	g_bClientDataLoaded[client] = true;
	g_bSQLUpdateTagRetry[client] = 0;

	delete pack;
}

public void OnSQLInsert_Replace(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return;
	}

	if (SQL_Conn_Lost(results))
	{
		LogError("An error occurred while inserting a chat trigger, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);
		if (g_bSQLInsertReplaceRetry[client] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLInsertReplaceRetry[client]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLInsert_Replace, data);
			return;
		}
	}
	else
	{
		char sTrigger[MAX_CHAT_TRIGGER_LENGTH];
		char sValue[MAX_CHAT_LENGTH];

		pack.ReadString(sTrigger, sizeof(sTrigger));
		pack.ReadString(sValue, sizeof(sValue));

		g_sReplaceList[g_iReplaceListSize][0] = sTrigger;
		g_sReplaceList[g_iReplaceListSize][1] = sValue;
		g_iReplaceListSize++;
	}

	g_bSQLInsertReplaceRetry[client] = 0;

	delete pack;
}

public void OnSQLDelete_Replace(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return;
	}

	if (SQL_Conn_Lost(results))
	{
		if (g_bSQLDeleteReplaceRetry[client] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLDeleteReplaceRetry[client]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLDelete_Replace, data);
			return;
		}
	}
	else
	{
		char sTrigger[MAX_CHAT_TRIGGER_LENGTH];
		pack.ReadString(sTrigger, sizeof(sTrigger));

		for (int i = 0; i < g_iReplaceListSize; i++)
		{
			if (strcmp(sTrigger, g_sReplaceList[i][0], false) == 0)
			{
				for (int y = i; y < g_iReplaceListSize; y++)
				{
					if (y + 1 < g_iReplaceListSize)
					{
						g_sReplaceList[y][0] = g_sReplaceList[y + 1][0];
						g_sReplaceList[y][1] = g_sReplaceList[y + 1][1];
					}
					else
					{
						g_sReplaceList[y][0] = "";
						g_sReplaceList[y][1] = "";
					}
				}
				g_iReplaceListSize--;

				break;
			}
		}
	}

	g_bSQLDeleteReplaceRetry[client] = 0;

	delete pack;
}

public void OnSQLInsert_Tag(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	if (!client)
	{
		delete pack;
		return;
	}

	if (SQL_Conn_Lost(results))
	{
		LogError("An error occurred while inserting an user tag, retrying in %d seconds. (%s)", GetConVarInt(g_cvar_SQLRetryTime), err);
		if (g_bSQLInsertTagRetry[client] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLInsertTagRetry[client]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLInsert_Tag, data);
			return;
		}
	}

	g_bSQLInsertTagRetry[client] = 0;

	delete pack;
}

public void OnSQLInsert_Ban(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int target = GetClientOfUserId(pack.ReadCell());

	if (!client || !target)
	{
		delete pack;
		return;
	}

	if (SQL_Conn_Lost(results))
	{
		if (g_bSQLInsertBanRetry[target] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLInsertBanRetry[target]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLInsert_Ban, data);
			return;
		}
	}
	else
	{
		char sTime[128];
		pack.ReadString(sTime, sizeof(sTime));

		int time = StringToInt(sTime);
		time = GetTime() + (time * 60);

		if (StringToInt(sTime) == 0)
		{
			time = 0;
		}

		g_iClientBanned[target] = time;
	}

	g_bSQLInsertBanRetry[target] = 0;

	delete pack;
}

public void OnSQLDelete_Ban(Database db, DBResultSet results, const char[] err, DataPack data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int target = GetClientOfUserId(pack.ReadCell());

	if (!client || !target)
	{
		delete pack;
		return;
	}

	if (SQL_Conn_Lost(results))
	{
		if (g_bSQLDeleteBanRetry[target] + 1 < GetConVarInt(g_cvar_SQLMaxRetries))
		{
			g_bSQLDeleteBanRetry[target]++;
			CreateTimer(GetConVarFloat(g_cvar_SQLRetryTime), SQLDelete_Ban, data);
			return;
		}
	}
	else
	{
		g_iClientBanned[target] = -1;
	}

	g_bSQLDeleteBanRetry[target] = 0;

	delete pack;
}

bool MakeStringPrintable(char[] str, int str_len_max, const char[] empty) //function taken from Forlix FloodCheck (http://forlix.org/gameaddons/floodcheck.shtml)
{
	int r = 0;
	int w = 0;
	bool modified = false;
	bool nonspace = false;
	bool addspace = false;

	if (str[0])
	{
		do
		{
			if (str[r] < '\x20')
			{
				modified = true;

				if ((str[r] == '\n' || str[r] == '\t') && w > 0 && str[w-1] != '\x20')
					addspace = true;
			}
			else
			{
				if (str[r] != '\x20')
				{
					nonspace = true;

					if (addspace)
						str[w++] = '\x20';
				}

				addspace = false;
				str[w++] = str[r];
			}
		}
		while (str[++r]);
	}

	str[w] = '\0';

	if (!nonspace)
	{
		modified = true;
		strcopy(str, str_len_max, empty);
	}

	return (modified);
}

bool SingularOrMultiple(int num)
{
	if (num > 1 || num == 0)
	{
		return true;
	}

	return false;
}

bool HasFlag(int client, AdminFlag ADMFLAG)
{
	AdminId Admin = GetUserAdmin(client);

	if (Admin != INVALID_ADMIN_ID && GetAdminFlag(Admin, ADMFLAG, Access_Effective))
		return true;

	return false;
}

bool ChangeSingleTag(int client, int iTarget, char sTag[64], bool bAdmin)
{
	ReplaceString(sTag, sizeof(sTag), "\"", "'");
	ReplaceString(sTag, sizeof(sTag), "%s", "s");

	if (SetTag(sTag, iTarget, bAdmin))
	{
		CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}%s]{default} Successfully set {green}%N's{default} tag to: {green}%s{default}!", bAdmin ? "-ADMIN" : "", iTarget, sTag);
		return true;
	}
	return false;
}

bool ChangeTag(int client, bool bAdmin)
{
	int iTarget;
	char sTarget[64];
	char sTag[64];

	if (bAdmin)
	{
		GetCmdArg(1, sTarget, sizeof(sTarget));
		GetCmdArg(2, sTag, sizeof(sTag));

		if ((iTarget = FindTarget(client, sTarget, true)) == -1)
		{
			return false;
		}
	}
	else
	{
		iTarget = client;
		GetCmdArg(1, sTag, sizeof(sTag));
	}

	if (strlen(sTag) > 31)
	{
		CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Tag is too long (32 characters max).");
		return false;
	}

	return ChangeSingleTag(client, iTarget, sTag, bAdmin);
}

bool ChangeSingleColor(int client, int iTarget, char Key[64], char sCol[64], bool bAdmin)
{
	if (IsValidRGBNum(sCol))
	{
		char g[8];
		char b[8];
		GetCmdArg(3, g, sizeof(g));
		GetCmdArg(4, b, sizeof(b));
		int hex;

		hex |= ((StringToInt(sCol) & 0xFF) << 16);
		hex |= ((StringToInt(g) & 0xFF) << 8);
		hex |= ((StringToInt(b) & 0xFF) << 0);

		Format(sCol, 64, "#%06X", hex);
	}

	if (IsSource2009() && IsValidHex(sCol))
	{
		if (sCol[0] != '#')
			Format(sCol, sizeof(sCol), "#%s", sCol);

		SetColor(Key, sCol, iTarget, bAdmin);

		if (!strcmp(Key, "namecolor"))
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}%s]{default} Successfully set {green}%N's{default} name color to: \x07%s%s{default}!", bAdmin ? "-ADMIN" : "", iTarget, sCol[0], sCol[0]);
		else if (!strcmp(Key, "tagcolor"))
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}%s]{default} Successfully set {green}%N's{default} tag color to: \x07%s%s{default}!", bAdmin ? "-ADMIN" : "", iTarget, sCol[0], sCol[0]);
		else
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}%s]{default} Successfully set {green}%N's{default} text color to: \x07%s%s{default}!", bAdmin ? "-ADMIN" : "", iTarget, sCol[0], sCol[0]);
	}
	else if ((IsSource2009() && !IsValidHex(sCol)) || !IsSource2009())
	{
		StringMap smTrie = CGetTrie();
		char value[32];
		if (!smTrie.GetString(sCol, value, sizeof(value)))
		{
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid color name given.");
			return false;
		}

		SetColor(Key, sCol, iTarget, bAdmin);

		if (!strcmp(Key, "namecolor"))
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}%s]{default} Successfully set {green}%N's{default} name color to: {%s}%s{default}!", bAdmin ? "-ADMIN" : "", iTarget, sCol[0], sCol[0]);
		else if (!strcmp(Key, "tagcolor"))
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}%s]{default} Successfully set {green}%N's{default} tag color to: {%s}%s{default}!", bAdmin ? "-ADMIN" : "", iTarget, sCol[0], sCol[0]);
		else
			CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}%s]{default} Successfully set {green}%N's{default} text color to: {%s}%s{default}!", bAdmin ? "-ADMIN" : "", iTarget, sCol[0], sCol[0]);
	}
	else
	{
		CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} Invalid HEX|RGB|name color code given.");
		return false;
	}
	return true;
}

bool ChangeColor(int client, char Key[64], bool bAdmin)
{
	int iTarget;
	char sTarget[64];
	char sCol[64];

	if (bAdmin)
	{
		GetCmdArg(1, sTarget, sizeof(sTarget));
		GetCmdArg(2, sCol, sizeof(sCol));

		if ((iTarget = FindTarget(client, sTarget, true)) == -1)
		{
			return false;
		}
	}
	else
	{
		iTarget = client;
		GetCmdArg(1, sCol, sizeof(sCol));
	}

	return ChangeSingleColor(client, iTarget, Key, sCol, bAdmin);
}

bool IsValidRGBNum(char[] arg)
{
	if (SimpleRegexMatch(arg, "^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$") == 2)
	{
		return true;
	}

	return false;
}

bool IsValidHex(char[] arg)
{
	if (SimpleRegexMatch(arg, "^(#?)([A-Fa-f0-9]{6})$") == 0)
	{
		return false;
	}

	return true;
}

stock bool IsClientBanned(int client, const char Key[64] = "")
{
	if (g_iClientBanned[client] == 0)
	{
		CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} You are currently {red}permanently banned{default} from changing your {green}%s{default}.", Key);
		return true;
	}
	else if (g_iClientBanned[client] >= GetTime())
	{
		char TimeBuffer[64];
		int tstamp = g_iClientBanned[client];
		tstamp = (tstamp - GetTime());

		int days = (tstamp / 86400);
		int hrs = ((tstamp / 3600) % 24);
		int mins = ((tstamp / 60) % 60);
		int sec = (tstamp % 60);

		if (tstamp > 86400)
		{
			Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s, %d %s, %d %s", days, SingularOrMultiple(days) ? "Days" : "Day", hrs, SingularOrMultiple(hrs) ? "Hours" : "Hour", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
		}
		else if (tstamp > 3600)
		{
			Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s, %d %s", hrs, SingularOrMultiple(hrs) ? "Hours" : "Hour", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
		}
		else if (tstamp > 60)
		{
			Format(TimeBuffer, sizeof(TimeBuffer), "%d %s, %d %s", mins, SingularOrMultiple(mins) ? "Minutes" : "Minute", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
		}
		else
		{
			Format(TimeBuffer, sizeof(TimeBuffer), "%d %s", sec, SingularOrMultiple(sec) ? "Seconds" : "Second");
		}

		CPrintToChat(client, "{green}[{red}C{green}C{blue}C{green}]{default} You are currently {red}banned{default} from changing your {green}%s{default}. (Time remaining: {green}%s{default})", Key, TimeBuffer);
		return true;
	}
	return false;
}

stock bool SetColor(char Key[64], char HEX[64], int client, bool IgnoreBan=false)
{
	if (g_DatabaseState != DatabaseState_Connected)
		return false;

	if (!IgnoreBan)
	{
		if (IsClientBanned(client, Key))
			return false;
	}

	// Normalize HEX by stripping leading '#'
	if (HEX[0] == '#')
		ReplaceString(HEX, sizeof(HEX), "#", "");

	// Avoid unnecessary DB writes if value unchanged
	char current[32];
	if (strcmp(Key, "tagcolor", false) == 0)
		strcopy(current, sizeof(current), g_sClientTagColor[client]);
	else if (strcmp(Key, "namecolor", false) == 0)
		strcopy(current, sizeof(current), g_sClientNameColor[client]);
	else if (strcmp(Key, "textcolor", false) == 0)
		strcopy(current, sizeof(current), g_sClientChatColor[client]);
	else
		current[0] = '\0';

	if (current[0] != '\0' && strcmp(current, HEX, false) == 0)
		return true;

	if (strcmp(Key, "tagcolor", false) == 0)
	{
		strcopy(g_sClientTagColor[client], sizeof(g_sClientTagColor[]), HEX);
	}
	else if (strcmp(Key, "namecolor", false) == 0)
	{
		strcopy(g_sClientNameColor[client], sizeof(g_sClientNameColor[]), HEX);
	}
	else if (strcmp(Key, "textcolor", false) == 0)
	{
		strcopy(g_sClientChatColor[client], sizeof(g_sClientChatColor[]), HEX);
	}

	if (g_sClientSID[client][0] != '\0')
		SQLUpdate_TagClient(GetClientUserId(client));
	else
		SQLInsert_TagClient(GetClientUserId(client));

	return true;
}

stock bool SetTag(char text[64], int client, bool IgnoreBan=false)
{
	if (g_DatabaseState != DatabaseState_Connected)
		return false;

	if (!IgnoreBan)
	{
		if (IsClientBanned(client, "Tag"))
			return false;
	}

	Format(g_sClientTag[client], sizeof(g_sClientTag[]), "%s ", text);

	if (g_sClientSID[client][0] != '\0')
		SQLUpdate_TagClient(GetClientUserId(client));
	else
		SQLInsert_TagClient(GetClientUserId(client));

	return true;
}

stock bool RemoveCCC(int client)
{
	ResetClient(client);

	return true;
}

stock void BanCCC(int client, int target, char Time[128])
{
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(GetClientUserId(target));
	pack.WriteString(Time);

	// Snapshot SteamIDs and names to keep operations stable across retries/disconnects
	char targetSid[64];
	char clientSid[64];
	char sClientName[32];
	char sTargetName[32];
	FormatEx(targetSid, sizeof(targetSid), "%s", g_sSteamIDs[target]);
	FormatEx(clientSid, sizeof(clientSid), "%s", g_sSteamIDs[client]);
	GetClientName(client, sClientName, sizeof(sClientName));
	GetClientName(target, sTargetName, sizeof(sTargetName));

	pack.WriteString(targetSid);
	pack.WriteString(clientSid);
	pack.WriteString(sTargetName);
	pack.WriteString(sClientName);

	SQLInsert_Ban(INVALID_HANDLE, pack);
}

stock void UnBanCCC(int client, int target)
{
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(GetClientUserId(target));
	pack.WriteString(g_sSteamIDs[target]);

	SQLDelete_Ban(INVALID_HANDLE, pack);
}

stock void ToggleCCC(int client)
{
	g_iClientEnable[client] = g_iClientEnable[client] ? 0 : 1;
}

void SendChatToAdmins(int from, const char[] message)
{
	// Message is empty, ignore it
	if (strlen(message) == 0)
		return;

	LogAction(from, -1, "\"%L\" triggered sm_chat (text %s)", from, message);

	int fromAdmin = CheckCommandAccess(from, "sm_chat", ADMFLAG_CHAT);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (from == i || CheckCommandAccess(i, "sm_chat", ADMFLAG_CHAT)))
		{
			CPrintToChat(i, "%s(%sADMINS) %s%N{default} : %s%s", g_sSmCategoryColor, fromAdmin ? "" : "TO ",
				g_sSmNameColor, from, g_sSmChatColor, message);
		}
	}
}

void SendPrivateChat(int client, int target, const char[] message)
{
	if (g_bDisablePsay[client])
	{
		CPrintToChat(client, "{green}[SM]{default} Enabling private messaging is necessary to send private messages.");
		ShowSettingsMenu(client);
		return;
	}

	if (client && (IsClientInGame(client) && BaseComm_IsClientGagged(client)))
	{
		CPrintToChat(client, "{green}[SM]{default} You are {red}not allowed {default}to use this command {red}since you are gagged{default}.");
		return;
	}

#if defined _sourcecomms_included
	if (g_bSourceCommsNative && client)
	{
		int IsGagged = SourceComms_GetClientGagType(client);
		if (IsGagged > 0)
		{
			CPrintToChat(client, "{green}[SM]{default} You are {red}not allowed {default}to use this command {red}since you are gagged{default}.");
			return;
		}
	}
#endif

	int iTime = GetTime();
	if (g_iClientPsayCooldown[client] > iTime)
	{
		CPrintToChat(client, "{green}[SM]{default} You are on cooldown, wait {olive}%d {default}seconds to use this command again.", (g_iClientPsayCooldown[client] - iTime));
		return;
	}

	if (!target || !IsClientInGame(target))
	{
		CPrintToChat(client, "{green}[SM]{default} The receiver is not in the game.");
		return;
	}

	if (g_bDisablePsay[target])
	{
		CPrintToChat(client, "{green}[SM]{olive} %N{default} has{red} disabled{default} private messages.", target);
		return;
	}

	char text[192];
	Format(text, sizeof(text), "%s", message);
	StripQuotes(text);

	int admins[MAXPLAYERS + 1];
	int adminsCount = 0;

	if (g_cvPsayPrivacy.IntValue != 1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			if (i == client || i == target)
				continue;

			if (CheckCommandAccess(i, "sm_ban", ADMFLAG_BAN, true))
			{
				admins[adminsCount] = i;
				adminsCount++;
			}
		}
	}

	if (!client)
	{
		PrintToServer("(Private to %N) %N: %s", target, client, text);
	}
	else if (target != client)
	{
		CPrintToChat(client, "%s(Private to %s%N%s) %s%N {default}: %s%s",
			g_sSmCategoryColor,
			g_sSmNameColor, target, g_sSmCategoryColor,
			g_sSmNameColor, client,
			g_sSmChatColor, text);

		if (g_cvPsayPrivacy.IntValue != 1)
		{
			for (int i = 0; i < adminsCount; i++)
			{
				CPrintToChat(admins[i], "%s(Private from %s%N%s to %s%N%s){default}: %s%s",
					g_sSmCategoryColor,
					g_sSmNameColor, client, g_sSmCategoryColor,
					g_sSmNameColor, target, g_sSmCategoryColor,
					g_sSmChatColor, text);
			}
		}
	}

#if defined _SelfMute_included_
	if (!g_bSelfMuteNative || !SelfMute_GetSelfMute(target, client) || CheckCommandAccess(client, "sm_kick", ADMFLAG_KICK, true))
		CPrintToChat(target, "%s(Private to %s%N%s) %s%N {default}: %s%s",
			g_sSmCategoryColor,
			g_sSmNameColor, target, g_sSmCategoryColor,
			g_sSmNameColor, client,
			g_sSmChatColor, text);
#else
	CPrintToChat(target, "%s(Private to %s%N%s) %s%N {default}: %s%s",
		g_sSmCategoryColor,
		g_sSmNameColor, target, g_sSmCategoryColor,
		g_sSmNameColor, client,
		g_sSmChatColor, text);
#endif

	g_iClientPsayCooldown[client] = iTime + g_cvPsayCooldown.IntValue;
	CPrintToChat(target, "{green}[SM] {default}Use /r <message> to reply.");
	LogAction(client, target, "\"%L\" triggered sm_psay to \"%L\" (text %s)", client, target, text);
}

void SendChatToAll(int client, const char[] message)
{
	if (!CheckCommandAccess(client, "sm_say", ADMFLAG_CHAT))
		return;

	char nameBuf[MAX_NAME_LENGTH];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));

		CPrintToChat(i, "%s(ALL) %s%s {default}: %s%s", g_sSmCategoryColor, g_sSmNameColor, nameBuf, g_sSmChatColor, message);
	}
}

//   .d8888b.   .d88888b.  888b     d888 888b     d888        d8888 888b    888 8888888b.   .d8888b.
//  d88P  Y88b d88P" "Y88b 8888b   d8888 8888b   d8888       d88888 8888b   888 888  "Y88b d88P  Y88b
//  888    888 888     888 88888b.d88888 88888b.d88888      d88P888 88888b  888 888    888 Y88b.
//  888        888     888 888Y88888P888 888Y88888P888     d88P 888 888Y88b 888 888    888  "Y888b.
//  888        888     888 888 Y888P 888 888 Y888P 888    d88P  888 888 Y88b888 888    888     "Y88b.
//  888    888 888     888 888  Y8P  888 888  Y8P  888   d88P   888 888  Y88888 888    888       "888
//  Y88b  d88P Y88b. .d88P 888   "   888 888   "   888  d8888888888 888   Y8888 888  .d88P Y88b  d88P
//   "Y8888P"   "Y88888P"  888       888 888       888 d88P     888 888    Y888 8888888P"   "Y8888P"
//

public Action Command_CCCImportReplaceFile(int client, int argc)
{
	if (argc != 1)
	{
		CReplyToCommand(client, "{green}[CCC]{white} Usage: sm_cccimportreplacefile filename");
		return Plugin_Handled;
	}

	char sFilename[128];
	GetCmdArg(1, sFilename, sizeof(sFilename));

	char sFilepath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilepath, sizeof(sFilepath), "configs/%s", sFilename);

	KeyValues kv = new KeyValues("AutoReplace");

	if (!kv.ImportFromFile(sFilepath))
	{
		CReplyToCommand(client, "{green}[CCC]{white} File missing, please make sure \"%s\" is in the \"sourcemod/configs\" folder.", sFilepath);
		return Plugin_Handled;
	}

	if (!kv.GotoFirstSubKey(false))
	{
		delete kv;
		return Plugin_Handled;
	}

	char sTrigger[MAX_CHAT_TRIGGER_LENGTH];
	char sValue[MAX_CHAT_LENGTH];
	do
	{
		kv.GetSectionName(sTrigger, sizeof(sTrigger));
		kv.GetString(NULL_STRING, sValue, sizeof(sValue));

		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(sTrigger);
		pack.WriteString(sValue);

		SQLInsert_Replace(INVALID_HANDLE, pack);

	} while (kv.GotoNextKey(false));

	delete kv;
	return Plugin_Handled;
}

public Action Command_CCCAddTag(int client, int argc)
{
	if (argc != 8)
	{
		CReplyToCommand(client, "{green}[CCC]{white} Usage: sm_cccaddtag steamid enable name flag tag tag_color name_color chat_color");
		return Plugin_Handled;
	}

	char sSteamID[64];
	char sEnable[2];
	char sName[32];
	char sFlag[32];
	char sTag[32];
	char sTagColor[32];
	char sNameColor[32];
	char sChatColor[32];

	GetCmdArg(1, sSteamID, sizeof(sSteamID));
	GetCmdArg(2, sEnable, sizeof(sEnable));
	GetCmdArg(3, sName, sizeof(sName));
	GetCmdArg(4, sFlag, sizeof(sFlag));
	GetCmdArg(5, sTag, sizeof(sTag));
	GetCmdArg(6, sTagColor, sizeof(sTagColor));
	GetCmdArg(7, sNameColor, sizeof(sNameColor));
	GetCmdArg(8, sChatColor, sizeof(sChatColor));

	if (strlen(sTag) > 31)
	{
		CReplyToCommand(client, "{green}[CCC]{white} Tag is too long (32 characters max).");
		return Plugin_Handled;
	}

	if (strlen(sEnable) == 1 && strlen(sName) > 0 &&
		strlen(sTagColor) <= 6 && strlen(sNameColor) <= 6 && strlen(sChatColor) <= 6)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(sSteamID);
		pack.WriteCell(StringToInt(sEnable));
		pack.WriteString(sName);
		pack.WriteString(sFlag);
		pack.WriteString(sTag);
		pack.WriteString(sTagColor);
		pack.WriteString(sNameColor);
		pack.WriteString(sChatColor);

		SQLInsert_Tag(INVALID_HANDLE, pack);
	}
	else
	{
		CReplyToCommand(client, "{green}[CCC]{white} Wrong parameters.");
	}

	return Plugin_Handled;
}

public Action Command_CCCDeleteTag(int client, int argc)
{
	if (argc != 8)
	{
		CReplyToCommand(client, "{green}[CCC]{white} Usage: sm_cccdeletetag steamid");
		return Plugin_Handled;
	}

	char sSteamID[64];

	GetCmdArg(1, sSteamID, sizeof(sSteamID));

	if (strlen(sSteamID) > 0)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(sSteamID);

		SQLDelete_Tag(INVALID_HANDLE, pack);
	}
	else
	{
		CReplyToCommand(client, "{green}[CCC]{white} Wrong parameter.");
	}

	return Plugin_Handled;
}

public Action Command_CCCAddTrigger(int client, int argc)
{
	if (argc != 2)
	{
		CReplyToCommand(client, "{green}[CCC]{white} Usage: sm_cccaddtrigger trigger value");
		return Plugin_Handled;
	}

	char sTrigger[MAX_CHAT_TRIGGER_LENGTH];
	char sValue[MAX_CHAT_LENGTH];

	GetCmdArg(1, sTrigger, sizeof(sTrigger));
	GetCmdArg(2, sValue, sizeof(sValue));

	if (sTrigger[0] == '\0')
	{
		CReplyToCommand(client, "{green}[CCC]{white} Trigger must be non empty");
		return Plugin_Handled;
	}

	if (sValue[0] == '\0')
	{
		CReplyToCommand(client, "{green}[CCC]{white} Value must be non empty");
		return Plugin_Handled;
	}

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(sTrigger);
	pack.WriteString(sValue);

	SQLInsert_Replace(INVALID_HANDLE, pack);

	return Plugin_Handled;
}

public Action Command_CCCDeleteTrigger(int client, int argc)
{
	if (argc != 1)
	{
		CReplyToCommand(client, "{green}[CCC]{white} Usage: sm_cccdeletetrigger trigger");
		return Plugin_Handled;
	}

	char sTrigger[MAX_CHAT_TRIGGER_LENGTH];

	GetCmdArg(1, sTrigger, sizeof(sTrigger));

	if (sTrigger[0] == '\0')
	{
		CReplyToCommand(client, "{green}[CCC]{white} Trigger must be non empty");
		return Plugin_Handled;
	}

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(sTrigger);

	SQLDelete_Replace(INVALID_HANDLE, pack);

	return Plugin_Handled;
}

public Action Command_ReloadConfig(int client, int args)
{
	LateLoad();

	LogAction(client, -1, "\"%L\" Reloaded Custom Chat Colors config file", client);
	CReplyToCommand(client, "{green}[CCC] {default}Reloaded ccc.");
	Call_StartForward(configReloadedForward);
	Call_Finish();
	return Plugin_Handled;
}

public Action Command_TagMenu(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	Menu_Main(client);
	return Plugin_Stop;
}

public Action Command_SmSay(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_say <message>");
		return Plugin_Handled;
	}

	char text[192];
	GetCmdArgString(text, sizeof(text));

	SendChatToAll(client, text);
	LogAction(client, -1, "\"%L\" triggered sm_say (text %s)", client, text);

	return Plugin_Stop;
}

public Action Command_SmCsay(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_csay <message>");
		return Plugin_Handled;
	}

	char text[192];
	GetCmdArgString(text, sizeof(text));

	DisplayCenterTextToAll(client, text);

	LogAction(client, -1, "\"%L\" triggered sm_csay (text %s)", client, text);

	return Plugin_Handled;
}

public Action Command_SmChat(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_chat <message>");
		return Plugin_Handled;
	}

	char text[192];
	GetCmdArgString(text, sizeof(text));

	SendChatToAdmins(client, text);

	return Plugin_Stop;
}

public Action Command_SmPsay(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_psay <name or #userid> <message>");
		return Plugin_Handled;
	}

	char text[192], arg[64];
	GetCmdArgString(text, sizeof(text));

	int len = BreakString(text, arg, sizeof(arg));

	// We don't allow multi-target filters
	if (arg[0] == '@')
		ReplaceString(arg, sizeof(arg), "@", "");

	int target = FindTarget(client, arg, true, false);
	if (target == -1)
		return Plugin_Handled;

	SendPrivateChat(client, target, text[len]);
	g_iClientFastReply[target] = GetClientUserId(client);
	g_iClientFastReply[client] = GetClientUserId(target);

	return Plugin_Stop;
}

// Original code https://forums.alliedmods.net/showthread.php?p=2355247
public Action Command_SmPsayReply(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_r <message>");
		return Plugin_Handled;
	}

	if (g_iClientFastReply[client] == 0)
	{
		CReplyToCommand(client, "{green}[SM] {default}You cannot reply to anything since you haven't sent or received a private message.");
		return Plugin_Handled;
	}

	if (g_iClientFastReply[client] == -1)
	{
		CReplyToCommand(client, "{green}[SM] {default}You cannot send a private message to a disconnected player.");
		return Plugin_Handled;
	}

	char message[224], arg[32];
	for (int i = 1; i <= args; i++)
	{
		GetCmdArg(i, arg, sizeof(arg));
		Format(message, sizeof(message), "%s %s", message, arg);
	}

	int target = GetClientOfUserId(g_iClientFastReply[client]);
	if (target == -1)
		return Plugin_Handled;

	SendPrivateChat(client, target, message);
	return Plugin_Handled;
}

public Action Command_SmHsay(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_hsay <message>");
		return Plugin_Handled;
	}

	char text[192];
	GetCmdArgString(text, sizeof(text));

	char nameBuf[MAX_NAME_LENGTH];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));
		PrintHintText(i, "%s: %s", nameBuf, text);
	}

	LogAction(client, -1, "\"%L\" triggered sm_hsay (text %s)", client, text);

	return Plugin_Handled;
}

public Action Command_SmDsay(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_dsay <message>");
		return Plugin_Handled;
	}

	char text[192];
	GetCmdArgString(text, sizeof(text));

	char nameBuf[MAX_NAME_LENGTH];
	SetHudTextParams(-1.0, 0.25, 3.0, 0, 255, 127, 255, 1);

	int iHUDChannel = -1;
	int iChannel = g_cvHUDChannel.IntValue;
	if (iChannel < 0 || iChannel > 5)
		iChannel = 0;

#if defined _DynamicChannels_included_
	if (g_bDynamicNative)
		iHUDChannel = GetDynamicChannel(iChannel);
#endif

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));
		ShowHudText(i, iHUDChannel, "%s: %s", nameBuf, text);
	}

	LogAction(client, -1, "\"%L\" triggered sm_dsay (text %s)", client, text);

	return Plugin_Handled;
}

public Action Command_SmTsay(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_tsay <message>");
		return Plugin_Handled;
	}

	char text[192], colorStr[16];
	GetCmdArgString(text, sizeof(text));

	int len = BreakString(text, colorStr, 16);

	int color = FindColor(colorStr);
	char nameBuf[MAX_NAME_LENGTH];

	if (color == -1)
	{
		color = 0;
		len = 0;
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));
		SendDialogToOne(i, color, "%s: %s", nameBuf, text[len]);
	}

	LogAction(client, -1, "\"%L\" triggered sm_tsay (text %s)", client, text);

	return Plugin_Handled;
}

public Action Command_SmMsay(int client, int args)
{
	if (IsVoteInProgress())
	{
		CReplyToCommand(client, "{green}[SM] {default}A vote is in progress, please try again after the vote.");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default} Usage: sm_msay <message>");
		return Plugin_Handled;
	}

	char text[192];
	GetCmdArgString(text, sizeof(text));

	SendPanelToAll(client, text);

	LogAction(client, -1, "\"%L\" triggered sm_msay (text %s)", client, text);

	return Plugin_Handled;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (client <= 0 || (IsClientInGame(client) && BaseComm_IsClientGagged(client)))
		return Plugin_Continue;

#if defined _sourcecomms_included
	if (g_bSourceCommsNative && client)
	{
		if (IsClientInGame(client))
		{
			int IsGagged = SourceComms_GetClientGagType(client);
			if (IsGagged > 0)
				return Plugin_Continue;
		}
	}
#endif
	int startidx;
	if (sArgs[startidx] != CHAT_SYMBOL)
		return Plugin_Continue;

	startidx++;

	if (strcmp(command, "say", false) == 0)
	{
		if (!CheckCommandAccess(client, "sm_psay_chat", ADMFLAG_CHAT))
		{
			return Plugin_Continue;
		}

		char arg[64];

		int len = BreakString(sArgs[startidx], arg, sizeof(arg));
		int target = FindTarget(client, arg, true, false);

		if (target == -1 || len == -1)
			return Plugin_Stop;

		SendPrivateChat(client, target, sArgs[startidx+len]);

		return Plugin_Stop;
	}
	else if (strcmp(command, "say_team", false) == 0 || strcmp(command, "say_squad", false) == 0)
	{
		if (!CheckCommandAccess(client, "sm_chat", ADMFLAG_CHAT) && !g_Cvar_Chatmode.BoolValue)
		{
			return Plugin_Continue;
		}

		SendChatToAdmins(client, sArgs[startidx]);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

int FindColor(const char[] color)
{
	for (int i = 0; i < sizeof(g_ColorNames); i++)
	{
		if (strcmp(color, g_ColorNames[i], false) == 0)
			return i;
	}

	return -1;
}

void SendDialogToOne(int client, int color, const char[] text, any ...)
{
	char message[100];
	VFormat(message, sizeof(message), text, 4);

	KeyValues kv = new KeyValues("Stuff", "title", message);
	kv.SetColor("color", g_Colors[color][0], g_Colors[color][1], g_Colors[color][2], 255);
	kv.SetNum("level", 1);
	kv.SetNum("time", 10);

	CreateDialog(client, kv, DialogType_Msg);

	delete kv;
}

void SendPanelToAll(int from, char[] message)
{
	char title[100];
	Format(title, 64, "%N:", from);

	ReplaceString(message, 192, "\\n", "\n");

	Panel mSayPanel = new Panel();
	mSayPanel.SetTitle(title);
	mSayPanel.DrawItem("", ITEMDRAW_SPACER);
	mSayPanel.DrawText(message);
	mSayPanel.DrawItem("", ITEMDRAW_SPACER);
	mSayPanel.CurrentKey = GetMaxPageItems(mSayPanel.Style);
	mSayPanel.DrawItem("Exit", ITEMDRAW_CONTROL);

	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			mSayPanel.Send(i, Handler_DoNothing, 10);
		}
	}

	delete mSayPanel;
}

public int Handler_DoNothing(Menu menu, MenuAction action, int param1, int param2)
{
	/* Do nothing */
	return 0;
}

void DisplayCenterTextToAll(int client, const char[] message)
{
	char nameBuf[MAX_NAME_LENGTH];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
		{
			continue;
		}
		FormatActivitySource(client, i, nameBuf, sizeof(nameBuf));
		PrintCenterText(i, "%s: %s", nameBuf, message);
	}
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		char text[MAX_CHAT_LENGTH];
		GetCmdArgString(text, sizeof(text));

		if (!HasFlag(client, Admin_Generic) || !HasFlag(client, Admin_Custom1))
		{
			if (MakeStringPrintable(text, sizeof(text), ""))
			{
				return Plugin_Handled;
			}
		}

		if (g_bWaitingForChatInput[client])
		{
			g_bWaitingForChatInput[client] = false;

			if (text[strlen(text)-1] == '"')
				text[strlen(text)-1] = '\0';

			if (strcmp(g_sInputType[client], "ChangeTag", false) == 0 || strcmp(g_sInputType[client], "MenuForceTag", false) == 0)
			{
				if (strlen(text[1]) > 31)
				{
					CReplyToCommand(client, "{green}[CCC]{white} Tag is too long (32 characters max).");
					return Plugin_Handled;
				}
			}

			strcopy(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), text[1]);

			if (strcmp(g_sInputType[client], "ChangeTag", false) == 0)
				ChangeSingleTag(client, client, g_sReceivedChatInput[client], false);
			else if (strcmp(g_sInputType[client], "ColorTag", false) == 0)
				ChangeSingleColor(client, client, "tagcolor", g_sReceivedChatInput[client], false);
			else if (strcmp(g_sInputType[client], "ColorName", false) == 0)
				ChangeSingleColor(client, client, "namecolor", g_sReceivedChatInput[client], false);
			else if (strcmp(g_sInputType[client], "ColorText", false) == 0)
				ChangeSingleColor(client, client, "textcolor", g_sReceivedChatInput[client], false);
			else if (strcmp(g_sInputType[client], "MenuForceTag", false) == 0)
				ChangeSingleTag(client, g_iATarget[client], g_sReceivedChatInput[client], true);
			else if (strcmp(g_sInputType[client], "MenuForceTagColor", false) == 0)
				ChangeSingleColor(client, g_iATarget[client], "tagcolor", g_sReceivedChatInput[client], true);
			else if (strcmp(g_sInputType[client], "MenuForceNameColor", false) == 0)
				ChangeSingleColor(client, g_iATarget[client], "namecolor", g_sReceivedChatInput[client], true);
			else if (strcmp(g_sInputType[client], "MenuForceTextColor", false) == 0)
				ChangeSingleColor(client, g_iATarget[client], "textcolor", g_sReceivedChatInput[client], true);

			return Plugin_Handled;
		}
		else
		{
			if (strcmp(command, "say_team", false) == 0)
				g_msgIsTeammate = true;
			else
				g_msgIsTeammate = false;
		}
	}

	return Plugin_Continue;
}

////////////////////////////////////////////
//Force Tag                            /////
////////////////////////////////////////////

public Action Command_ForceTag(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_forcetag <name|#userid|@filter> <tag text>");
		return Plugin_Handled;
	}

	ChangeTag(client, true);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Force Tag Color                      /////
////////////////////////////////////////////

public Action Command_ForceTagColor(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_forcetagcolor <name|#userid|@filter> <RRGGBB HEX|0-255 0-255 0-255 RGB|Name CODE>");
		return Plugin_Handled;
	}

	ChangeColor(client, "tagcolor", true);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Force Name Color                     /////
////////////////////////////////////////////

public Action Command_ForceNameColor(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_forcenamecolor <name|#userid|@filter> <RRGGBB HEX|0-255 0-255 0-255 RGB|Name CODE>");
		return Plugin_Handled;
	}

	ChangeColor(client, "namecolor", true);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Force Text Color                     /////
////////////////////////////////////////////

public Action Command_ForceTextColor(int client, int args)
{
	if (args < 2)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_forcetextcolor <name|#userid|@filter> <RRGGBB HEX|0-255 0-255 0-255 RGB|Name CODE>");
		return Plugin_Handled;
	}

	ChangeColor(client, "textcolor", true);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Reset Tag & Colors                   /////
////////////////////////////////////////////

public Action Command_CCCReset(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_cccreset <name|#userid|@filter>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	if ((iTarget = FindTarget(client, sTarget, true)) == -1)
	{
		return Plugin_Handled;
	}

	CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Cleared {green}%N's tag {default}&{green} colors{default}.", iTarget);
	RemoveCCC(iTarget);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Ban Tag & Color Changes              /////
////////////////////////////////////////////

public Action Command_CCCBan(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_cccban <name|#userid|@filter> <optional:time>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[64];
	char sTime[128];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	if (args > 1)
	{
		GetCmdArg(2, sTime, sizeof(sTime));
	}

	if ((iTarget = FindTarget(client, sTarget, true)) == -1)
	{
		return Plugin_Handled;
	}

	BanCCC(client, iTarget, sTime);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Allow Tag & Color Changes            /////
////////////////////////////////////////////

public Action Command_CCCUnban(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_cccunban <name|#userid|@filter>");
		return Plugin_Handled;
	}

	int iTarget;
	char sTarget[64];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	if ((iTarget = FindTarget(client, sTarget, true)) == -1)
	{
		return Plugin_Handled;
	}

	UnBanCCC(client, iTarget);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Set Tag                              /////
////////////////////////////////////////////

public Action Command_SetTag(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CReplyToCommand(client, "{green}[SM] {default}Usage: sm_tag <tag text>");
		Menu_Main(client);
		return Plugin_Handled;
	}

	ChangeTag(client, false);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Clear Tag                            /////
////////////////////////////////////////////

public Action Command_ClearTag(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	SetTag("", client);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Set Tag Color                        /////
////////////////////////////////////////////

public Action Command_SetTagColor(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CPrintToChat(client, "{green}[SM] {default}Usage: sm_tagcolor <RRGGBB HEX|0-255 0-255 0-255 RGB|Name CODE>");
		Menu_TagPrefs(client);
		return Plugin_Handled;
	}

	ChangeColor(client, "tagcolor", false);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Clear Tag Color                      /////
////////////////////////////////////////////

public Action Command_ClearTagColor(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	SetColor("tagcolor", "", client);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Set Name Color                       /////
////////////////////////////////////////////

public Action Command_SetNameColor(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CPrintToChat(client, "{green}[SM] {default}Usage: sm_namecolor <RRGGBB HEX|0-255 0-255 0-255 RGB|Name CODE>");
		Menu_NameColor(client);
		return Plugin_Handled;
	}

	ChangeColor(client, "namecolor", false);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Clear Name Color                     /////
////////////////////////////////////////////

public Action Command_ClearNameColor(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	SetColor("namecolor", "", client);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Set Text Color                       /////
////////////////////////////////////////////

public Action Command_SetTextColor(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	if (args < 1)
	{
		CPrintToChat(client, "{green}[SM] {default}Usage: sm_textcolor <RRGGBB HEX|0-255 0-255 0-255 RGB|Name CODE>");
		Menu_ChatColor(client);
		return Plugin_Handled;
	}

	ChangeColor(client, "textcolor", false);

	return Plugin_Handled;
}

////////////////////////////////////////////
//Clear Text Color                     /////
////////////////////////////////////////////

public Action Command_ClearTextColor(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	SetColor("textcolor", "", client);

	return Plugin_Handled;
}

public Action Command_ToggleTag(int client, int args)
{
	if (!client)
	{
		PrintToServer("[CCC] Cannot use command from server console");
		return Plugin_Handled;
	}

	ToggleCCC(client);
	CReplyToCommand(client, "{green}[{red}C{green}C{blue}C{green}]{default} {green}Tag and color{default} displaying %s", g_iClientEnable[client] ? "{red}enabled{default}." : "{green}disabled{default}.");

	return Plugin_Handled;
}

//  888b     d888 8888888888 888b    888 888     888
//  8888b   d8888 888        8888b   888 888     888
//  88888b.d88888 888        88888b  888 888     888
//  888Y88888P888 8888888    888Y88b 888 888     888
//  888 Y888P 888 888        888 Y88b888 888     888
//  888  Y8P  888 888        888  Y88888 888     888
//  888   "   888 888        888   Y8888 Y88b. .d88P
//  888       888 8888888888 888    Y888  "Y88888P"

public void AdminMenu_UnBanList(int client)
{
	Menu MenuAUnBan = new Menu(MenuHandler_AdminUnBan);
	MenuAUnBan.SetTitle("Select a Target (Unban from Tag/Colors)");
	MenuAUnBan.ExitBackButton = true;

	int clients = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsClientBanned(i))
		{
			char info[64];
			char id[32];
			int remaining;
			remaining = ((g_iClientBanned[client] - GetTime()) / 60);

			if (g_iClientBanned[client] == 0)
			{
				Format(info, sizeof(info), "%N (Permanent)", i);
			}
			else
			{
				Format(info, sizeof(info), "%N (%d minutes remaining)", i, remaining);
			}

			Format(id, sizeof(id), "%i", GetClientUserId(i));

			MenuAUnBan.AddItem(id, info);

			clients++;
		}
	}

	if (!clients)
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "No banned clients");
		MenuAUnBan.AddItem("0", sBuffer, ITEMDRAW_DISABLED);
	}

	MenuAUnBan.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_AdminUnBan(Menu MenuAUnBan, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAUnBan);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuAUnBan.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CReplyToCommand(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");

			Menu_Admin(param1);
		}
		else
		{
			UnBanCCC(param1, target);
		}

		Menu_Admin(param1);
	}

	return 0;
}

public void Menu_Main(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuMain = new Menu(MenuHandler_Main);
	MenuMain.SetTitle("Chat Tags & Colors");

	MenuMain.AddItem("Current", "View Current Settings");
	MenuMain.AddItem("Tag", "Tag Options");
	MenuMain.AddItem("Name", "Name Options");
	MenuMain.AddItem("Chat", "Chat Options");

	char sBuffer[128];
	Format(sBuffer, sizeof(sBuffer), "Colors and tag: %s", g_iClientEnable[client] ? "Enabled" : "Disabled");
	MenuMain.AddItem("CCC", sBuffer);

	if (g_bWaitingForChatInput[client])
	{
		MenuMain.AddItem("CancelCInput", "Cancel Chat Input");
	}

	if (HasFlag(client, Admin_Slay) || HasFlag(client, Admin_Cheats))
	{
		MenuMain.AddItem("", "", ITEMDRAW_SPACER);
		MenuMain.AddItem("Admin", "Administrative Options");
	}

	MenuMain.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Main(Menu MenuMain, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		if (param1 != MenuEnd_Selected)
			delete MenuMain;
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		GetMenuItem(MenuMain, param2, Selected, sizeof(Selected));

		if (strcmp(Selected, "Tag", false) == 0)
		{
			Menu_TagPrefs(param1);
		}
		else if (strcmp(Selected, "Name", false) == 0)
		{
			Menu_NameColor(param1);
		}
		else if (strcmp(Selected, "Chat", false) == 0)
		{
			Menu_ChatColor(param1);
		}
		else if (strcmp(Selected, "CCC", false) == 0)
		{
			ToggleCCC(param1);
			CloseHandle(MenuMain);
			Menu_Main(param1);
		}
		else if (strcmp(Selected, "Admin", false) == 0)
		{
			Menu_Admin(param1);
		}
		else if (strcmp(Selected, "CancelCInput", false) == 0)
		{
			g_bWaitingForChatInput[param1] = false;
			g_sInputType[param1] = "";
			Menu_Main(param1);
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cancelled chat input.");
		}
		else if (strcmp(Selected, "Current", false) == 0)
		{
			char sTagF[32];
			char sTagColorF[64];
			char sNameColorF[64];
			char sChatColorF[64];

			Menu hMenuCurrent = new Menu(MenuHandler_Current);
			hMenuCurrent.SetTitle("Current Settings:");
			hMenuCurrent.ExitBackButton = true;

			Format(sTagF, sizeof(sTagF), "Current Tag: %s", g_sClientTag[param1]);
			Format(sTagColorF, sizeof(sTagColorF), "Current Tag Color: %s", g_sClientTagColor[param1]);
			Format(sNameColorF, sizeof(sNameColorF), "Current Name Color: %s", g_sClientNameColor[param1]);
			Format(sChatColorF, sizeof(sChatColorF), "Current Chat Color: %s", g_sClientChatColor[param1]);

			hMenuCurrent.AddItem("sTag", sTagF, ITEMDRAW_DISABLED);
			hMenuCurrent.AddItem("sTagColor", sTagColorF, ITEMDRAW_DISABLED);
			hMenuCurrent.AddItem("sNameColor", sNameColorF, ITEMDRAW_DISABLED);
			hMenuCurrent.AddItem("sChatColor", sChatColorF, ITEMDRAW_DISABLED);

			hMenuCurrent.Display(param1, MENU_TIME_FOREVER);
		}
		else
		{
			PrintToChat(param1, "congrats you broke it");
		}
	}

	return 0;
}

public int MenuHandler_Current(Menu hMenuCurrent, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(hMenuCurrent);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	return 0;
}

public void Menu_Admin(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuAdmin = new Menu(MenuHandler_Admin);
	MenuAdmin.SetTitle("Chat Tags & Colors Admin");
	MenuAdmin.ExitBackButton = true;

	MenuAdmin.AddItem("Reset", "Reset a client's Tag & Colors");
	MenuAdmin.AddItem("Ban", "Ban a client from the Tag & Colors system");
	MenuAdmin.AddItem("Unban", "Unban a client from the Tag & Colors system");

	if (HasFlag(client, Admin_Cheats))
	{
		MenuAdmin.AddItem("ForceTag", "Forcefully change a client's Tag");
		MenuAdmin.AddItem("ForceTagColor", "Forcefully change a client's Tag Color");
		MenuAdmin.AddItem("ForceNameColor", "Forcefully change a client's Name Color");
		MenuAdmin.AddItem("ForceTextColor", "Forcefully change a client's Chat Color");
	}

	MenuAdmin.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Admin(Menu MenuAdmin, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAdmin);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuAdmin.GetItem(param2, Selected, sizeof(Selected));

		if (strcmp(Selected, "Reset", false) == 0)
		{
			Menu MenuAReset = new Menu(MenuHandler_AdminReset);
			MenuAReset.SetTitle("Select a Target (Reset Tag/Colors)");
			MenuAReset.ExitBackButton = true;

			AddTargetsToMenu2(MenuAReset, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAReset.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (strcmp(Selected, "Ban", false) == 0)
		{
			Menu MenuABan = new Menu(MenuHandler_AdminBan);
			MenuABan.SetTitle("Select a Target (Ban from Tag/Colors)");
			MenuABan.ExitBackButton = true;

			AddTargetsToMenu2(MenuABan, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuABan.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (strcmp(Selected, "Unban", false) == 0)
		{
			AdminMenu_UnBanList(param1);
			return 0;
		}
		else if (strcmp(Selected, "ForceTag", false) == 0)
		{
			Menu MenuAFTag = new Menu(MenuHandler_AdminForceTag);
			MenuAFTag.SetTitle("Select a Target (Force Tag)");
			MenuAFTag.ExitBackButton = true;

			AddTargetsToMenu2(MenuAFTag, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAFTag.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (strcmp(Selected, "ForceTagColor", false) == 0)
		{
			Menu MenuAFTColor = new Menu(MenuHandler_AdminForceTagColor);
			MenuAFTColor.SetTitle("Select a Target (Force Tag Color)");
			MenuAFTColor.ExitBackButton = true;

			AddTargetsToMenu2(MenuAFTColor, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAFTColor.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (strcmp(Selected, "ForceNameColor", false) == 0)
		{
			Menu MenuAFNColor = new Menu(MenuHandler_AdminForceNameColor);
			MenuAFNColor.SetTitle("Select a Target (Force Name Color)");
			MenuAFNColor.ExitBackButton = true;

			AddTargetsToMenu2(MenuAFNColor, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAFNColor.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (strcmp(Selected, "ForceTextColor", false) == 0)
		{
			Menu MenuAFTeColor = new Menu(MenuHandler_AdminForceTextColor);
			MenuAFTeColor.SetTitle("Select a Target (Force Text Color)");
			MenuAFTeColor.ExitBackButton = true;

			AddTargetsToMenu2(MenuAFTeColor, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

			MenuAFTeColor.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}
		else if (strcmp(Selected, "CancelCInput", false) == 0)
		{
			g_bWaitingForChatInput[param1] = false;
			g_sInputType[param1] = "";
			Menu_Admin(param1);
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cancelled chat input.");
		}
		else
		{
			PrintToChat(param1, "congrats you broke it");
		}

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminReset(Menu MenuAReset, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAReset);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuAReset.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");

			Menu_Admin(param1);
		}
		else
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Cleared {green}%N's tag {default}&{green} colors{default}.", target);
			RemoveCCC(target);
		}

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminBan(Menu MenuABan, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuABan);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuABan.GetItem(param2, Selected, sizeof(Selected));
		int target;
		int userid = StringToInt(Selected);
		target = GetClientOfUserId(userid);

		if (!target)
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");

			Menu_Admin(param1);
		}
		else
		{
			g_iATarget[param1] = target;
			g_sATargetSID[param1] = g_sSteamIDs[target];

			Menu MenuABTime = new Menu(MenuHandler_AdminBanTime);
			MenuABTime.SetTitle("Select Ban Length");
			MenuABTime.ExitBackButton = true;

			MenuABTime.AddItem("10", "10 Minutes");
			MenuABTime.AddItem("30", "30 Minutes");
			MenuABTime.AddItem("60", "1 Hour");
			MenuABTime.AddItem("1440", "1 Day");
			MenuABTime.AddItem("10080", "1 Week");
			MenuABTime.AddItem("40320", "1 Month");
			MenuABTime.AddItem("0", "Permanent");

			MenuABTime.Display(param1, MENU_TIME_FOREVER);
		}
	}

	return 0;
}

public int MenuHandler_AdminBanTime(Menu MenuABTime, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuABTime);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu MenuABan = new Menu(MenuHandler_AdminBan);
		MenuABan.SetTitle("Select a Target (Ban from Tag/Colors)");
		MenuABan.ExitBackButton = true;

		AddTargetsToMenu2(MenuABan, 0, COMMAND_FILTER_NO_BOTS|COMMAND_FILTER_CONNECTED);

		MenuABan.Display(param1, MENU_TIME_FOREVER);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[128];
		MenuABTime.GetItem(param2, Selected, sizeof(Selected));

		if (!g_iATarget[param1])
		{
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");

			Menu_Admin(param1);
		}

		BanCCC(param1, g_iATarget[param1], Selected);

		Menu_Admin(param1);
	}

	return 0;
}

public void Menu_Input(Menu MenuAF, int param1, int param2, char Key[32])
{
	char Selected[32];
	MenuAF.GetItem(param2, Selected, sizeof(Selected));

	int userid = StringToInt(Selected);
	int target = GetClientOfUserId(userid);

	if (!target)
	{
		CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Player no longer available.");
		Menu_Admin(param1);
	}
	else
	{
		g_iATarget[param1] = target;
		g_sATargetSID[param1] = g_sSteamIDs[target];
		g_bWaitingForChatInput[param1] = true;
		g_sInputType[param1] = Key;
		if (strcmp("MenuForceTag", Key, false) == 0)
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Please enter what you want {green}%N's{default} tag to be.", target);
		else if (strcmp("MenuForceTagColor", Key, false) == 0)
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Please enter what you want {green}%N's{default} tag color to be (#{red}RR{green}GG{blue}BB{default} HEX only!).", target);
		else if (strcmp("MenuForceNameColor", Key, false) == 0)
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Please enter what you want {green}%N's{default} name color to be (#{red}RR{green}GG{blue}BB{default} HEX only!).", target);
		else if (strcmp("MenuForceTextColor", Key, false) == 0)
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}-ADMIN]{default} Please enter what you want {green}%N's{default} text color to be (#{red}RR{green}GG{blue}BB{default} HEX only!).", target);
	}
}

public int MenuHandler_AdminForceTag(Menu MenuAFTag, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAFTag);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		Menu_Input(MenuAFTag, param1, param2, "MenuForceTag");

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminForceTagColor(Menu MenuAFTColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAFTColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		Menu_Input(MenuAFTColor, param1, param2, "MenuForceTagColor");

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminForceNameColor(Menu MenuAFNColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAFNColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		Menu_Input(MenuAFNColor, param1, param2, "MenuForceNameColor");

		Menu_Admin(param1);
	}

	return 0;
}

public int MenuHandler_AdminForceTextColor(Menu MenuAFTeColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuAFTeColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Admin(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		Menu_Input(MenuAFTeColor, param1, param2, "MenuForceTextColor");

		Menu_Admin(param1);
	}

	return 0;
}

public void Menu_TagPrefs(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuTPrefs = new Menu(MenuHandler_TagPrefs);
	MenuTPrefs.SetTitle("Tag Options:");
	MenuTPrefs.ExitBackButton = true;

	MenuTPrefs.AddItem("Reset", "Clear Tag");
	MenuTPrefs.AddItem("ResetColor", "Clear Tag Color");
	MenuTPrefs.AddItem("ChangeTag", "Change Tag (Chat input)");
	MenuTPrefs.AddItem("Color", "Change Tag Color");
	MenuTPrefs.AddItem("ColorTag", "Change Tag Color (Chat input)");

	MenuTPrefs.Display(client, MENU_TIME_FOREVER);
}

public void Menu_AddColors(Menu ColorsMenu)
{
	char info[64];
	StringMap smTrie = CGetTrie();

	if (smTrie!= null && g_sColorsArray != null)
	{
		for (int i = 0; i < g_sColorsArray.Length; i++)
		{
			char key[64];
			char value[64];
			g_sColorsArray.GetString(i, key, sizeof(key));
			smTrie.GetString(key, value, sizeof(value));
			if (IsSource2009() && value[0] == '#')
				Format(info, sizeof(info), "%s (%s)", key, value);
			else
				Format(info, sizeof(info), "%s", key);
			ColorsMenu.AddItem(key, info);
		}
	}
}

public int MenuHandler_TagPrefs(Menu MenuTPrefs, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuTPrefs);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuTPrefs.GetItem(param2, Selected, sizeof(Selected));

		if (strcmp(Selected, "Reset", false) == 0)
		{
			SetTag("", param1);
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cleared your custom {green}tag{default}.");
		}
		else if (strcmp(Selected, "ResetColor", false) == 0)
		{
			if (SetColor("tagcolor", "", param1))
				CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cleared your custom {green}tag color{default}.");
		}
		else if (strcmp(Selected, "ChangeTag", false) == 0)
		{
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "ChangeTag";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Please enter what you want your {green}tag{default} to be.");
		}
		else if (strcmp(Selected, "ColorTag", false) == 0)
		{
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "ColorTag";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Please enter what you want your {green}tag color{default} to be (#{red}RR{green}GG{blue}BB{default} HEX only!).");
		}
		else
		{
			Menu ColorsMenu = new Menu(MenuHandler_TagColorSub);
			ColorsMenu.SetTitle("Pick a color:");
			ColorsMenu.ExitBackButton = true;

			Menu_AddColors(ColorsMenu);

			ColorsMenu.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}

		Menu_Main(param1);
	}

	return 0;
}

public void Menu_NameColor(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuNColor = new Menu(MenuHandler_NameColor);
	MenuNColor.SetTitle("Name Options:");
	MenuNColor.ExitBackButton = true;

	MenuNColor.AddItem("ResetColor", "Clear Name Color");
	MenuNColor.AddItem("Color", "Change Name Color");
	MenuNColor.AddItem("ColorName", "Change Name Color (Chat input)");

	MenuNColor.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_NameColor(Menu MenuNColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuNColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuNColor.GetItem(param2, Selected, sizeof(Selected));

		if (strcmp(Selected, "ResetColor", false) == 0)
		{
			if (SetColor("namecolor", "", param1))
				CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cleared your custom {green}name color{default}.");
		}
		else if (strcmp(Selected, "ColorName", false) == 0)
		{
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "ColorName";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Please enter what you want your {green}name color{default} to be (#{red}RR{green}GG{blue}BB{default} HEX only!).");
		}
		else
		{
			Menu ColorsMenu = new Menu(MenuHandler_NameColorSub);
			ColorsMenu.SetTitle("Pick a color:");
			ColorsMenu.ExitBackButton = true;

			Menu_AddColors(ColorsMenu);

			if (HasFlag(param1, Admin_Cheats))
			{
				ColorsMenu.AddItem("X", "X");
			}

			ColorsMenu.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}

		Menu_Main(param1);
	}

	return 0;
}

public void Menu_ChatColor(int client)
{
	if (IsVoteInProgress())
		return;

	Menu MenuCColor = new Menu(MenuHandler_ChatColor);
	MenuCColor.SetTitle("Chat Options:");
	MenuCColor.ExitBackButton = true;

	MenuCColor.AddItem("ResetColor", "Clear Chat Text Color");
	MenuCColor.AddItem("Color", "Change Chat Text Color");
	MenuCColor.AddItem("ColorText", "Change Chat Text Color (Chat input)");

	MenuCColor.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ChatColor(Menu MenuCColor, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuCColor);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_Main(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[32];
		MenuCColor.GetItem(param2, Selected, sizeof(Selected));

		if (strcmp(Selected, "ResetColor", false) == 0)
		{
			if (SetColor("textcolor", "", param1))
				CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Cleared your custom {green}text color{default}.");
		}
		else if (strcmp(Selected, "ColorText", false) == 0)
		{
			g_bWaitingForChatInput[param1] = true;
			g_sInputType[param1] = "ColorText";
			CPrintToChat(param1, "{green}[{red}C{green}C{blue}C{green}]{default} Please enter what you want your {green}text color{default} to be (#{red}RR{green}GG{blue}BB{default} HEX only!).");
		}
		else
		{
			Menu ColorsMenu = new Menu(MenuHandler_ChatColorSub);
			ColorsMenu.SetTitle("Pick a color:");
			ColorsMenu.ExitBackButton = true;

			Menu_AddColors(ColorsMenu);

			ColorsMenu.Display(param1, MENU_TIME_FOREVER);
			return 0;
		}

		Menu_Main(param1);
	}

	return 0;
}

public int MenuHandler_TagColorSub(Menu MenuTCSub, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuTCSub);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_TagPrefs(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[64];
		MenuTCSub.GetItem(param2, Selected, sizeof(Selected));

		ChangeSingleColor(param1, param1, "tagcolor", Selected, false);

		Menu_TagPrefs(param1);
	}

	return 0;
}

public int MenuHandler_NameColorSub(Menu MenuNCSub, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuNCSub);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_NameColor(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[64];
		MenuNCSub.GetItem(param2, Selected, sizeof(Selected));

		ChangeSingleColor(param1, param1, "namecolor", Selected, false);

		Menu_NameColor(param1);
	}

	return 0;
}

public int MenuHandler_ChatColorSub(Menu MenuCCSub, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(MenuCCSub);
		return 0;
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		Menu_ChatColor(param1);
		return 0;
	}

	if (action == MenuAction_Select)
	{
		char Selected[64];
		MenuCCSub.GetItem(param2, Selected, sizeof(Selected));

		ChangeSingleColor(param1, param1, "textcolor", Selected, false);

		Menu_ChatColor(param1);
	}

	return 0;
}

//  88888888888     d8888  .d8888b.        .d8888b.  8888888888 88888888888 88888888888 8888888 888b    888  .d8888b.
//      888        d88888 d88P  Y88b      d88P  Y88b 888            888         888       888   8888b   888 d88P  Y88b
//      888       d88P888 888    888      Y88b.      888            888         888       888   88888b  888 888    888
//      888      d88P 888 888              "Y888b.   8888888        888         888       888   888Y88b 888 888
//      888     d88P  888 888  88888          "Y88b. 888            888         888       888   888 Y88b888 888  88888
//      888    d88P   888 888    888            "888 888            888         888       888   888  Y88888 888    888
//      888   d8888888888 Y88b  d88P      Y88b  d88P 888            888         888       888   888   Y8888 Y88b  d88P
//      888  d88P     888  "Y8888P88       "Y8888P"  8888888888     888         888     8888888 888    Y888  "Y8888P88

stock void ClearValues(int client)
{
	g_iClientEnable[client] = 1;
	Format(g_sClientTag[client], sizeof(g_sClientTag[]), "");
	Format(g_sClientTagColor[client], sizeof(g_sClientTagColor[]), "");
	Format(g_sClientNameColor[client], sizeof(g_sClientNameColor[]), "");
	Format(g_sClientChatColor[client], sizeof(g_sClientChatColor[]), "");

	g_iDefaultClientEnable[client] = 1;
	Format(g_sDefaultClientTag[client], sizeof(g_sDefaultClientTag[]), "");
	Format(g_sDefaultClientTagColor[client], sizeof(g_sDefaultClientTagColor[]), "");
	Format(g_sDefaultClientNameColor[client], sizeof(g_sDefaultClientNameColor[]), "");
	Format(g_sDefaultClientChatColor[client], sizeof(g_sDefaultClientChatColor[]), "");
}

stock void ResetClient(int client)
{
	Format(g_sReceivedChatInput[client], sizeof(g_sReceivedChatInput[]), "");
	Format(g_sInputType[client], sizeof(g_sInputType[]), "");
	Format(g_sATargetSID[client], sizeof(g_sATargetSID[]), "");
	g_bWaitingForChatInput[client] = false;
	g_iClientFastReply[client] = 0;
	g_iATarget[client] = 0;
	g_sClientSID[client] = "";
	g_sSteamIDs[client] = "";
	ClearValues(client);
}

public bool IsClientEnabled()
{
	return (HasFlag(g_msgAuthor, Admin_Generic) || HasFlag(g_msgAuthor, Admin_Custom1)) && g_iClientEnable[g_msgAuthor];
}

public Action Hook_UserMessage(UserMsg msg_id, Handle bf, const int[] players, int playersNum, bool reliable, bool init)
{
	char sAuthorTag[64];

	if (g_bProto)
	{
		g_msgAuthor = PbReadInt(bf, "ent_idx");
		g_msgIsChat = PbReadBool(bf, "chat");
		PbReadString(bf, "msg_name", g_msgName, sizeof(g_msgName));
		PbReadString(bf, "params", g_msgSender, sizeof(g_msgSender), 0);
		PbReadString(bf, "params", g_msgText, sizeof(g_msgText), 1);
	}
	else
	{
		g_msgAuthor = BfReadByte(bf);
		g_msgIsChat = view_as<bool>(BfReadByte(bf));
		BfReadString(bf, g_msgName, sizeof(g_msgName), false);
		BfReadString(bf, g_msgSender, sizeof(g_msgSender), false);
		BfReadString(bf, g_msgText, sizeof(g_msgText), false);
	}

	if (g_msgAuthor < 0 || g_msgAuthor > MaxClients)
		return Plugin_Continue;

	if (strlen(g_msgName) == 0 || strlen(g_msgSender) == 0)
		return Plugin_Continue;

	if (!strcmp(g_msgName, "#Cstrike_Name_Change"))
		return Plugin_Continue;

	TrimString(g_msgText);

	if (strlen(g_msgText) == 0)
		return Plugin_Handled;


	bool bIsAction;
	char sNameColorKey[32];
	char sChatColorKey[32];
	char sTagColorKey[32];

	Format(sAuthorTag, sizeof(sAuthorTag), "%s", g_sClientTag[g_msgAuthor]);
	bool bNameFound = GetColorKey(g_msgAuthor, view_as<CCC_ColorType>(CCC_NameColor), sNameColorKey, sizeof(sNameColorKey));
	bool bChatFound = GetColorKey(g_msgAuthor, view_as<CCC_ColorType>(CCC_ChatColor), sChatColorKey, sizeof(sChatColorKey));
	bool bTagFound = GetColorKey(g_msgAuthor, view_as<CCC_ColorType>(CCC_TagColor), sTagColorKey, sizeof(sTagColorKey));

	if (!strncmp(g_msgText, "/me", 3, false))
	{
		strcopy(g_msgName, sizeof(g_msgName), "Cstrike_Chat_Me");
		strcopy(g_msgText, sizeof(g_msgText), g_msgText[4]);
		bIsAction = true;
	}

	if (GetConVarInt(g_cvar_ReplaceText) > 0)
	{
		char sPart[MAX_CHAT_LENGTH];
		char sBuff[MAX_CHAT_LENGTH];
		int CurrentIndex = 0;
		int NextIndex = 0;

		while (NextIndex != -1 && CurrentIndex < sizeof(g_msgText))
		{
			NextIndex = BreakString(g_msgText[CurrentIndex], sPart, sizeof(sPart));

			sBuff = "";
			for (int i = 0; i < g_iReplaceListSize; i++)
			{
				if (strcmp(g_sReplaceList[i][0], sPart, false) == 0)
				{
					Format(sBuff, sizeof(sBuff), "%s", g_sReplaceList[i][1]);
					break;
				}
			}

			if (sBuff[0])
			{
				ReplaceString(g_msgText[CurrentIndex], sizeof(g_msgText) - CurrentIndex, sPart, sBuff);
				CurrentIndex += strlen(sBuff);
			}
			else
				CurrentIndex += NextIndex;
		}
	}

	char sValue[32];
	if (!bIsAction && IsClientEnabled())
	{
		if (!bNameFound)
			sNameColorKey = "teamcolor";

		Format(g_msgSender, sizeof(g_msgSender), "{%s%s}%s", GetColor(sNameColorKey, sValue, sizeof(sValue)) ? "#" : "", sNameColorKey, g_msgSender);

		if (strlen(sAuthorTag) > 0)
			Format(g_msgSender, sizeof(g_msgSender), "{%s%s}%s%s", GetColor(sTagColorKey, sValue, sizeof(sValue)) ? "#" : "", bTagFound ? sTagColorKey : "default", sAuthorTag, g_msgSender);

		if (strlen(g_sClientTag[g_msgAuthor]) > strlen(sAuthorTag) && IsClientInGame(g_msgAuthor))
		{
			CPrintToChat(g_msgAuthor, "{green}[{red}C{green}C{blue}C{green}]{default} Your tag is longer than 32 characters and has been truncated for display.");
		}

		StringMap smTrie = CGetTrie();
		if (g_msgText[0] == '>' && GetConVarInt(g_cvar_GreenText) > 0 && smTrie.GetString("green", sValue, sizeof(sValue)))
			Format(g_msgText, sizeof(g_msgText), "{green}%s", g_msgText);

		if (bChatFound)
			Format(g_msgText, sizeof(g_msgText), "{%s%s}%s", GetColor(sChatColorKey, sValue, sizeof(sValue)) ? "#" : "", sChatColorKey, g_msgText);
	}

	if (!bIsAction && IsSource2009() && (!IsClientEnabled() || (IsClientEnabled() && g_msgAuthor && g_sClientTag[g_msgAuthor][0] == '\0')))
	{
		sNameColorKey = "teamcolor";
		Format(g_msgSender, sizeof(g_msgSender), "{%s%s}%s", GetColor(sNameColorKey, sValue, sizeof(sValue)) ? "#" : "", sNameColorKey, g_msgSender);
		CFormatColor(g_msgSender, sizeof(g_msgSender), g_msgAuthor);
	}

	SetGlobalTransTarget(g_msgAuthor);
	Format(g_msgFinal, sizeof(g_msgFinal), "%t", g_msgName, g_msgSender, g_msgText);

	if (!g_msgAuthor || IsClientEnabled())
	{
		CFormatColor(g_msgFinal, sizeof(g_msgFinal), g_msgAuthor);
		CAddWhiteSpace(g_msgFinal, sizeof(g_msgFinal));
	}

	return Plugin_Handled;
}

public Action Event_PlayerSay(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_msgAuthor == -1 || GetClientOfUserId(GetEventInt(event, "userid")) != g_msgAuthor)
		return Plugin_Continue;

	if (strlen(g_msgText) == 0)
		return Plugin_Continue;

	int[] players = new int[MaxClients + 1];
	int playersNum = 0;

	if (g_msgIsTeammate && g_msgAuthor > 0)
	{
		int team = GetClientTeam(g_msgAuthor);

		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && GetClientTeam(client) == team)
			{
				if (!g_Ignored[client * (MAXPLAYERS + 1) + g_msgAuthor])
					players[playersNum++] = client;
			}
		}
	}
	else
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				if (!g_Ignored[client * (MAXPLAYERS + 1) + g_msgAuthor])
					players[playersNum++] = client;
			}
		}
	}

	if (!playersNum)
	{
		g_msgAuthor = -1;
		return Plugin_Continue;
	}

	Handle SayText2 = StartMessage("SayText2", players, playersNum, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);

	if (g_bProto)
	{
		PbSetInt(SayText2, "ent_idx", g_msgAuthor);
		PbSetBool(SayText2, "chat", g_msgIsChat);
		PbSetString(SayText2, "msg_name", g_msgFinal);
		PbAddString(SayText2, "params", "");
		PbAddString(SayText2, "params", "");
		PbAddString(SayText2, "params", "");
		PbAddString(SayText2, "params", "");
	}
	else
	{
		BfWriteByte(SayText2, g_msgAuthor);
		BfWriteByte(SayText2, g_msgIsChat);
		BfWriteString(SayText2, g_msgFinal);
	}

	EndMessage();
	g_msgAuthor = -1;

	return Plugin_Continue;
}

public Action OnToggleCCCSettings(int client, int args)
{
	ToggleCCCSettings(client);
	return Plugin_Handled;
}

public void ToggleCCCSettings(int client)
{
	if (!client || IsFakeClient(client))
		return;

	if (!AreClientCookiesCached(client))
	{
		CPrintToChat(client, "{green}[CCC]{default} Please wait, your settings are retrieved...");
		return;
	}

	g_bDisablePsay[client] = !g_bDisablePsay[client];
	SetClientCookie(client, g_hCookie_DisablePsay, g_bDisablePsay[client] ? "1" : "");

	CPrintToChat(client, "{green}[CCC]{default} Private messages has been %s.", g_bDisablePsay[client] ? "{red}disabled" : "{green}enabled");
}

public Action Command_PsayStatus(int client, int args)
{
	if (args > 1)
		CPrintToChat(client, "{green}[CCC]{default} Usage sm_pstatus <name or #userid>");

	if (args == 0)
		CPrintToChat(client, "{green}[CCC]{default} Your private messages are %s{default}.", g_bDisablePsay[client] ? "{red}disabled" : "{green}enabled");

	if (args == 1)
	{
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		int target = FindTarget(client, arg1, false, false);
		if (target == -1)
			return Plugin_Handled;

		CPrintToChat(client, "{green}[CCC]{default} Private messages are %s{default} for {olive}%N{default}.", g_bDisablePsay[target] ? "{red}disabled" : "{green}enabled", target);
	}

	return Plugin_Handled;
}

public void ShowSettingsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_MainMenu, MENU_ACTIONS_ALL);
	menu.SetTitle("CustomChatColors Settings", client);

	char sPsay[128], sTag[128];
	Format(sPsay, sizeof(sPsay), "Private messages: %s", g_bDisablePsay[client] ? "Disabled" : "Enabled");
	Format(sTag, sizeof(sTag), "Tag Settings");

	menu.AddItem("0", sPsay);
	menu.AddItem("1", sTag);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MainMenu(Menu menu, MenuAction action, int client, int selection)
{
	switch(action)
	{
		case(MenuAction_Select):
		{
			switch(selection)
			{
				case(0):
				{
					ToggleCCCSettings(client);
					ShowSettingsMenu(client);
				}
				case(1):
				{
					Menu_Main(client);
				}
			}
		}
		case(MenuAction_Cancel):
		{
			ShowCookieMenu(client);
		}
		case(MenuAction_End):
		{
			delete menu;
		}
	}
	return 0;
}

public void MenuHandler_CookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch(action)
	{
		case(CookieMenuAction_DisplayOption):
		{
			Format(buffer, maxlen, "CustomChatColors Settings", client);
		}
		case(CookieMenuAction_SelectOption):
		{
			ShowSettingsMenu(client);
		}
	}
}

//  888b    888        d8888 88888888888 8888888 888     888 8888888888 .d8888b.
//  8888b   888       d88888     888       888   888     888 888       d88P  Y88b
//  88888b  888      d88P888     888       888   888     888 888       Y88b.
//  888Y88b 888     d88P 888     888       888   Y88b   d88P 8888888    "Y888b.
//  888 Y88b888    d88P  888     888       888    Y88b d88P  888           "Y88b.
//  888  Y88888   d88P   888     888       888     Y88o88P   888             "888
//  888   Y8888  d8888888888     888       888      Y888P    888       Y88b  d88P
//  888    Y888 d88P     888     888     8888888     Y8P     8888888888 "Y8888P"

stock bool ConfigForward(int client)
{
	Action myresult = Plugin_Continue;

	Call_StartForward(preLoadedForward);
	Call_PushCell(client);
	Call_Finish(myresult);

	if (myresult >= Plugin_Handled)
		return false;

	return true;
}

stock bool GetColorKey(int client, CCC_ColorType colorType, char[] key, int size, bool skipChecks = false)
{
	if (!skipChecks && (!client || client > MaxClients || !IsClientInGame(client)))
		return false;

	StringMap smTrie = CGetTrie();
	bool bFound = true;
	char value[32];

	strcopy(key, size, "");

	switch(colorType)
	{
		case CCC_TagColor:
		{
			if (strcmp(g_sClientTagColor[client], "T", false) == 0)
				strcopy(key, size, "teamcolor");
			else if (strcmp(g_sClientTagColor[client], "G", false) == 0)
				strcopy(key, size, "green");
			else if (strcmp(g_sClientTagColor[client], "O", false) == 0)
				strcopy(key, size, "olive");
			else if (IsSource2009() && IsValidHex(g_sClientTagColor[client]))
				strcopy(key, size, g_sClientTagColor[client]);
			else if (smTrie.GetString(g_sClientTagColor[client], value, sizeof(value)))
				strcopy(key, size, g_sClientTagColor[client]);
			else
				bFound = false;
		}

		case CCC_NameColor:
		{
			if (strcmp(g_sClientNameColor[client], "G", false) == 0)
				strcopy(key, size, "green");
			else if (strcmp(g_sClientNameColor[client], "X", false) == 0)
				strcopy(key, size, "");
			else if (strcmp(g_sClientNameColor[client], "O", false) == 0)
				strcopy(key, size, "olive");
			else if (IsSource2009() && IsValidHex(g_sClientNameColor[client]))
				strcopy(key, size, g_sClientNameColor[client]);
			else if (smTrie.GetString(g_sClientNameColor[client], value, sizeof(value)))
				strcopy(key, size, g_sClientNameColor[client]);
			else
				bFound = false;
		}

		case CCC_ChatColor:
		{
			if (strcmp(g_sClientChatColor[client], "T", false) == 0)
				strcopy(key, size, "teamcolor");
			else if (strcmp(g_sClientChatColor[client], "G", false) == 0)
				strcopy(key, size, "green");
			else if (strcmp(g_sClientChatColor[client], "O", false) == 0)
				strcopy(key, size, "olive");
			else if (IsSource2009() && IsValidHex(g_sClientChatColor[client]))
				strcopy(key, size, g_sClientChatColor[client]);
			else if (smTrie.GetString(g_sClientChatColor[client], value, sizeof(value)))
				strcopy(key, size, g_sClientChatColor[client]);
			else
				bFound = false;
		}
		default:
		{
			bFound = false;
		}
	}
	return bFound;
}

public int Native_GetColorKey(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return false;
	}

	CCC_ColorType colorType = view_as<CCC_ColorType>(GetNativeCell(2));
	int size = GetNativeCell(4);

	char[] key = new char[size];

	bool bFound = GetColorKey(client, colorType, key, size, true);

	SetNativeString(3, key, size);

	return bFound;
}

stock bool GetColor(char key[32], char[] value, int size)
{
	if (IsSource2009() && IsValidHex(key))
	{
		strcopy(value, size, key);
		return true;
	}
	StringMap smTrie = CGetTrie();
	smTrie.GetString(key, value, size);
	return false;
}

public int Native_GetColor(Handle plugin, int numParams)
{
	char key[32];
	GetNativeString(1, key, sizeof(key));

	int size = GetNativeCell(3);

	char[] value = new char[size];

	bool bAlpha = GetColor(key, value, size);

	SetNativeString(2, value, size);

	return bAlpha;
}

public int Native_SetColor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	char color[32];

	if (GetNativeCell(3) < 0)
	{
		switch (GetNativeCell(3))
		{
			case COLOR_CGREEN:
			{
				Format(color, sizeof(color), "G");
			}
			case COLOR_OLIVE:
			{
				Format(color, sizeof(color), "O");
			}
			case COLOR_TEAM:
			{
				Format(color, sizeof(color), "T");
			}
			case COLOR_NULL:
			{
				Format(color, sizeof(color), "X");
			}
			case COLOR_NONE:
			{
				Format(color, sizeof(color), "");
			}
		}
	}
	else
	{
		if (!GetNativeCell(4))
		{
			// No alpha
			Format(color, sizeof(color), "%06X", GetNativeCell(3));
		}
		else
		{
			// Alpha specified
			Format(color, sizeof(color), "%08X", GetNativeCell(3));
		}
	}

	if (strlen(color) != 6 && strlen(color) != 8 && !StrEqual(color, "G", false) && !StrEqual(color, "O", false) && !StrEqual(color, "T", false) && !StrEqual(color, "X", false))
	{
		return 0;
	}

	switch (GetNativeCell(2))
	{
		case CCC_TagColor:
		{
			strcopy(g_sClientTagColor[client], sizeof(g_sClientTagColor[]), color);
		}
		case CCC_NameColor:
		{
			strcopy(g_sClientNameColor[client], sizeof(g_sClientNameColor[]), color);
		}
		case CCC_ChatColor:
		{
			strcopy(g_sClientChatColor[client], sizeof(g_sClientChatColor[]), color);
		}
	}

	return 1;
}

public int Native_GetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	SetNativeString(2, g_sClientTag[client], GetNativeCell(3));
	return 1;
}

public int Native_SetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	char tempTag[32];
	GetNativeString(2, tempTag, sizeof(tempTag));

	if (strlen(tempTag) > 31)
	{
		tempTag[31] = '\0';
	}

	strcopy(g_sClientTag[client], sizeof(g_sClientTag[]), tempTag);
	return 1;
}

public int Native_ResetColor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	switch(GetNativeCell(2))
	{
		case CCC_TagColor:
		{
			strcopy(g_sClientTagColor[client], sizeof(g_sClientTagColor[]), g_sDefaultClientTagColor[client]);
		}
		case CCC_NameColor:
		{
			strcopy(g_sClientNameColor[client], sizeof(g_sClientNameColor[]), g_sDefaultClientNameColor[client]);
		}
		case CCC_ChatColor:
		{
			strcopy(g_sClientChatColor[client], sizeof(g_sClientChatColor[]), g_sDefaultClientChatColor[client]);
		}
	}

	return 1;
}

public int Native_ResetTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}

	strcopy(g_sClientTag[client], sizeof(g_sClientTag[]), g_sDefaultClientTag[client]);
	return 1;
}

public int Native_UpdateIgnoredArray(Handle plugin, int numParams)
{
	GetNativeArray(1, g_Ignored, sizeof(g_Ignored));

	return 1;
}

public int Native_UnLoadClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}
	OnClientDisconnect(client);
	return 1;
}

public int Native_LoadClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!client || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_PARAM, "Invalid client or client is not in game");
		return 0;
	}
	OnClientPostAdminCheck(client);
	return 1;
}

public int Native_ReloadConfig(Handle plugin, int numParams)
{
	LateLoad();
	return 1;
}

public int Native_IsClientEnabled(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return (HasFlag(client, Admin_Generic) || HasFlag(client, Admin_Custom1)) && g_iClientEnable[client];
}

public Action Timer_DelayedDBConnectCCC(Handle timer, any data)
{
	g_bDBConnectDelayActive = false;
	DB_Connect();
	LateLoad();
	return Plugin_Stop;
}
