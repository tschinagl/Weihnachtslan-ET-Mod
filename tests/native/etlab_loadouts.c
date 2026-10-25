/* ETLab regression tests using the production shared rules and spawn function. */
#include "../src/game/g_local.h"


static int checks;

static void Check(qboolean condition, const char *message)
{
	checks++;
	if (!condition)
	{
		fprintf(stderr, "FAIL: %s\n", message);
		exit(1);
	}
}

static void CheckSpawn(int team, int cls, weapon_t primary, int skillLevel)
{
	gclient_t client;
	bg_playerclass_t *info = BG_GetPlayerClassInfo(team, cls);
	weapon_t akimbo = cls == PC_COVERTOPS
		? (team == TEAM_AXIS ? WP_AKIMBO_SILENCEDLUGER : WP_AKIMBO_SILENCEDCOLT)
		: (team == TEAM_AXIS ? WP_AKIMBO_LUGER : WP_AKIMBO_COLT);
	qboolean bonus = cls == PC_SOLDIER && (primary == WP_PANZERFAUST || primary == WP_BAZOOKA || primary == WP_FLAMETHROWER);
	int i;

	Com_Memset(&client, 0, sizeof(client));
	client.sess.sessionTeam = team;
	client.sess.playerType = cls;
	client.sess.playerWeapon = primary;
	client.sess.playerWeapon2 = info->classSecondaryWeapons[0].weapon;
	client.sess.skill[SK_LIGHT_WEAPONS] = skillLevel;
	if (skillLevel == 4)
	{
		client.sess.playerWeapon2 = akimbo;
	}
	SetWolfSpawnWeapons(&client);
	Check(COM_BitCheck(client.ps.weapons, primary), "selected primary retained");
	Check(!!COM_BitCheck(client.ps.weapons, WP_PLIERS) == (cls != PC_MEDIC), "pliers on every class/team except Medic");
	Check(!!(client.ps.stats[STAT_KEYS] & (1 << INV_BINOCS)) == (cls != PC_MEDIC), "zero-XP binoculars exclude Medic");
	Check(COM_BitCheck(client.ps.weapons, akimbo) == (bonus || skillLevel == 4), "conditional bonus and normal XP unlock");
	Check(client.ps.weapon == primary, "primary initially selected");
	Check(client.sess.skill[SK_LIGHT_WEAPONS] == skillLevel, "no artificial XP promotion");
	if (cls != PC_ENGINEER)
	{
		Check(!COM_BitCheck(client.ps.weapons, WP_DYNAMITE), "no extra dynamite");
		Check(!COM_BitCheck(client.ps.weapons, WP_LANDMINE), "no extra mines");
	}
	if (bonus || skillLevel == 4)
	{
		Check(client.ps.ammoclip[GetWeaponTableData(akimbo)->clipIndex] == 8, "first Akimbo clip loaded");
		Check(client.ps.ammoclip[GetWeaponTableData(GetWeaponTableData(akimbo)->akimboSideArm)->clipIndex] == 8, "second Akimbo clip loaded");
		Check(client.ps.ammo[GetWeaponTableData(akimbo)->ammoIndex] >= 48, "Akimbo reserve ammo");
	}
	for (i = 0; i < MAX_WEAPS_PER_CLASS && info->classSecondaryWeapons[i].weapon; i++)
	{
		if (info->classSecondaryWeapons[i].weapon == akimbo)
		{
			Check(BG_IsSecondaryWeaponAvailable(info, team, primary, i, client.sess.skill) == (bonus || skillLevel == 4), "menu and server agree");
		}
	}
	// Reuse the same client state: changing class/loadout must clear the bonus.
	client.sess.playerType = PC_MEDIC;
	client.sess.playerWeapon = team == TEAM_AXIS ? WP_MP40 : WP_THOMPSON;
	client.sess.skill[SK_LIGHT_WEAPONS] = 0;
	SetWolfSpawnWeapons(&client);
	Check(!COM_BitCheck(client.ps.weapons, WP_AKIMBO_LUGER) && !COM_BitCheck(client.ps.weapons, WP_AKIMBO_COLT), "no stale bonus after class change");
	Check(!COM_BitCheck(client.ps.weapons, WP_PLIERS), "no pliers after changing to Medic");
	Check(!(client.ps.stats[STAT_KEYS] & (1 << INV_BINOCS)), "no stale binoculars after changing to zero-XP Medic");
	for (i = 0; i <= 4; i++)
	{
		client.sess.skill[SK_BATTLE_SENSE] = i;
		SetWolfSpawnWeapons(&client);
		Check(!!(client.ps.stats[STAT_KEYS] & (1 << INV_BINOCS)) == (i >= SK_BATTLE_SENSE_BINOCULAR), "Medic retains normal Battle Sense binocular unlock");
		Check(!COM_BitCheck(client.ps.weapons, WP_PLIERS), "Medic never unlocks pliers");
	}
}

