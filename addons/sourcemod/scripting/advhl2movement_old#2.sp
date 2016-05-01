/*****************************************************************


C O M P I L E   O P T I O N S


*****************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1


/*****************************************************************


P L U G I N   I N C L U D E S


*****************************************************************/
#include <sourcemod>
#include <sdktools>
//#include <smlib>
#include <masterhook>

/*****************************************************************


P L U G I N   I N F O


*****************************************************************/
#define PLUGIN_NAME				"Advanced HL2 Movement"
#define PLUGIN_SHORTNAME		"advhl2movement"
#define PLUGIN_AUTHOR			"Chanz"
#define PLUGIN_DESCRIPTION		"This plugin enables advanced Half-Life 2 Multiplayer movement, such as bhop without delay."
#define PLUGIN_VERSION 			"0.2.4"
#define PLUGIN_URL				"http://www.mannisfunhouse.eu/"

public Plugin:myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}

/*****************************************************************


P L U G I N   D E F I N E S


*****************************************************************/
#define WHAT_ADMIN_IS_DEVELOPER Admin_Root


/*****************************************************************


G L O B A L   V A R S


*****************************************************************/
// ConVar Handles
new Handle:g_cvar_Version;
new Handle:g_cvar_Enable;
new Handle:g_cvar_FastGravGun;
new Handle:g_cvar_ShaftSprint;
new Handle:g_cvar_Debug;

//ConVars runtime saver:
new g_iPluginEnable;
new g_iPluginFastGravGun;
new g_iPluginShaftSprint;
new g_iPluginDebug;

// Misc
new bool:g_bIsDeveloper[MAXPLAYERS+1];

/*****************************************************************


F O R W A R D   P U B L I C S


*****************************************************************/

public OnPluginStart(){
	
	//Init for first or late load
	Plugin_LoadInit();
	
	decl String:pluginFileName[PLATFORM_MAX_PATH];
	GetPluginFilename(INVALID_HANDLE,pluginFileName,sizeof(pluginFileName));
	decl String:cvarVersionInfo[512];
	Format(cvarVersionInfo,sizeof(cvarVersionInfo),"\n  || %s ('%s') v%s\n  || Builddate:'%s - %s'\n  || Author(s):'%s'\n  || URL:'%s'\n  || Description:'%s'",PLUGIN_NAME,pluginFileName,PLUGIN_VERSION,__TIME__,__DATE__,PLUGIN_AUTHOR,PLUGIN_URL,PLUGIN_DESCRIPTION);
	g_cvar_Version = CreateConVar("sm_advhl2movement_version", PLUGIN_VERSION, cvarVersionInfo, FCVAR_PLUGIN|FCVAR_DONTRECORD|FCVAR_NOTIFY);
	SetConVarString(g_cvar_Version,PLUGIN_VERSION);
	
	//Cvars
	g_cvar_Enable = CreateConVar("sm_advhl2movement_enable", "1", "Enables or Disables Advanced HL2 Movement (1=Enable|0=Disabled)",FCVAR_PLUGIN|FCVAR_NOTIFY,true,0.0,true,1.0);
	g_cvar_FastGravGun = CreateConVar("sm_advhl2movement_fastgravgun", "1", "Enables or Disables debug mode of Advanced HL2 Movement (2=SendToClient|1=Enable|0=Disabled)",FCVAR_PLUGIN|FCVAR_DONTRECORD,true,0.0,true,2.0);
	g_cvar_ShaftSprint = CreateConVar("sm_advhl2movement_shaftsprint", "1", "Enables or Disables debug mode of Advanced HL2 Movement (2=SendToClient|1=Enable|0=Disabled)",FCVAR_PLUGIN|FCVAR_DONTRECORD,true,0.0,true,2.0);
	g_cvar_Debug = CreateConVar("sm_advhl2movement_debug", "0", "Enables or Disables debug mode of Advanced HL2 Movement (2=SendToClient|1=Enable|0=Disabled)",FCVAR_PLUGIN|FCVAR_DONTRECORD,true,0.0,true,2.0);
	
	
	//Cvar Runtime optimizer
	g_iPluginEnable = GetConVarInt(g_cvar_Enable);
	g_iPluginFastGravGun = GetConVarInt(g_cvar_FastGravGun);
	g_iPluginShaftSprint = GetConVarInt(g_cvar_ShaftSprint);
	g_iPluginDebug = GetConVarInt(g_cvar_Debug);

	//Cvar Hooks
	HookConVarChange(g_cvar_Enable,ConVarChange_Enable);
	HookConVarChange(g_cvar_FastGravGun,ConVarChange_FastGravGun);
	HookConVarChange(g_cvar_ShaftSprint,ConVarChange_ShaftSprint);
	HookConVarChange(g_cvar_Debug,ConVarChange_Debug);
	
	
	//Masterhook
	Mh_HookFunction("CHL2_Player::StopSprinting", ValveLibrary_Server, Mh_Callback_StopSprint, MhDataType_Void);
	Mh_HookFunction("CBasePlayer::GetPlayerMaxSpeed", ValveLibrary_Server, Mh_Callback_GetPlayerMaxSpeed, MhDataType_Float);
	//Mh_HookFunction("CHL2_Player::HandleSpeedChanges", ValveLibrary_Server, Mh_Callback_HandleSpeedChanges, MhDataType_Void);
	
	AutoExecConfig(true,"plugin.advhl2movement");
	
	//Show the dev that he is loading the right plugin
	Server_PrintDebug(cvarVersionInfo);
}

