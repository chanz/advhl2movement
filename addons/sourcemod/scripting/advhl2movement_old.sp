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
#include <smlib>
//#include <masterhook>

/*****************************************************************


P L U G I N   I N F O


*****************************************************************/
#define PLUGIN_NAME				"Advanced HL2 Movement"
#define PLUGIN_SHORTNAME		"advhl2movement"
#define PLUGIN_AUTHOR			"Chanz"
#define PLUGIN_DESCRIPTION		"This plugin enables advanced Half-Life 2 Multiplayer movement, such as bhop without delay."
#define PLUGIN_VERSION 			"0.4.16"
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

#define UNIT_TO_BASEVEL 15.784

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

//SDKCalls
new Handle:g_SDKCallStartSprinting;



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
	g_cvar_Enable = CreateConVar("sm_advhl2movement_enable", "1", "Enables or Disables Advanced HL2 Movement (1=Enable|0=Disabled)",FCVAR_PLUGIN|FCVAR_NOTIFY,true,0.0);
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
	//Mh_HookFunction("CHL2_Player::StopSprinting", ValveLibrary_Server, Mh_Callback_StopSprinting, MhDataType_Void);
	//Mh_HookFunction("CBasePlayer::GetPlayerMaxSpeed", ValveLibrary_Server, Mh_Callback_GetPlayerMaxSpeed, MhDataType_Float);
	//Mh_HookFunction("CHL2_Player::HandleSpeedChanges", ValveLibrary_Server, Mh_Callback_HandleSpeedChanges, MhDataType_Void);
	//Mh_HookFunction("CHL2_Player::CanSprint", ValveLibrary_Server, Mh_Callback_CanSprint, MhDataType_Bool);
	
	//SDKCalls
	new Handle:GameConf = LoadGameConfigFile("advhl2movement.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(GameConf, SDKConf_Signature, "StartSprinting");
	g_SDKCallStartSprinting = EndPrepSDKCall();
	
	PrintToServer("g_SDKCallStartSprinting: %d",g_SDKCallStartSprinting);
	
	CloseHandle(GameConf);
	
	//AutoConfig
	AutoExecConfig(true,"plugin.advhl2movement");
	
	//Show the dev that he is loading the right plugin
	Server_PrintDebug(cvarVersionInfo);
}

