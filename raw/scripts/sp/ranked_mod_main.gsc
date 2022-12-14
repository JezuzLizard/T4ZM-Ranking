#include maps\_utility;
#include common_scripts\utility;

main()
{
	replaceFunc( maps\_laststand::revive_success, ::revive_success_override );
	//replaceFunc( maps\_challenges_coop::ch_kills, ::ch_kills_override );
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
	level._xp_events[ "revive" ] = getRankDvarIntDefault( "scr_ranking_xp_per_revive", 15 );
	level._xp_events[ "door" ] = getRankDvarIntDefault( "scr_ranking_xp_per_door", 25 );
	level._xp_events[ "power" ] = getRankDvarIntDefault( "scr_ranking_xp_power", 50 );
	level.ranking_show_kill_xp_on_hud = getRankDvarIntDefault( "scr_ranking_show_kill_xp_on_hud", 1 );
	//level.xp_round_bonus = getRankDvarFloatDefault( "scr_ranking_round_bonus_mult", 0.02 );
	level.xp_round_floor_bonus = getRankDvarFloatDefault( "scr_ranking_round_floor_bonus_mult", 2.5 );
	level.xp_round_floor_threshold = getRankDvarIntDefault( "scr_ranking_round_floor_threshold", 10 );
	level.xp_killstreak_max_grace_period = getRankDvarFloatDefault( "scr_ranking_killstreak_grace_period", 3 );
	level.xp_killstreak_threshold_floor = getRankDvarIntDefault( "scr_ranking_killstreak_threshold_floor", 8 );
	level.xp_killstreak_bonus = getRankDvarIntDefault( "scr_ranking_killstreak_bonus", 20 );
	/*
	level.xp_player_count_bonus = [];
	max_clients = getDvarInt( "sv_maxclients" );
	for ( i = 1; i < max_clients + 1; i++ )
	{
		level.xp_player_count_bonus[ i + "player" ] = getRankDvarFloatDefault( "scr_ranking_" + i + "player_bonus", 1 + ( ( i - 1 ) * 0.20 ) );
	}
	*/
	precachestring( &"SCRIPT_PLUS" );
	level thread on_player_connect();
	level thread on_round_over();
}

init()
{
	level thread add_trigger_callbacks();
	if ( !isDefined( level.on_actor_killed_callbacks ) )
	{
		level.on_actor_killed_callbacks = [];
	}
	level.on_actor_killed_callbacks[ level.on_actor_killed_callbacks.size ] = ::ch_kills_override;
	level.on_actor_killed_callbacks[ level.on_actor_killed_callbacks.size ] = ::watch_xp_killstreak;
	level.callbackActorKilled = ::Callback_ActorKilled_override;
	level.t4zm_ranking_init_done = true;
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
		player.xp_recent_kills = 0;
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
	xp_value = level._xp_events[ "round_base" ] * ( level.round_number - 1 ); 
	if ( ( ( level.round_number - 1 ) % level.xp_round_floor_threshold ) == 0 )
	{
		xp_value *= level.xp_round_floor_bonus;
	}
	players = getPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		player = players[ i ];
		if ( !maps\_zombiemode_utility::is_player_valid( player ) )
		{
			continue;
		}
		player giveRankXP( "round_completion", int( xp_value ) );
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
	player_count = getPlayers().size;
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

ch_kills_override( eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, iTimeOffset )
{
	if ( !isDefined( self ) || !isAlive( self ) )
	{
		return;
	}
	if ( !isDefined( eAttacker ) || !isPlayer( eAttacker ) || self.team == "allies" )
	{
		return;
	}
	player = eAttacker;
	player giveRankXP( "kill" );
}

watch_xp_killstreak( eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, iTimeOffset )
{
	if ( !isDefined( self ) || !isAlive( self ) )
	{
		return;
	}
	if ( !isDefined( eAttacker ) || !isPlayer( eAttacker ) || self.team == "allies" )
	{
		return;
	}

	player = eAttacker;
	player.xp_recent_kills++;
	if ( player.xp_recent_kills >= level.xp_killstreak_threshold_floor )
	{
		player giveRankXP( "killstreak", level.xp_killstreak_bonus );
		player.xp_recent_kills = 0;
	}
	player thread end_killstreak_after_time();
}

end_killstreak_after_time()
{
	level endon( "end_game" );
	self endon( "disconnect" );
	self notify( "watch_killstreak" );
	self endon( "watch_killstreak" );

	wait level.xp_killstreak_max_grace_period;

	self.xp_recent_kills = 0;
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

getRankDvarFloatDefault( dvar, value )
{
	if ( getDvar( dvar ) == "" )
	{
		setDvar( dvar, value );
		return value;
	}
	else 
	{
		return getDvarFloat( dvar );
	}
}

Callback_ActorKilled_override( eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, iTimeOffset )
{
	if ( isDefined( level.on_actor_killed_callbacks ) && level.on_actor_killed_callbacks.size > 0 )
	{
		for ( i = 0; i < level.on_actor_killed_callbacks.size; i++ )
		{
			self [[ level.on_actor_killed_callbacks[ i ] ]]( eInflictor, eAttacker, iDamage, sMeansOfDeath, sWeapon, vDir, sHitLoc, iTimeOffset );
		}
	}
}