/* Engine geometry is controlled here; all gameplay functions are the real module. */
extern gclient_t g_clients[MAX_CLIENTS];
extern void dllEntry(intptr_t(QDECL *syscallptr)(intptr_t arg, ...));
extern gentity_t *Weapon_Engineer(gentity_t *ent);
extern void G_CheckSpottedLandMines(void);
extern void G_ArmLandmine(gentity_t *mine, gentity_t *player);
static int traceTarget = ENTITYNUM_NONE;
static qboolean radiusQuery, blocked;

static intptr_t QDECL TestSyscall(intptr_t arg, ...)
{
	va_list ap;
	intptr_t result = 0;
	va_start(ap, arg);
	switch (arg)
	{
	case G_SEND_SERVER_COMMAND: case G_PRINT: case G_LOCATE_GAME_DATA:
		break;
	case G_LINKENTITY: case G_UNLINKENTITY:
	{
		gentity_t *e = va_arg(ap, gentity_t *);
		e->r.linked = arg == G_LINKENTITY;
		VectorAdd(e->r.currentOrigin, e->r.mins, e->r.absmin);
		VectorAdd(e->r.currentOrigin, e->r.maxs, e->r.absmax);
		break;
	}
	case G_IN_PVS: result = 1; break;
	case G_ENTITIES_IN_BOX:
		(void)va_arg(ap, const float *); (void)va_arg(ap, const float *);
		if (radiusQuery) { int *list = va_arg(ap, int *); list[0] = MAX_CLIENTS; result = 1; }
		break;
	case G_TRACE:
	{
		trace_t *tr = va_arg(ap, trace_t *);
		const float *end;
		(void)va_arg(ap, const float *); (void)va_arg(ap, const float *); (void)va_arg(ap, const float *);
		end = va_arg(ap, const float *);
		Com_Memset(tr, 0, sizeof(*tr));
		tr->fraction = blocked ? 0.5f : (traceTarget == ENTITYNUM_NONE ? 1.f : 0.01f);
		tr->entityNum = blocked ? ENTITYNUM_WORLD : traceTarget;
		if (traceTarget == ENTITYNUM_NONE) { VectorCopy(end, tr->endpos); }
		break;
	}
	default:
		fprintf(stderr, "Unexpected engine syscall %d\n", (int)arg);
		exit(1);
	}
	va_end(ap);
	return result;
}

static void ResetScene(void)
{
	Com_Memset(g_entities, 0, sizeof(gentity_t) * MAX_GENTITIES);
	Com_Memset(&level, 0, sizeof(level));
	level.num_entities = MAX_CLIENTS + 2;
	level.time = 60000;
	level.clients = g_clients;
	g_corpses.integer = 1;
	g_gamestate.integer = GS_WARMUP;
	G_InitMapEntityData(&mapEntityData[0]);
	G_InitMapEntityData(&mapEntityData[1]);
	traceTarget = ENTITYNUM_NONE;
	radiusQuery = blocked = qfalse;
}

