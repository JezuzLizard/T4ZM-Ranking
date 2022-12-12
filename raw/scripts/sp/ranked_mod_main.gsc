#include maps\_utility;
#include common_scripts\utility;

main()
{
	replaceFunc( maps\_laststand::revive_success, ::revive_success_override );
	replaceFunc( maps\_challenges_coop::ch_kills, ::ch_kills_override );
	replaceFunc( maps\_challenges_coop::mayProcessChallenges, ::mayProcessChallenges_override );
	if ( !isDefined( level._custom_funcs_table ) )
	{
		level._custom_funcs_table = [];
	}
	level._custom_func_table[ "say_revived_vo" ] = getFunction( "maps/_laststand", "say_revived_vo" );
	level._custom_func_table[ "giveRankXP" ] = ::giveRankXP;
	setDvar( "scr_xpscale", getRankDvarIntDefault( "scr_ranking_xp_scale", 1 ) );
	setDvar( "onlinegame", 1 ); //Force online game to be true even in solo matches
	level._xp_events = [];
	level._xp_events[ "kill" ] = getRankDvarIntDefault( "scr_ranking_xp_per_kill", 5 );
	level._xp_events[ "round_base" ] = getRankDvarIntDefault( "scr_ranking_xp_round_base", 10 );
	level._xp_events[ "round_cap" ] = getRankDvarIntDefault( "scr_ranking_xp_round_cap", 300 );
	level._xp_events[ "revive" ] = getRankDvarIntDefault( "scr_ranking_xp_per_revive", 15 );
	level._xp_events[ "door" ] = getRankDvarIntDefault( "scr_ranking_xp_per_door", 25 );
	level._xp_events[ "power" ] = getRankDvarIntDefault( "scr_ranking_xp_power", 50 );
	level.ranking_show_kill_xp_on_hud = getRankDvarIntDefault( "scr_ranking_show_kill_xp_on_hud", 1 );
	precachestring( &"SCRIPT_PLUS" );
	level thread on_player_connect();
	level thread on_round_over();
}

init()
{
	level thread add_trigger_callbacks();
}

on_round_over()
{
	level endon( "intermission" );

	while ( true )
	{
		level waittill( "between_round_over" );
		award_round_completion_xp();
	}
}

add_trigger_callbacks()
{
	wait 1;
	use_triggers = getEntArray( "trigger_use", "classname" );
	for ( i = 0; i < use_triggers.size; i++ )
	{
		// This should never happen but if it does and this check isn't here...
		if ( !isDefined( use_triggers[ i ].targetname ) )
		{
			continue;
		}
		switch ( use_triggers[ i ].targetname )
		{
			case "zombie_debris":
			case "zombie_door":
			case "use_power_switch":
			case "use_master_switch":
				use_triggers[ i ] thread award_xp_for_purchased_trigger();
			default:
				break;
		}
	}
}

on_player_connect()
{
	level endon( "intermission" );
	while ( true )
	{
		level waittill( "connected", player );
		player.rankUpdateTotal = 0;
		player thread onPlayerSpawned();
	}
}

onPlayerSpawned()
{
	self endon("disconnect");

	for(;;)
	{
		self waittill("spawned_player");

		if(!isdefined(self.hud_rankscroreupdate))
		{
			self.hud_rankscroreupdate = newClientHudElem(self);
			self.hud_rankscroreupdate.horzAlign = "center";
			self.hud_rankscroreupdate.vertAlign = "middle";
			self.hud_rankscroreupdate.alignX = "center";
			self.hud_rankscroreupdate.alignY = "middle";
	 		self.hud_rankscroreupdate.x = 0;
			self.hud_rankscroreupdate.y = -60;
			self.hud_rankscroreupdate.font = "default";
			self.hud_rankscroreupdate.fontscale = 2.0;
			self.hud_rankscroreupdate.archived = false;
			self.hud_rankscroreupdate.color = (0.5,0.5,0.5);
			self.hud_rankscroreupdate.alpha = 0;
			self.hud_rankscroreupdate fontPulseInit();
		}
	}
}

award_round_completion_xp()
{
	xp_value = int( ( level._xp_events[ "round_base" ] * ( level.round_number - 1 ) ) ); 
	if ( xp_value > level._xp_events[ "round_cap" ] )
	{
		xp_value = level._xp_events[ "round_cap" ];
	}
	players = getPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		player = players[ i ];
		if ( !maps\_zombiemode_utility::is_player_valid( player ) )
		{
			continue;
		}
		player giveRankXP( "round_completion", xp_value );
	}
}

mayProcessChallenges_override()
{
	return true;
}