public OnPluginEnd(){
	
	PrintToServer("[MASTERHook] Test: %d\n", Mh_UnhookFunction("CHL2_Player::StopSprinting", Mh_Callback_StopSprint));
	PrintToServer("[MASTERHook] Test#2: %d\n", Mh_UnhookFunction("CBasePlayer::GetPlayerMaxSpeed", Mh_Callback_GetPlayerMaxSpeed));
	//PrintToServer("[MASTERHook] Test#2: %d\n", Mh_UnhookFunction("CHL2_Player::HandleSpeedChanges", Mh_Callback_HandleSpeedChanges));
}


public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon){
	
	if(g_iPluginEnable == 0){
		
		Server_PrintDebug("Plugin is disabled");
		return Plugin_Continue;
	}
	
	if(IsFakeClient(client)){
		
		Client_PrintDebug(client,"you are a bot -> no plugin action",client);
		return Plugin_Continue;
	}
	
	if(buttons == 0){
		return Plugin_Continue;
	}
	
	//SetEntProp(client,Prop_Send,"m_bSpeedCropped",1,1);
	
	/*new entityFlags = GetEntityFlags(client);
	
	if(entityFlags & FL_DUCKING){
		
		new Float:flForward = GetEntPropFloat(client,Prop_Data,"m_flForwardMove");
		new Float:slSide = GetEntPropFloat(client,Prop_Data,"m_flSideMove");
		
		Client_PrintDebug(client,"#b: forward move: %f; sidemove: %f",flForward,slSide);
		
		SetEntPropFloat(client,Prop_Data,"m_flForwardMove",flForward*3);
		SetEntPropFloat(client,Prop_Data,"m_flSideMove",slSide*3);
		
		flForward = GetEntPropFloat(client,Prop_Data,"m_flForwardMove");
		slSide = GetEntPropFloat(client,Prop_Data,"m_flSideMove");
		
		Client_PrintDebug(client,"#a: forward move: %f; sidemove: %f",flForward,slSide);
	}*/
	
	/*
	new m_fIsSprinting = GetEntProp(client,Prop_Data,"m_fIsSprinting",1);
	//new Float:m_flSuitPowerLoad = GetEntPropFloat(client, Prop_Data, "m_flSuitPowerLoad");
	
	new sprintButton = -1;
	
	if(buttons & IN_SPEED){
		sprintButton = 1;
	}
	else {
		sprintButton = 0;
	}
	
	//Client_PrintDebug(client,"Flags: %d; Buttons: %d;",entityFlags,buttons);
	//Client_PrintDebug(client,"SprintButton: %d; m_fIsSprinting: %d;",sprintButton,m_fIsSprinting);
	//Client_PrintDebug(client,"m_flSuitPowerLoad: %f",m_flSuitPowerLoad);
	
	if(g_iLastButtons[client] & IN_SPEED){
		SetEntProp(client,Prop_Data,"m_fIsSprinting",1,1);
		SetEntProp(client,Prop_Data,"m_bDucked",0,1);
		SetEntProp(client,Prop_Data,"m_bDucking",0,1);
	}
	
	//Client_PrintDebug(client,"plugin enable: %d; plugin debug: %d",g_iPluginEnable,g_iPluginDebug);
	
	switch(g_iPluginEnable){
		
		case 1:{
			
			if((buttons & IN_SPEED) && !(buttons & IN_DUCK) && (m_fIsSprinting == 0)){
				
				if(g_bFlipFlopSpeed[client]){
					
					buttons &= ~IN_SPEED;
					//SetEntProp(client,Prop_Data,"m_fIsSprinting",1,1);
					g_bFlipFlopSpeed[client] = false;
					Client_PrintDebug(client,"flip (m_fIsSprinting: %d)",m_fIsSprinting);
				}
				else {
					
					//SetEntProp(client,Prop_Data,"m_fIsSprinting",0,1);
					g_bFlipFlopSpeed[client] = true;
					Client_PrintDebug(client,"flop (m_fIsSprinting: %d)",m_fIsSprinting);
				}
			}
		}
		case 2:{
			//Client_PrintDebug(client,"mode2: sprint: %d; duck: %d; powerload: %f",(buttons & IN_SPEED),(buttons & IN_DUCK),m_flSuitPowerLoad);
			
			//if((buttons & IN_FORWARD) || (buttons & IN_BACK) || (buttons & IN_MOVELEFT) || (buttons & IN_MOVERIGHT)){
			
			//if((buttons & IN_SPEED) && !(buttons & IN_DUCK)){
				
				//SetEntProp(client,Prop_Data,"m_bSprintEnabled",1,1);
				//SetEntProp(client,Prop_Data,"m_bDucked",0,1);
				//SetEntProp(client,Prop_Data,"m_bDucking",1,1);
				//SetEntProp(client,Prop_Data,"m_fIsWalking",0,1);
				
				
				//SetEntProp(client,Prop_Data,"m_fIsSprinting",0,1);
				//SetEntPropFloat(client,Prop_Data,"m_flSuitPowerLoad",25.0);
				
				//Client_PrintDebug(client,"client  run");
				//Client_Walk(client);
				//vel[0] = g_fPluginSprintSpeed;
			//}
			//}
		}
	}
	
	//m_fIsSprinting = GetEntProp(client,Prop_Data,"m_fIsSprinting",1);
	//Client_PrintDebug(client,"#2 SprintButton: %d; m_fIsSprinting: %d;",sprintButton,m_fIsSprinting);
	*/
	return Plugin_Changed;
}