static void CheckPliersActions(int team, int cls)
{
	gclient_t client;
	gentity_t *target = &g_entities[MAX_CLIENTS];
	gentity_t *player = &g_entities[0];
	int kind;
	ResetScene();
	Com_Memset(&client, 0, sizeof(client));
	player->client = &client;
	client.sess.sessionTeam = team;
	client.sess.playerType = cls;
	client.ps.stats[STAT_PLAYER_CLASS] = cls;
	client.ps.weapon = WP_PLIERS;
	level.engineerChargeTime[team - 1] = 30000;
	traceTarget = MAX_CLIENTS;
	for (kind = 0; kind < 6; kind++)
	{
		Com_Memset(target, 0, sizeof(*target));
		target->s.number = MAX_CLIENTS;
		target->s.eType = kind < 5 ? ET_MISSILE : ET_CONSTRUCTIBLE;
		target->methodOfDeath = kind < 2 ? MOD_DYNAMITE : (kind < 4 ? MOD_LANDMINE : MOD_SATCHEL);
		target->s.effect1Time = kind == 0 || kind == 2 || kind == 4;
		target->classname = "test_target";
		Check(G_CanUsePliersOn(player, target) == (cls == PC_ENGINEER || (cls != PC_MEDIC && (kind == 0 || kind == 2))), "pliers eligibility excludes Medic and restricts other non-Engineers");
		if (cls != PC_ENGINEER || kind == 0 || kind == 2)
		{
			Weapon_Engineer(player);
			Check(target->health == ((cls != PC_MEDIC && (kind == 0 || kind == 2)) ? 3 : 0), "real pliers dispatch blocks Medic, arming, satchel and construction");
		}
	}
	target->classname = "misc_mg42";
	target->s.eType = ET_GENERAL;
	target->s.frame = 1;
	target->health = 0;
	Weapon_Engineer(player);
	Check(target->health == (cls == PC_ENGINEER ? 3 : 0), "only Engineer repairs emplaced guns");
	// Completing a defuse must remove the mine without giving other classes mine ammo.
	Com_Memset(target, 0, sizeof(*target));
	target->inuse = qtrue;
	target->s.number = MAX_CLIENTS;
	target->s.eType = ET_MISSILE;
	target->s.weapon = WP_LANDMINE;
	target->methodOfDeath = MOD_LANDMINE;
	target->s.effect1Time = 1;
	target->s.teamNum = team;
	target->health = 248;
	target->classname = "landmine";
	Weapon_Engineer(player);
	Check(!!target->inuse == (cls == PC_MEDIC), "Medic cannot complete a mine defuse");
	if (cls == PC_MEDIC)
	{
		Check(target->health == 248, "Medic makes no mine defuse progress");
		target->s.effect1Time = 2;
		Check(!G_CanUsePliersOn(player, target), "Medic cannot defuse triggered mines");
		Weapon_Engineer(player);
		Check(target->inuse && target->health == 248, "Medic leaves triggered mines unchanged");
	}
	if (cls != PC_ENGINEER)
	{
		Check(client.ps.ammo[WP_LANDMINE] == 0 && client.ps.ammoclip[WP_LANDMINE] == 0, "defusing does not supply mines to other classes");
	}
	player->client = NULL;
}

static void CheckMineDamage(void)
{
	const meansOfDeath_t mods[] = { MOD_GRENADE_LAUNCHER, MOD_GRENADE_PINEAPPLE, MOD_LUGER, MOD_COLT, MOD_MP40, MOD_PANZERFAUST, MOD_KNIFE };
	int spotted, i;
	for (spotted = 0; spotted < 2; spotted++)
	{
		for (i = 0; i < ARRAY_LEN(mods); i++)
		{
			gentity_t *mine = &g_entities[MAX_CLIENTS];
			qboolean expected = i < 2 || (spotted && i < 6);
			ResetScene();
			mine->s.number = MAX_CLIENTS;
			mine->s.eType = ET_MISSILE;
			mine->s.weapon = WP_LANDMINE;
			mine->methodOfDeath = MOD_LANDMINE;
			mine->s.effect1Time = 1;
			mine->s.modelindex2 = spotted;
			mine->takedamage = qtrue;
			G_Damage(mine, NULL, NULL, NULL, NULL, 30, 0, mods[i]);
			Check(mine->freeAfterEvent == expected, "mine detonation: hidden hand grenades only, spotted bullets/explosives");
		}
	}
	for (i = 0; i < 3; i++)
	{
		gentity_t *mine = &g_entities[MAX_CLIENTS];
		vec3_t origin = { 0, 0, 0 };
		ResetScene();
		mine->s.number = MAX_CLIENTS;
		mine->s.eType = ET_MISSILE;
		mine->s.weapon = WP_LANDMINE;
		mine->methodOfDeath = MOD_LANDMINE;
		mine->s.effect1Time = 1;
		mine->takedamage = qtrue;
		VectorSet(mine->r.currentOrigin, i == 2 ? 500 : 100, 0, 0);
		VectorCopy(mine->r.currentOrigin, mine->r.absmin);
		VectorCopy(mine->r.currentOrigin, mine->r.absmax);
		radiusQuery = qtrue;
		blocked = i == 1;
		G_RadiusDamage(origin, &g_entities[ENTITYNUM_WORLD], &g_entities[ENTITYNUM_WORLD], 250, 250, NULL, MOD_GRENADE_PINEAPPLE);
		Check(mine->freeAfterEvent == (i == 0), "real grenade radius: nearby hidden mine, cover and distance respected");
	}
}