public OnPluginEnd(){
	
	//PrintToServer("[MASTERHook] Test: %d\n", Mh_UnhookFunction("CHL2_Player::StopSprinting", Mh_Callback_StopSprinting));
	//PrintToServer("[MASTERHook] Test#2: %d\n", Mh_UnhookFunction("CBasePlayer::GetPlayerMaxSpeed", Mh_Callback_GetPlayerMaxSpeed));
	//PrintToServer("[MASTERHook] Test#2: %d\n", Mh_UnhookFunction("CHL2_Player::HandleSpeedChanges", Mh_Callback_HandleSpeedChanges));
	
	//PrintToServer("[MASTERHook] Test: %d\n", Mh_UnhookFunction("CHL2_Player::CanSprint", Mh_Callback_CanSprint));
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
	
	//new flags = GetEntProp(client, Prop_Send, "m_fFlags");
	
	new m_fIsSprinting = GetEntProp(client,Prop_Data,"m_fIsSprinting",1);
	
	new m_bDucked = GetEntProp(client,Prop_Send,"m_bDucked",1);
	new m_bDucking = GetEntProp(client,Prop_Send,"m_bDucking",1);
	
	/*new sprintButton = -1;
	
	if(buttons & IN_SPEED){
		sprintButton = 1;
	}
	else {
		sprintButton = 0;
	}*/
	
	//PrintToChat(client,"Flags: %d; Buttons: %d;",flags,buttons);
	//PrintToChat(client,"SprintButton: %d; m_fIsSprinting: %d;",sprintButton,m_fIsSprinting);
	//PrintToChat(client,"m_bDucked: %d; m_bDucking: %d",m_bDucked,m_bDucking);
	//Client_PrintDebug(client,"m_flSuitPowerLoad: %f",m_flSuitPowerLoad);
	
	/*if(buttons & IN_SPEED){
	SetEntProp(client,Prop_Data,"m_fIsSprinting",1,1);
	SetEntProp(client,Prop_Data,"m_bDucked",0,1);
	SetEntProp(client,Prop_Data,"m_bDucking",0,1);
	}*/
	
	//Client_PrintDebug(client,"Client_GetSuitSprintPower(client): %f",Client_GetSuitSprintPower(client));
	
	static iLastButtons[MAXPLAYERS+1] = {0,...};
	static bool:bHasDucked[MAXPLAYERS+1]  = {false,...};
	
	switch(g_iPluginEnable){
		
		case 1:{
			
			if((m_bDucked == 1) && (m_bDucking == 1)){
				
				if(buttons & IN_SPEED){
					
					SetEntPropFloat(client,Prop_Send,"m_flMaxspeed",960.0);
					SetEntPropFloat(client,Prop_Data,"m_flMaxspeed",960.0);
				}
				else {
					
					SetEntPropFloat(client,Prop_Send,"m_flMaxspeed",570.0);
					SetEntPropFloat(client,Prop_Data,"m_flMaxspeed",570.0);
				}
			}
			
			if((m_bDucked == 0) && (m_bDucking == 0)){
				
				if(buttons & IN_SPEED){
					
					SetEntPropFloat(client,Prop_Send,"m_flMaxspeed",320.0);
					SetEntPropFloat(client,Prop_Data,"m_flMaxspeed",320.0);
				}
				else {
					
					SetEntPropFloat(client,Prop_Send,"m_flMaxspeed",190.0);
					SetEntPropFloat(client,Prop_Data,"m_flMaxspeed",190.0);
				}
			}
			
		}
		
		case 2:{
			
			static bool:ls_bFlipFlopSpeed[MAXPLAYERS+1] = {false,...};
			
			//This works when the player is fully standing, then he can sprint.
			if((buttons & IN_SPEED) && !(buttons & IN_DUCK) && (m_fIsSprinting == 0)){
				
				if(ls_bFlipFlopSpeed[client]){
					
					buttons &= ~IN_SPEED;
					//SetEntProp(client,Prop_Data,"m_fIsSprinting",1,1);
					ls_bFlipFlopSpeed[client] = false;
					Client_PrintDebug(client,"flip (m_fIsSprinting: %d)",m_fIsSprinting);
				}
				else {
					
					//SetEntProp(client,Prop_Data,"m_fIsSprinting",0,1);
					ls_bFlipFlopSpeed[client] = true;
					Client_PrintDebug(client,"flop (m_fIsSprinting: %d)",m_fIsSprinting);
				}
			}
		}
		/*
		case 9:{
			
			if((iLastButtons[client] & IN_DUCK) && !(buttons & IN_DUCK)){
				
				SetEntProp(client,Prop_Data,"m_bDucked",false,1);
				SetEntProp(client,Prop_Data,"m_bDucking",true,1);
				//SetEntProp(client, Prop_Send, "m_fFlags", flags & ~FL_DUCKING); 
			}
			
			
		}
		
		case 8:{
			
			if((iLastButtons[client] & IN_DUCK) && !(buttons & IN_DUCK)){
				
				SetEntProp(client, Prop_Send, "m_fFlags", flags & ~FL_DUCKING);  
				
				//PrintToChat(client,"your m_fFlags: %d",flags);
				
				bHasDucked[client] = true;
			}
			else if(!(iLastButtons[client] & IN_DUCK) && !(buttons & IN_DUCK) && bHasDucked[client]){
				
				//SetEntProp(client, Prop_Send, "m_fFlags", flags & ~FL_DUCKING);  
				
				bHasDucked[client] = false;
			}
		}
		
		case 7:{
			//I wish m_bSpeedCropped wasn't protected!! >.<
			//SetEntProp(client,Prop_Send,"m_bSpeedCropped",1,1);
		}
		
		case 6:{
			
			//works but needs alot of coding work.
			if((buttons & IN_SPEED) && !(buttons & IN_DUCK)){
				
				Entity_SetBaseVelocity(client,Float:{20.27369488,0.0,0.0});
			}
			
			new Float:velocity[3];
			
			Entity_GetBaseVelocity(client,velocity);
			
			//PrintToChat(client,"speed: x:%f; y:%f; z:%f",velocity[0],velocity[1],velocity[2]);
		}
		case 5:{
			
			//Doesn't to anything
			SetEntPropFloat(client,Prop_Data,"m_flForwardMove",1000.0);
			
		}
		case 4:{
			
			//just a test
			new m_afButtonPressed = GetEntProp(client,Prop_Data,"m_afButtonPressed",4);
			Client_PrintDebug(client,"m_afButtonPressed: %d;",m_afButtonPressed);
			
			if(m_afButtonPressed & IN_SPEED){
				
				m_afButtonPressed = ~IN_SPEED;
			}
			
			SetEntProp(client,Prop_Data,"m_afButtonPressed",m_afButtonPressed,4);
		}
		case 3:{
			
			//if called double then its blocked
			if((buttons & IN_DUCK)){ //&& !(buttons & IN_DUCK) && (Client_GetSuitSprintPower(client) != 0.0)){
				
				SDKCall(g_SDKCallStartSprinting, client);
			}
		}*/
	}
	
	iLastButtons[client] = buttons;
	
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
/*
public Action:Mh_Callback_StopSprinting(&client){
	
	if(g_iPluginEnable < 1){
		return Plugin_Continue;
	}
	
	if((GetClientButtons(client) & IN_SPEED)){ //&& (Client_GetSuitSprintPower(client) > 0.0)){
		
		return Plugin_Handled;
	}
	else {
		
		return Plugin_Continue;
	}
}

public Action:Mh_Callback_CanSprint(&client){
	PrintToChat(client,"CanSprint will return true for you");
	Mh_SetReturnValue(true);
	return Plugin_Changed;
}*/

/*public Action:Mh_Callback_GetPlayerMaxSpeed(&client){

if(g_iPluginShaftSprint != 1){
return Plugin_Continue;
}



new entityFlags = GetEntityFlags(client);
new buttons = GetClientButtons(client);

if((entityFlags & FL_DUCKING) && (buttons & IN_SPEED) && (Client_GetSuitSprintPower(client) > 0.0)){

PrintToChat(client,"setting your maxspeed to 920.0");
//Mh_SetReturnValue(100);
return Plugin_Handled;
}
else if(entityFlags & FL_DUCKING){

PrintToChat(client,"setting your maxspeed to 570.0");
//Mh_SetReturnValue(1);
return Plugin_Handled;
}

return Plugin_Continue;
}*/
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
	
	ClientAll_InitVars();
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


stock Entity_GetBaseVelocity(entity, Float:vec[3])
{
	GetEntPropVector(entity, Prop_Data, "m_vecBaseVelocity", vec);
}


stock Entity_SetBaseVelocity(entity, const Float:vec[3])
{
	SetEntPropVector(entity, Prop_Data, "m_vecBaseVelocity", vec);
}