public OnClientDisconnect(client){
	
	Client_InitVars(client);
}

public OnClientPostAdminCheck(client){
	
	Client_InitVars(client);
}

/****************************************************************


C A L L B A C K   F U N C T I O N S


****************************************************************/
public ConVarChange_Enable(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPluginEnable = StringToInt(newVal);
}

public ConVarChange_FastGravGun(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPluginFastGravGun = StringToInt(newVal);
}

public ConVarChange_ShaftSprint(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPluginShaftSprint = StringToInt(newVal);
}

public ConVarChange_Debug(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPluginDebug = StringToInt(newVal);
}

public Action:Mh_Callback_StopSprint(&client){
	
	if(g_iPluginEnable != 1){
		return Plugin_Continue;
	}
	
	if((GetClientButtons(client) & IN_SPEED) && (Client_GetSuitSprintPower(client) > 0.0)){
		
		return Plugin_Handled;
	}
	else {
		
		return Plugin_Continue;
	}
}

public Action:Mh_Callback_GetPlayerMaxSpeed(&client){
	
	if(g_iPluginShaftSprint != 1){
		return Plugin_Continue;
	}
	
	
	
	new entityFlags = GetEntityFlags(client);
	new buttons = GetClientButtons(client);
	
	if((entityFlags & FL_DUCKING) && (buttons & IN_SPEED) && (Client_GetSuitSprintPower(client) > 0.0)){
		
		PrintToChat(client,"setting your maxspeed to 920.0");
		Mh_SetReturnValue(100);
		return Plugin_Handled;
	}
	else if(entityFlags & FL_DUCKING){
		
		PrintToChat(client,"setting your maxspeed to 570.0");
		Mh_SetReturnValue(1);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}
/*
public Action:Mh_Callback_HandleSpeedChanges(&client){
	
	if(g_iPluginShaftSprint != 1){
		return Plugin_Continue;
	}
	
	PrintToChatAll("handle speed changes called by client: %d (%N)",client,client);
	
	//new buttons = GetClientButtons(client);
	
	
	
	SetEntProp(client,Prop_Data,"m_bDucked",0,1);
	SetEntProp(client,Prop_Data,"m_bDucking",1,1);
}
*/

/*****************************************************************


P L U G I N   F U N C T I O N S


*****************************************************************/

stock Plugin_LoadInit(){
	
	Server_InitVars();
	ClientAll_InitVars();
}

stock Server_InitVars(){
	
	//Init Server
	g_cvar_Version 					= INVALID_HANDLE;
	g_cvar_Enable 					= INVALID_HANDLE;
	g_cvar_Debug 					= INVALID_HANDLE;

	//ConVars runtime saver
	g_iPluginEnable					= 1;
	g_iPluginDebug					= 0;
}

stock ClientAll_InitVars(){
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		Client_InitVars(client);
	}
}