static void CheckSpotting(int team, int cls)
{
	gclient_t client;
	gentity_t *player = &g_entities[0], *mine = &g_entities[MAX_CLIENTS];
	int i;
	ResetScene();
	Com_Memset(&client, 0, sizeof(client));
	player->client = &client;
	player->inuse = qtrue;
	player->health = 100;
	client.sess.sessionTeam = team;
	client.sess.playerType = cls;
	client.ps.stats[STAT_KEYS] = 1 << INV_BINOCS;
	level.numConnectedClients = 1;
	mine->s.number = MAX_CLIENTS;
	mine->inuse = qtrue;
	mine->s.eType = ET_MISSILE;
	mine->methodOfDeath = MOD_LANDMINE;
	mine->s.weapon = WP_LANDMINE;
	mine->s.effect1Time = 1;
	mine->s.teamNum = team == TEAM_AXIS ? TEAM_ALLIES : TEAM_AXIS;
	VectorSet(mine->r.currentOrigin, 500, 0, 0);
	G_CheckSpottedLandMines();
	Check(!mine->s.modelindex2 && !mine->count2, "no passive binocular spotting");
	client.ps.eFlags |= EF_ZOOMING;
	Check(G_LandmineSnapshotCallback(MAX_CLIENTS, 0) == (cls != PC_MEDIC), "binocular snapshots exclude Medic");
	for (i = 0; i < 5; i++)
	{
		level.time += 500;
		G_CheckSpottedLandMines();
	}
	if (cls == PC_MEDIC)
	{
		Check(!mine->s.modelindex2 && !mine->count2, "Medic cannot spot mines with binoculars");
		client.sess.skill[SK_BATTLE_SENSE] = 4;
		Check(G_LandmineSnapshotCallback(MAX_CLIENTS, 0), "Medic retains normal Battle Sense trap awareness");
		for (i = 0; i < 5; i++)
		{
			level.time += 500;
			G_CheckSpottedLandMines();
		}
		Check(!mine->s.modelindex2 && !mine->count2, "high-skill Medic cannot mark mines with binoculars");
		player->client = NULL;
		return;
	}
	Check(mine->s.modelindex2 && mine->count2 == 250, "normal binocular dwell spots enemy mine for eligible classes");
	Check((mine->r.contents & MASK_SHOT) && mine->r.maxs[2] == 40, "flag has bullet hitbox");
	Check(!(mine->r.contents & MASK_PLAYERSOLID), "flag does not block walking");
	player->client = NULL;
}

int main(void)
{
	int team, cls, i, xp;
	team_riflegrenades.integer = 1;
	dllEntry(TestSyscall);
	CheckMineDamage();
	for (team = TEAM_AXIS; team <= TEAM_ALLIES; team++)
	{
		for (cls = PC_SOLDIER; cls < NUM_PLAYER_CLASSES; cls++)
		{
			bg_playerclass_t *info = BG_GetPlayerClassInfo(team, cls);
			CheckPliersActions(team, cls);
			CheckSpotting(team, cls);
			for (i = 0; i < MAX_WEAPS_PER_CLASS && info->classPrimaryWeapons[i].weapon; i++)
			{
				for (xp = 0; xp <= 4; xp += 4)
				{
					CheckSpawn(team, cls, info->classPrimaryWeapons[i].weapon, xp);
				}
			}
		}
	}
	printf("PASS: %d production spawn/menu/pliers/mines checks, both teams, all classes and primary loadouts, XP 0/4.\n", checks);
	return 0;
}
