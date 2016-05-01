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
#include <smlib/pluginmanager>

/*****************************************************************


P L U G I N   I N F O


*****************************************************************/
#define PLUGIN_NAME				"Adv HL2 Movement"
#define PLUGIN_TAG				"sm"
#define PLUGIN_AUTHOR			"Chanz"
#define PLUGIN_DESCRIPTION		"This plugin enables advanced Half-Life 2 Multiplayer movement, such as bhop without delay."
#define PLUGIN_VERSION 			"0.4.16"
#define PLUGIN_URL				"http://forums.alliedmods.net/showthread.php?p=1324970 OR http://www.mannisfunhouse.eu/"

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


/*****************************************************************


		G L O B A L   V A R S


*****************************************************************/
//ConVars
new Handle:g_cvarRemoveSprintDelay = INVALID_HANDLE;
new Handle:g_cvarFastGravGun = INVALID_HANDLE;
new Handle:g_cvarShaftSprint = INVALID_HANDLE;
new Handle:g_cvarMaxSpeed = INVALID_HANDLE;

//ConVar runtime Optimizer:
new g_iPlugin_RemoveSprintDelay = 0;
new g_iPlugin_FastGravGun = 0;
new g_iPlugin_ShaftSprint = 0;
new Float:g_fPlugin_MaxSpeed = -1.0;

/*****************************************************************


		F O R W A R D   P U B L I C S


*****************************************************************/
public OnPluginStart() {
	
	//Init for smlib
	SMLib_OnPluginStart(PLUGIN_NAME,PLUGIN_TAG,PLUGIN_VERSION,PLUGIN_AUTHOR,PLUGIN_DESCRIPTION,PLUGIN_URL);
	
	//ConVars
	g_cvarRemoveSprintDelay =	CreateConVarEx("removesprintdelay", "1", "Enables or Disables debug mode of Advanced HL2 Movement (2=SendToClient|1=Enable|0=Disabled)",FCVAR_PLUGIN|FCVAR_DONTRECORD,true,0.0,true,2.0);
	g_cvarShaftSprint =			CreateConVarEx("shaftsprint", "1", "Enables or Disables debug mode of Advanced HL2 Movement (2=SendToClient|1=Enable|0=Disabled)",FCVAR_PLUGIN|FCVAR_DONTRECORD,true,0.0,true,2.0);
	g_cvarFastGravGun = 		CreateConVarEx("fastgravgun", "0", "Enables or Disables debug mode of Advanced HL2 Movement (2=SendToClient|1=Enable|0=Disabled)",FCVAR_PLUGIN|FCVAR_DONTRECORD,true,0.0,true,2.0);
	g_cvarMaxSpeed =			FindConVar("sv_maxspeed");
	
	//ConVar runtime optimizer
	g_iPlugin_RemoveSprintDelay = 		GetConVarInt(g_cvarRemoveSprintDelay);
	g_iPlugin_ShaftSprint = 			GetConVarInt(g_cvarShaftSprint);
	g_iPlugin_FastGravGun = 			GetConVarInt(g_cvarFastGravGun);
	g_fPlugin_MaxSpeed = 				(g_cvarMaxSpeed != INVALID_HANDLE) ? GetConVarFloat(g_cvarMaxSpeed) : -1.0;
	
	//Hook ConVar Change
	HookConVarChange(g_cvarRemoveSprintDelay,ConVarChange_RemoveSprintDelay);
	HookConVarChange(g_cvarShaftSprint,ConVarChange_ShaftSprint);
	HookConVarChange(g_cvarFastGravGun,ConVarChange_FastGravGun);
	HookConVarChange(g_cvarMaxSpeed,ConVarChange_MaxSpeed);
	
	//AutoConfig
	AutoExecConfig(true,"plugin.advhl2movement");
}

public OnMapStart() {
	
	// hax against valvefail (thx psychonic for fix)
	if(GuessSDKVersion() == SOURCE_SDK_EPISODE2VALVE){
		SetConVarString(g_cvarVersion, PLUGIN_VERSION);
	}
	
	if((g_cvarMaxSpeed != INVALID_HANDLE) && (g_fPlugin_MaxSpeed != 960.0)){
		
		SetConVarFloat(g_cvarMaxSpeed,960.0,true,true);
		g_fPlugin_MaxSpeed = 960.0;
	}
}

public OnClientConnected(client){
	
	Client_Init(client);
}

public OnClientPostAdminCheck(client){
	
	Client_Init(client);
}