stock Client_InitVars(client){
	
	//Variables:
	g_bIsDeveloper[client] = Client_IsDeveloper(client);
	
	ClientAll_PrintDebug("init client: %d; isdev: %d;",client,g_bIsDeveloper[client]);
}


stock bool:Client_IsDeveloper(client){
	
	if(!IsClientAuthorized(client)){
		
		return false;
	}
	
	new AdminId:adminid = GetUserAdmin(client);
	
	if(adminid == INVALID_ADMIN_ID){
		
		//PrintToChat(client,"you are not admin at all");
		return false;
	}
	else if(GetAdminFlag(adminid,WHAT_ADMIN_IS_DEVELOPER)){
		
		//PrintToChat(client,"you are allowed as developer");
		return true;
	}
	
	//PrintToChat(client,"you don't have permission to be developer");
	return false;
}

stock Server_PrintDebug(const String:format[],any:...){
	
	if(g_iPluginEnable == 0){
		return;
	}
	
	switch(g_iPluginDebug){
		
		case 1:{
			decl String:vformat[1024];
			VFormat(vformat, sizeof(vformat), format, 2);
			PrintToServer(vformat);
		}
		case 2:{
			decl String:vformat[1024];
			VFormat(vformat, sizeof(vformat), format, 2);
			PrintToServer(vformat);
			ClientAll_PrintDebug(vformat);
		}
		case 3:{
			decl String:vformat[1024];
			VFormat(vformat, sizeof(vformat), format, 2);
			ClientAll_PrintDebug(vformat);
		}
	}
}

stock ClientAll_PrintDebug(const String:format[],any:...){
	
	if(g_iPluginEnable == 0){
		return;
	}
	
	switch(g_iPluginDebug){
		
		case 1,2,3:{
			
			decl String:vformat[1024];
			VFormat(vformat, sizeof(vformat), format, 2);
			
			for(new client=1;client<=MaxClients;client++){
				
				if(!IsClientInGame(client)){
					continue;
				}
				
				Client_PrintDebug(client,vformat);
			}
		}
	}
}

stock Client_PrintDebug(client,const String:format[],any:...){
	
	if(g_iPluginEnable == 0){
		return;
	}
	
	switch(g_iPluginDebug){
		
		case 1,2,3:{
			
			if(!g_bIsDeveloper[client]){
				return;
			}
			
			decl String:vformat[1024];
			VFormat(vformat, sizeof(vformat), format, 3);
			PrintToChat(client,vformat);
		}
	}
}

/*****************************************************************


 S M   L I B :   P L U G I N   F U N C T I O N S


*****************************************************************/
/*
* Returns how much suit sprint power a client has left in percent.
*
* @param client			Client index.
* @return				returns the actual power left in percent.
*/
stock Float:Client_GetSuitSprintPower(client){

	return GetEntPropFloat(client, Prop_Send, "m_flSuitPower");
}