giveRankXP( type, value, levelEnd )
{
	self endon("disconnect");
	if(	!isDefined( levelEnd ) )
	{
		levelEnd = false;
	}
	
	if ( isDefined( level._xp_events[ type ] ) && !isDefined( value ) )
	{
		value = level._xp_events[ type ];
	}
	if ( !isDefined( value ) )
	{
		return;
	}
	value = int( value * level.xpScale );
	if ( value < 1 )
	{
		return;
	}
	self.summary_xp += value;

	switch( type )
	{
		case "challenge":
			self.summary_challenge += value;
			break;
		case "kill":
			if ( level.ranking_show_kill_xp_on_hud )
			{
				self thread updateRankScoreHUD_MP( value );
			}
			break;
		default:
			self thread updateRankScoreHUD_MP( value );
			break;
	}
		
	self maps\_challenges_coop::incRankXP( value );

	if ( level.rankedMatch && maps\_challenges_coop::updateRank() && false == levelEnd )
		self thread maps\_challenges_coop::updateRankAnnounceHUD();	
	// Set the XP stat after any unlocks, so that if the final stat set gets lost the unlocks won't be gone for good.
	self maps\_challenges_coop::syncXPStat();
}

ch_kills_override( victim )
{
	if ( !isDefined( victim.attacker ) || !isPlayer( victim.attacker ) || victim.team == "allies" )
	{
		return;
	}
	player = victim.attacker;
	player giveRankXP( "kill" );
}

revive_success_override( reviver )
{
	self notify ( "player_revived" );	
	self reviveplayer();
	
	//CODER_MOD: TOMMYK 06/26/2008 - For coop scoreboards
	reviver.revives++;
	//stat tracking
	reviver.stats["revives"] = reviver.revives;
	reviver giveRankXP( "revive" );
	// CODER MOD: TOMMY K - 07/30/08
	reviver thread maps\_arcademode::arcadeMode_player_revive();
	setClientSysState("lsm", "0", self);	// Notify client last stand ended.
	
	self.revivetrigger delete();
	self.revivetrigger = undefined;

	self maps\_laststand::laststand_giveback_player_weapons();
	
	self.ignoreme = false;
	
	if ( isDefined( level._custom_func_table[ "say_revived_vo" ] ) )
	{
		self thread [[ level._custom_func_table[ "say_revived_vo" ] ]]();
	}
}

award_xp_for_purchased_trigger()
{
	if ( IsDefined( self.script_noteworthy ) && self.script_noteworthy == "electric_door" )
	{
		return;
	}
	level endon( "end_game" );
	level endon( "intermission" );

	while ( true )
	{
		self waittill( "trigger", who ); 

		if( !who UseButtonPressed() )
		{
			continue;
		}

		if( who maps\_zombiemode_utility::in_revive_trigger() )
		{
			continue;
		}

		if( maps\_zombiemode_utility::is_player_valid( who ) )
		{
			if ( self.targetname == "use_master_switch" || self.targetname == "use_power_switch" )
			{
				players = getPlayers();
				for ( i = 0; i < players.size; i++ )
				{
					if ( !maps\_zombiemode_utility::is_player_valid( players[ i ] ) )
					{
						continue;
					}
					players[ i ] giveRankXP( "power" );
				}
				break;
			}
		 	else if( isDefined( self.zombie_cost ) && who.score >= self.zombie_cost )
			{
				who giveRankXP( "door" );
				break;
			}
		}
	}
}

fontPulseInit()
{
	self.baseFontScale = self.fontScale;
	self.maxFontScale = self.fontScale * 2;
	self.inFrames = 3;
	self.outFrames = 5;
}

fontPulse(player)
{
	self notify ( "fontPulse" );
	self endon ( "fontPulse" );
	player endon("disconnect");
	
	scaleRange = self.maxFontScale - self.baseFontScale;
	
	while ( self.fontScale < self.maxFontScale )
	{
		self.fontScale = min( self.maxFontScale, self.fontScale + (scaleRange / self.inFrames) );
		wait 0.05;
	}
		
	while ( self.fontScale > self.baseFontScale )
	{
		self.fontScale = max( self.baseFontScale, self.fontScale - (scaleRange / self.outFrames) );
		wait 0.05;
	}
}

updateRankScoreHUD_MP( amount )
{
	self endon( "disconnect" );

	if ( amount == 0 )
		return;

	self notify( "update_score" );
	self endon( "update_score" );

	self.rankUpdateTotal += amount;

	wait ( 0.05 );

	if( isDefined( self.hud_rankscroreupdate ) )
	{			
		if ( self.rankUpdateTotal < 0 )
		{
			self.hud_rankscroreupdate.label = &"";
			self.hud_rankscroreupdate.color = (1,0,0);
		}
		else
		{
			self.hud_rankscroreupdate.label = &"SCRIPT_PLUS";
			self.hud_rankscroreupdate.color = (1,1,0.5);
		}

		self.hud_rankscroreupdate setValue(self.rankUpdateTotal);

		self.hud_rankscroreupdate.alpha = 0.85;
		self.hud_rankscroreupdate thread fontPulse( self );

		wait 1;
		self.hud_rankscroreupdate fadeOverTime( 0.75 );
		self.hud_rankscroreupdate.alpha = 0;
		
		self.rankUpdateTotal = 0;
	}
}

getRankDvarIntDefault( dvar, value )
{
	if ( getDvar( dvar ) == "" )
	{
		setDvar( dvar, value );
		return value;
	}
	else 
	{
		return getDvarInt( dvar );
	}
}