public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon){
	
	if(g_iPlugin_Enable == 0){
		
		Server_PrintDebug("Plugin is disabled");
		return Plugin_Continue;
	}
	
	if(IsFakeClient(client)){
		
		Client_PrintDebug(client,"you are a bot -> no plugin action",client);
		return Plugin_Continue;
	}
	
	new m_bDucked = GetEntProp(client,Prop_Send,"m_bDucked",1);
	new m_bDucking = GetEntProp(client,Prop_Send,"m_bDucking",1);
	new Float:suitSprintPower = Client_GetSuitSprintPower(client);
	new bool:isSprinting = bool:GetEntProp(client,Prop_Data,"m_fIsSprinting",1);
	new Float:m_vecViewOffset[3];
	GetEntPropVector(client,Prop_Data,"m_vecViewOffset",m_vecViewOffset);
	
	
	static bool:s_bIsStandingUp[MAXPLAYERS+1] = {false,...};
	static Float:s_flOldVecViewOffset[MAXPLAYERS+1][3];
	static Float:s_flOldSuitSprintPower[MAXPLAYERS+1] = {100.0,...};
	
	new bool:isSprintPowerOk = (suitSprintPower >= 10.0);
	new releaseButtons = 0;
	
	new buttonsChanged = Client_GetChangedButtons(client);
	
	if(buttonsChanged){
		
		PrintToChat(client,"buttonsChanged: %d",buttonsChanged);
	}
	
	switch(g_iPlugin_RemoveSprintDelay){
		
		case 1:{
			
			//from ducking to stand
			if((m_bDucked == 1) && (m_bDucking == 1)){
				
				if(m_vecViewOffset[2] != s_flOldVecViewOffset[client][2]){
					
					if (buttonsChanged & IN_SPEED){
						
						if (isSprintPowerOk){
							
							Client_SetAllMaxSpeeds(client,960.0);
						}
						else {
							// Reset key, so it will be activated post whatever is suppressing it.
							releaseButtons &= IN_SPEED;
						}
					}
					
					if (releaseButtons & IN_SPEED){
						
						Client_SetAllMaxSpeeds(client,570.0);
					}
				}
				else {
					
					Client_SetAllMaxSpeeds(client,190.0);
				}
				
				s_bIsStandingUp[client] = true;
			}
			//Fully standing
			else if((m_bDucked == 0) && (m_bDucking == 0)){
				
				if (buttonsChanged & IN_SPEED){
					
					if (isSprintPowerOk){
						
						PrintToChat(client,"sprinting");
						Client_SetAllMaxSpeeds(client,320.0);
					}
					else {
						// Reset key, so it will be activated post whatever is suppressing it.
						releaseButtons &= IN_SPEED;
					}
				}
				
				if (releaseButtons & IN_SPEED){
					
					Client_SetAllMaxSpeeds(client,190.0);
				}
				
				s_bIsStandingUp[client] = false;
			}
			//from standing to ducking
			else if((m_bDucked == 1) && (m_bDucking == 0)){
				
				switch(g_iPlugin_ShaftSprint){
					
					case 0:{
						
						//block shaft sprinting at all by setting maxspeed to 190 what ever happens.
						Client_SetAllMaxSpeeds(client,190.0);
					}
					case 1:{
						
						//pro mode you need to do the trick!
						if(s_bIsStandingUp[client]){
							
							//PrintToChat(client,"You should be able to shaft sprint now");
							
							if(buttons & IN_SPEED && isSprintPowerOk){
								
								Client_SetAllMaxSpeeds(client,960.0);
							}
							else {
								
								Client_SetAllMaxSpeeds(client,570.0);
							}
						}
						else {
							
							//PrintToChat(client,"naa you cant shaft sprint like the pros");
							
							Client_SetAllMaxSpeeds(client,190.0);
						}
					}
					case 2:{
						
						if(Client_IsSpaceAboveYou(client,38.0) == -1){
							
							//allow sprinting in the shaft, even if you didn't do the trick nub.
							if(buttons & IN_SPEED && isSprintPowerOk){
								
								Client_SetAllMaxSpeeds(client,960.0);
							}
							else {
								
								Client_SetAllMaxSpeeds(client,570.0);
							}
						}
						else {
							
							Client_SetAllMaxSpeeds(client,190.0);
						}
					}
				}
			}
		}
		
		case 2:{
			
			static bool:s_bFlipFlopSpeed[MAXPLAYERS+1] = {false,...};
			
			//This works when the player is fully standing, then he can sprint.
			if((buttons & IN_SPEED) && !(buttons & IN_DUCK) && isSprinting){
				
				if(s_bFlipFlopSpeed[client]){
					
					buttons &= ~IN_SPEED;
					//SetEntProp(client,Prop_Data,"m_fIsSprinting",1,1);
					s_bFlipFlopSpeed[client] = false;
					//Client_PrintDebug(client,"flip (m_fIsSprinting: %d)",m_fIsSprinting);
				}
				else {
					
					//SetEntProp(client,Prop_Data,"m_fIsSprinting",0,1);
					s_bFlipFlopSpeed[client] = true;
					//Client_PrintDebug(client,"flop (m_fIsSprinting: %d)",m_fIsSprinting);
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
	
	//iLastButtons[client] = buttons;
	
	s_flOldVecViewOffset[client][0] = m_vecViewOffset[0];
	s_flOldVecViewOffset[client][1] = m_vecViewOffset[1];
	s_flOldVecViewOffset[client][2] = m_vecViewOffset[2];
	
	s_flOldSuitSprintPower[client] = suitSprintPower;
	
	buttons = buttons & ~releaseButtons;
	
	return Plugin_Changed;
}

/****************************************************************


		C A L L B A C K   F U N C T I O N S


****************************************************************/

public ConVarChange_RemoveSprintDelay(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPlugin_RemoveSprintDelay = StringToInt(newVal);
}

public ConVarChange_ShaftSprint(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPlugin_ShaftSprint = StringToInt(newVal);
}

public ConVarChange_FastGravGun(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_iPlugin_FastGravGun = StringToInt(newVal);
}

public ConVarChange_MaxSpeed(Handle:cvar, const String:oldVal[], const String:newVal[]){
	
	g_fPlugin_MaxSpeed = StringToFloat(newVal);
}


	
/*****************************************************************


		P L U G I N   F U N C T I O N S


*****************************************************************/
stock Client_SetAllMaxSpeeds(client,Float:speed){
	
	Client_SetMaxSpeed(client,speed);
	SetEntPropFloat(client,Prop_Data,"m_flForwardMove",speed);
	
}


//This function will be called within SMLib_OnPluginStart.
stock ClientAll_Init(){
	
	for(new client=1;client<=MaxClients;client++){
		
		if(!IsClientInGame(client)){
			continue;
		}
		
		Client_Init(client);
	}
}

stock Client_Init(client){
	
	//Variables
	Client_InitVars(client);
	
	PrintToChat(client,"setting your max speeds to 960.0");
	
	//Functions
	ClientCommand(client,"cl_forwardspeed %f",960.0);
	ClientCommand(client,"cl_backspeed %f",960.0);
	ClientCommand(client,"cl_sidespeed %f",960.0);
	
	FakeClientCommand(client,"cl_forwardspeed %f",960.0);
	FakeClientCommand(client,"cl_backspeed %f",960.0);
	FakeClientCommand(client,"cl_sidespeed %f",960.0);
}

stock Client_InitVars(client){
	
	//Plugin Client Vars
	
}

/*@return:
* -1 means no space
* 0 means there is space
* >0 means there is no space because of another player
*/
stock Client_IsSpaceAboveYou(client,Float:neededSpace=74.0){
	
	decl Float:origin[3];
	decl Handle:traceRay;
	new Float:angles[3] = {-90.0,0.0,0.0};
	
	new player = 0;
	
	GetClientAbsOrigin(client, origin);
	origin[2] += neededSpace;
	
	traceRay = TR_TraceRayFilterEx(origin, angles, MASK_ALL, RayType_Infinite, TraceEntityFilter_MySelf, client);
	
	if(TR_DidHit(traceRay)){
		
		decl Float:distance;
		decl Float:endOrigin[3];
		
		TR_GetEndPosition(endOrigin, traceRay);
		distance = GetVectorDistance(origin, endOrigin);
		
		player = TR_GetEntityIndex(traceRay);
		
		//PrintToChatAll("player %d - distance: %f - neededDistance: %f",player,distance,neededDistance);
		
		if(!Client_IsValid(player) && (distance < neededSpace)){
			player = -1;
		}
	}
	
	CloseHandle(traceRay);
	
	return player;
}

public bool:TraceEntityFilter_MySelf(entity, contentsMask, any:client) {
 	return !(entity == client);
}

