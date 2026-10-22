version "4.12"

// ============================================================================
// The Pink Valley - tag-along co-op (unofficial add-on)
//
// Player 1 (the host) plays The Pink Valley exactly as in single player and is
// the only one who triggers story events. Everyone else is a second Tilin who
// tags along: they move, fight, open the mod's doors and pick up health, armor
// and ammo (which everyone shares), but they never trigger scripted events, and
// they follow the host through scripted teleports, fades, slow-walks and weapon
// changes.
//
// Each player can also pick a character (user cvar tpvc_character, or Options >
// Pink Valley co-op): everyone else then sees them as Ella, a Paco, a civilian and
// so on, drawn with the mod's own sprites. It only changes how they look.
//
// None of the mod's files are replaced or copied. Nothing here runs in single
// player: every entry point returns early unless this is a net game.
// ============================================================================

class TPVC_Handler : StaticEventHandler
{
	const LATE_STATNUM = 120;	// ticks after players (33), actors (100) and ACS (103)
	const JUMP_DIST = 160.0;	// host moved farther than this in one tic = teleported

	bool modPresent;	// The Pink Valley is loaded
	bool announced;
	bool startChecked;

	// What a tag-along Tilin mirrors from the host.
	Array<Class<Weapon> > mirrorWeapons;
	Array<Class<Weapon> > companionOf;	// alt-fire companion of mirrorWeapons[i], or null
	Array<Class<Weapon> > forcedWeapons;	// story "empty hands" weapons the host gets locked into
	Array<Name> ammoDeny;			// ammo classes that are story counters, not ammo
	Class<Inventory> hudItem;		// IsPlaying: the mod's HUD only draws while you hold it
	int playSprite;
	int tnt1Sprite;

	// Doors guests may open: "MAPNAME#script" for use lines whose script only plays a door
	// sound, checks or takes a key and teleports whoever pressed Use (taken from the mod's maps).
	Array<String> guestDoors;
	// Locked doors whose rattle the story counts on the host ("MAPNAME#script"), and what it gives.
	Array<String> rattleKeys;
	Array<Name> rattleItems;
	Array<Name> keyCards;		// RedCard, BlueCard, YellowCard
	Array<Name> keyBoxes;		// the matching key boxes, same order
	Class<Actor> pibClass;		// P: the invisible Pib validator at the bus stops
	Array<Actor> pibs;
	int hudPrev;			// host held the HUD item last tic: 1 / 0, -1 = not known yet

	// Characters (see BuildCharacters). Index 0 is Tilin: the player's own sprite, no costume.
	// Frames are flat lists; each character has 5 roles (stand, walk, attack, pain, death),
	// role r of character c is frS/frF[roleStart[c * 5 + r] .. + roleLen[c * 5 + r]].
	const ROLE_STAND = 0;
	const ROLE_WALK = 1;
	const ROLE_ATTACK = 2;
	const ROLE_PAIN = 3;
	const ROLE_DEATH = 4;
	Array<String> chId;
	Array<String> chLabel;
	Array<double> chScale;
	Array<int> chOk;
	Array<int> roleStart;
	Array<int> roleLen;
	Array<int> frS;
	Array<int> frF;
	Array<String> frName;		// "PEATA", for the self-test's frame check
	Array<TPVC_Costume> costumes;	// per player: the actor drawn in their place, or null
	Array<double> chTop;		// per character: how high its standing picture reaches (0: not known)

	// Weapon icons (see UpdateWeaponIcons): weapon class -> frame of sprite TPWI.
	Array<Name> wiClass;
	Array<int> wiFrame;
	Array<TPVC_WeaponIcon> icons;	// per player: the picture over their head, or null
	int wiSprite;
	Array<int> forceChar;		// per player: self-test override, -1 = use the player's cvar
	Array<String> wantStr;		// per player: last cvar value seen, and what it matched
	Array<int> wantIdx;

	// Per player (dynamic arrays sized MAXPLAYERS in OnRegister).
	Array<int> placeNow;
	Array<int> haveSafe;
	Array<double> safeX;
	Array<double> safeY;
	Array<double> safeZ;

	// Host trackers.
	Vector3 hostLastPos;
	bool hostPosValid;
	bool resync;
	double hostSpeed;
	double hostJumpZ;
	bool hostSpeedKnown;
	Array<Name> ammoNames;

	// Shared supplies: what each player had last tic (dynamic arrays; ammo is flat, player * MAXAMMO + type).
	const MAXAMMO = 64;
	Array<int> lastHealth;
	Array<int> lastArmor;
	Array<int> resyncP;
	Array<int> ammoLastP;

	// Enemy multiplier.
	Array<Name> copyDeny;
	bool multiplyPending;
	int mapOriginals;
	int mapCopies;
	int mapExpected;
	int mapWaveCopies;
	double waveAcc;
	bool spawningCopies;
	Array<Actor> newSpawns;	// spawned by scripts this tic, checked once their tags are set
	Array<Actor> myCopies;	// copies this add-on made on this map (never copied again)
	const MAX_WAVE_COPIES = 800;	// safety cap per map (room for 10 players' worth)

	// Counters (shown by tpvc_status, checked by the self-test).
	int nBlocked;
	int nRerouted;
	int nPlaced;
	int nRespawns;
	int nGuestDoors;
	int nGuestPickups;
	int nRattles;
	bool hostRespawned;

	// Travelling guests and the map's ENTER script (see PlayerSpawned), for the last map load.
	int standInsWanted;	// guests travelling in without a body on the new map
	int standInsMade;	// stand-in bodies given to them
	int standInsLeft;	// stand-ins the engine didn't replace (removed in WorldLoaded)
	bool loadByTravel;	// this map was entered from another one, not from a save

	// Home's family-room scene (see HomeSceneCheck).
	bool homeSceneSeen;
	int homeArmWait;
	int nHomeArmed;

	// Self-test state.
	int testStage;
	int testPass;
	int testFail;
	int testWait;
	int testGuest;
	Class<Weapon> tWeap;
	Class<Ammo> tAmmo;
	int tAmmoGuest;
	double tSpeed;
	double tBlendR;
	double tBlendG;
	double tBlendB;
	double tBlendA;
	int tPlacedBefore;
	int tWaveBefore;
	int tInWave;
	int tRespawnsBefore;
	Actor tHealth;
	Actor tBox;
	int tHostHp;
	int tGuestHp;
	Class<Ammo> tAmmoG;
	int tAmmoHost;
	bool tHudSet;
	bool tKeyGiven;
	TPVC_Costume tCostume;
	int tCharSave;
	int tCharIdx;

	// ------------------------------------------------------------------------
	// Setup
	// ------------------------------------------------------------------------

	static Class<Actor> ClassByName(Name n)
	{
		return (Class<Actor>)(n);
	}

	void AddMirror(Name w, Name companion = 'None')
	{
		let wc = (Class<Weapon>)(ClassByName(w));
		if (!wc) return;
		mirrorWeapons.Push(wc);
		Class<Weapon> cc = null;
		if (companion != 'None') cc = (Class<Weapon>)(ClassByName(companion));
		companionOf.Push(cc);
	}

	override void OnRegister()
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			placeNow.Push(0);
			haveSafe.Push(0);
			safeX.Push(0);
			safeY.Push(0);
			safeZ.Push(0);
			lastHealth.Push(0);
			lastArmor.Push(0);
			resyncP.Push(1);
			costumes.Push(null);
			icons.Push(null);
			forceChar.Push(-1);
			wantStr.Push("");
			wantIdx.Push(0);
		}
		for (int i = 0; i < MAXPLAYERS * MAXAMMO; i++) ammoLastP.Push(0);

		modPresent = ClassByName('TILIN') != null && ClassByName('CAJALLAVEA') != null;

		// The weapons in Tilin's slots 1-6 and the Pib ticket (slot 7 is Monono and slot 9's
		// key boxes stay with the host), plus the story weapons scripts hand out.
		AddMirror('SAWOFF', 'SAWW');
		AddMirror('CUCHILLO');
		AddMirror('MARTILLO');
		AddMirror('REVOLVER', 'REVZOOM');
		AddMirror('HACHA');
		AddMirror('ESCOPETAYPISTOLA', 'Mypist');
		AddMirror('SSHOTGUN', 'GRL');
		AddMirror('LANZADIENTES', 'LANZABABOSAS');
		AddMirror('METRALLETA');
		AddMirror('TARRO');
		AddMirror('LANZAF', 'LANZAFALT');
		AddMirror('LANZALLAMAS');
		AddMirror('LZS', 'RECOLECTOR');
		AddMirror('TRAUMA');
		AddMirror('BLOCKWEA');
		AddMirror('BLOCKWEA2');
		AddMirror('PIBTAR');

		// Door scripts guests may run, by map (see IsGuestDoor). Generated from the maps' use
		// lines and their scripts: only scripts that play a door sound, check or take a key card or
		// key box, print "you need a key" and teleport the activator. Nothing else.
		String doors = "FUCK_YOU_DUMBASS:11,14,23,24,25,26,27,28,29,30,31,32,33;HAPPY:7,8,9,11,12,14;"
			.. "I_WANT_MY_MONONO:10,11,17,19,21,22,23,24,25,26,27,28,30,33,35,36,42;_:7,8;"
			.. "_A_NEW_DAY_:4,5,6,7;A_DAY:4,5,6,7;HOME:11;MY_NAME:4,5,6,7;PINK:4,5,6,7,14,97,98,99";
		Array<String> parts;
		doors.Split(parts, ";");
		for (int i = 0; i < parts.Size(); i++)
		{
			Array<String> kv;
			parts[i].Split(kv, ":");
			if (kv.Size() != 2) continue;
			Array<String> nums;
			kv[1].Split(nums, ",");
			for (int j = 0; j < nums.Size(); j++) guestDoors.Push(kv[0] .. "#" .. nums[j]);
		}

		// HOME: every locked door in Tilin's house runs script 1 (rattle, give L). Script 2 waits until
		// the host holds 3 L, then arms the family-room line (script 3: the parents' screaming).
		rattleKeys.Push("HOME#1"); rattleItems.Push('L');

		keyCards.Push('RedCard');	keyBoxes.Push('CAJALLAVER');
		keyCards.Push('BlueCard');	keyBoxes.Push('CAJALLAVEB');
		keyCards.Push('YellowCard');	keyBoxes.Push('CAJALLAVEA');
		pibClass = ClassByName('P');

		let b1 = (Class<Weapon>)(ClassByName('BLOCKWEA'));
		let b2 = (Class<Weapon>)(ClassByName('BLOCKWEA2'));
		if (b1) forcedWeapons.Push(b1);
		if (b2) forcedWeapons.Push(b2);

		ammoDeny.Push('CAJALL');
		ammoDeny.Push('MINIYOAMMO');
		ammoDeny.Push('MONONOCHECK');
		ammoDeny.Push('MORDIDAMONONO');
		ammoDeny.Push('SANGREMONONO');

		// Never copied by the enemy multiplier: bosses and story enemies whose scripts expect
		// exactly one of them. (Anything with +BOSS, a tag or a special is skipped anyway.)
		copyDeny.Push('SIRENA');
		copyDeny.Push('MONONOCORROCION');
		copyDeny.Push('DINOCORYDONTOSAURUS');
		copyDeny.Push('IDOLA');
		copyDeny.Push('JUZGADOR');
		copyDeny.Push('MATRIARCA');
		copyDeny.Push('MATRIARCAACE');
		copyDeny.Push('BIG');
		copyDeny.Push('TREX');

		hudItem = (Class<Inventory>)(ClassByName('IsPlaying'));
		playSprite = Actor.GetSpriteIndex('PLAY');
		tnt1Sprite = Actor.GetSpriteIndex('TNT1');
		if (modPresent) BuildCharacters();
		if (modPresent) BuildWeaponIcons();
	}

	// ------------------------------------------------------------------------
	// Characters
	// ------------------------------------------------------------------------

	// One line per character: id | name | scale | stand | walk | attack | pain | death.
	// Each frame list is "SPRT FRAMES", several separated by commas. Every sprite here is the
	// mod's own, the way its actors use them (scale included), except two: TPEL is Ella's
	// turn-around frames set up as rotations in TEXTURES (her own sprites only face one way), and
	// TPBT is Beta Tilin, whose sprites are in this add-on (sprites/). An attack can have a second
	// frame, shown while the player's gun flashes. Add new characters at the end: a costume
	// remembers its character by number.
	void BuildCharacters()
	{
		chId.Push("tilin"); chLabel.Push("Tilin"); chScale.Push(1); chOk.Push(1); chTop.Push(0);
		for (int r = 0; r < 5; r++) { roleStart.Push(0); roleLen.Push(0); }

		AddCharacter("ella|Ella|0.4|TPEL A|TPEL ABAC|TPEL A|SHEA L|SHEA WXYZ,SHEB ABCDEFGHIJKLM");
		AddCharacter("frida|Frida|0.8|FRIC A|FRIC ABCDE|FRIP B|FRIC A|FRID ABCDEF");
		AddCharacter("man|Civilian (man)|0.8|PEAT A|PEAT ABCDE|PEAT A|PEAT A|PEDE ABCDEFHI");
		AddCharacter("woman|Civilian (woman)|0.8|PETM A|PETM ABCDE|PETM A|PETM A|PDTM ABCDEFGH");
		AddCharacter("boy|Kid (boy)|0.8|NNOM A|NNOM ABCDE|NNOM A|NNOM A|NOM2 ABCDEFG");
		AddCharacter("girl|Kid (girl)|0.8|NNAM A|NNAM ABCDE|NNAM A|NNAM A|NAM2 ABCDEFG");
		AddCharacter("paco|Paco|0.6|PACO A|PACO ABCDEFG|PACO E|PACO C|PDEV FABCDE");
		AddCharacter("paca|Paca|0.6|PACA A|PACA ABCDEFG|PAFA D|PACA C|PKDA ABCDEFGH");
		AddCharacter("riotpaco|Riot Paco|0.6|PCRA A|PCRA ABCDEFG|PACF D|PCRA C|PCDN ABCDEFGHI");
		AddCharacter("perropaco|Perro Paco|0.8|CNPC A|CNPC ABCDE|CPSM B|CNPC A|CPMT ABCDE");
		AddCharacter("odio|ODIO|0.3|COES A|COES ABCDEFGHI|COAB C|COAB D|OCMP ABCDFGHIJK");
		AddCharacter("bipedo|Bipedo|0.2|COBI A|COBI ABCDEFGHI|CBKA D|COBI A|CBDT ABCDEFG");
		AddCharacter("bipeda|Bipeda|0.4|BAMV A|BAMV BCDEFGH|BAAM D|BAMV A|BAM0 ABCD");
		AddCharacter("cuadrupedo|Cuadrupedo|0.4|CCBE A|CCBE BCDEFG|CCAT B|CCAS A|CCED ABCDEFGHI");
		AddCharacter("oppressive|The Oppressive|0.5|OPRV A|OPRV BCDEFGHIJKLMN|OPVA A|OPRV C|OPDC ABCDEFG");
		AddCharacter("lovemachine|Love Machine|0.3|LMCH A|LMCH ABCDEF|LMPA E|LMCH D|LVMD ABCDEFG,LVMT ABCDEF");
		// Beta Tilin: E aims, F is the shot, H-K his death (shot in the head, falls). G (hurt,
		// tinted red) was made for the add-on, since the beta sprites have no pain frame.
		AddCharacter("betatilin|Beta Tilin|1|TPBT A|TPBT ABCD|TPBT EF|TPBT G|TPBT HIJK");
	}

	void AddCharacter(String spec)
	{
		Array<String> f;
		spec.Split(f, "|");
		if (f.Size() != 8) return;
		bool ok = true;
		chId.Push(f[0]);
		chLabel.Push(f[1]);
		chScale.Push(f[2].ToDouble());
		for (int r = 0; r < 5; r++)
		{
			int start = frS.Size();
			Array<String> groups;
			f[3 + r].Split(groups, ",");
			for (int g = 0; g < groups.Size(); g++)
			{
				Array<String> sf;
				groups[g].Split(sf, " ");
				if (sf.Size() != 2 || sf[0].Length() != 4) { ok = false; continue; }
				Name sn = sf[0];
				int spr = Actor.GetSpriteIndex(sn);
				if (spr < 0) { ok = false; continue; }
				int nf = sf[1].Length();
				for (int k = 0; k < nf; k++)
				{
					int fr = sf[1].ByteAt(k) - 65;	// 'A' = 0
					if (fr < 0 || fr > 28) { ok = false; continue; }
					frS.Push(spr);
					frF.Push(fr);
					frName.Push(sf[0] .. sf[1].Mid(k, 1));
				}
			}
			roleStart.Push(start);
			roleLen.Push(frS.Size() - start);
		}
		if (roleLen[roleLen.Size() - 5] == 0) ok = false;	// needs a standing frame at least
		chOk.Push(ok ? 1 : 0);

		// How high the standing picture reaches: its top offset times the scale (for the weapon
		// icon over the head).
		double top = 0;
		int st = roleStart[roleStart.Size() - 5];
		if (ok && st < frName.Size())
		{
			TextureID t = TexMan.CheckForTexture(frName[st] .. "1", TexMan.Type_Sprite);
			if (!t.IsValid()) t = TexMan.CheckForTexture(frName[st] .. "0", TexMan.Type_Sprite);
			if (t.IsValid())
			{
				Vector2 off = TexMan.GetScaledOffset(t);
				top = off.y * chScale[chScale.Size() - 1];
			}
		}
		chTop.Push(top);
	}

	// ------------------------------------------------------------------------
	// Weapon icons
	// ------------------------------------------------------------------------

	// A picture of the weapon each player is holding floats over their head, so friends can see
	// what everyone has (idea by Baozodaxia_ZAQ). The pictures are sprite TPWI in textures.tpvc:
	// the weapons' own pickup pictures, cut and scaled, plus the LZS (redrawn by Baican) and the
	// Pib card, which have no picture of their own in the mod. Weapons not listed (Tilin's empty
	// hands in story scenes, BLOCKWEA) show nothing.
	void BuildWeaponIcons()
	{
		wiSprite = Actor.GetSpriteIndex('TPWI');
		AddIcon('SAWOFF', "A");
		AddIcon('CUCHILLO', "B");
		AddIcon('MARTILLO', "C");
		AddIcon('REVOLVER', "D");
		AddIcon('HACHA', "E");
		AddIcon('ESCOPETAYPISTOLA', "F");
		AddIcon('SSHOTGUN', "G");
		AddIcon('LANZADIENTES', "H");
		AddIcon('METRALLETA', "I");
		AddIcon('TARRO', "J");
		AddIcon('LANZAF', "K");
		AddIcon('LANZALLAMAS', "L");
		AddIcon('LZS', "M");
		AddIcon('RECOLECTOR', "M");		// the LZS's alt fire switches to it
		AddIcon('MINIYO', "N");
		AddIcon('MONONODESNUTRIDO', "O");
		AddIcon('MONONOFULL', "O");
		AddIcon('PIBTAR', "P");
		AddIcon('CAJALLAVER', "Q");
		AddIcon('CAJALLAVEA', "R");
		AddIcon('CAJALLAVEB', "S");
		AddIcon('CAJALLAVEESPECIAL', "S");
	}

	void AddIcon(Name cls, String letter)
	{
		wiClass.Push(cls);
		wiFrame.Push(letter.ByteAt(0) - 65);
	}

	int IconFrame(Weapon w)
	{
		if (!w || wiSprite < 0) return -1;
		Name cls = w.GetClassName();
		for (int k = 0; k < wiClass.Size(); k++) if (wiClass[k] == cls) return wiFrame[k];
		return -1;
	}

	// How high over a player's feet their picture reaches: Tilin's height, or the character's.
	double HeadTop(int i, PlayerPawn mo)
	{
		int c = WantedCharacter(i);
		if (c > 0 && c < chTop.Size() && chTop[c] > 0)
		{
			double top = chTop[c];
			if (mo.player && mo.player.crouchfactor > 0) top *= mo.player.crouchfactor;
			return top;
		}
		return mo.Height;	// already lower while crouching
	}

	void UpdateWeaponIcons()
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			let ic = icons[i];
			PlayerPawn mo = playeringame[i] ? players[i].mo : null;
			int fr = (mo && mo.health > 0) ? IconFrame(players[i].ReadyWeapon) : -1;
			if (fr < 0)
			{
				if (ic) { ic.Destroy(); icons[i] = null; }
				continue;
			}
			double dz = HeadTop(i, mo) + 6;
			if (!ic)
			{
				ic = TPVC_WeaponIcon(Actor.Spawn("TPVC_WeaponIcon", mo.pos + (0, 0, dz), NO_REPLACE));
				if (!ic) continue;
				icons[i] = ic;
			}
			else ic.SetOrigin(mo.pos + (0, 0, dz), true);
			ic.Prev = mo.Prev + (0, 0, dz);	// move as smoothly as the player
			ic.sprite = wiSprite;
			ic.frame = fr;

			// Each screen decides for itself: never over your own head, and not at all if you
			// turned them off. (Only how this screen draws it; nothing the game plays by.)
			let me = players[consoleplayer];
			bool show = true;
			let cv = CVar.GetCVar('tpvc_weaponicons', me);
			if (cv) show = cv.GetBool();
			ic.bInvisible = !show || (me.camera == mo && !(me.cheats & CF_CHASECAM));
		}
	}

	// Which character player i wants: their tpvc_character cvar (id or name, any case).
	int WantedCharacter(int i)
	{
		if (forceChar[i] >= 0) return forceChar[i] < chId.Size() && chOk[forceChar[i]] ? forceChar[i] : 0;
		let cv = CVar.GetCVar('tpvc_character', players[i]);
		if (!cv) return 0;
		String want = cv.GetString();
		if (want == wantStr[i]) return wantIdx[i];
		wantStr[i] = want;
		String w = want.MakeLower();
		w.Replace(" ", "");
		int found = 0;
		for (int c = 1; c < chId.Size(); c++)
		{
			String lab = chLabel[c].MakeLower();
			lab.Replace(" ", "");
			if (chOk[c] && (w == chId[c] || w == lab)) { found = c; break; }
		}
		wantIdx[i] = found;
		return found;
	}

	// Every tic: players who picked a character get a costume actor drawn where they are, and
	// their own Tilin is hidden. Only looks change: the player keeps Tilin's body, weapons and sounds.
	// Tilin is hidden by showing the empty sprite TNT1 for the rest of the tic (this runs after the
	// players move), never with the INVISIBLE flag or render style: monsters can't see actors that
	// have those, so they would ignore the player.
	void UpdateCharacters()
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			let cs = costumes[i];
			if (!playeringame[i] || !players[i].mo)
			{
				if (cs) { cs.Destroy(); costumes[i] = null; }
				continue;
			}
			PlayerPawn mo = players[i].mo;
			int c = WantedCharacter(i);
			SetEllaFace(mo, c > 0 && c == FindCharacter("ella"));
			if (c <= 0)
			{
				if (cs) { cs.Destroy(); costumes[i] = null; }
				if (mo.bInvisible) mo.bInvisible = false;	// the first character build hid players this way
				if (mo.sprite == tnt1Sprite && mo.CurState && mo.CurState.sprite != tnt1Sprite)
				{
					mo.sprite = mo.CurState.sprite;	// show Tilin again right away
					mo.frame = mo.CurState.Frame;
				}
				continue;
			}
			if (cs && cs.charIdx != c) { cs.Destroy(); cs = null; costumes[i] = null; }
			if (!cs)
			{
				cs = TPVC_Costume(Actor.Spawn("TPVC_Costume", mo.pos, NO_REPLACE));
				if (!cs) continue;
				cs.pnum = i;
				cs.charIdx = c;
				cs.deathTic = -1;
				cs.Angle = mo.Angle;
				costumes[i] = cs;
				Dbg(String.Format("player %d is now %s", i + 1, chLabel[c]));
			}
			else cs.SetOrigin(mo.pos, true);
			cs.Prev = mo.Prev;	// interpolate exactly like the player
			if (mo.bInvisible) mo.bInvisible = false;
			mo.sprite = tnt1Sprite;	// hide Tilin (see above)
			Dress(cs, mo);

			// Never draw a costume in its own player's view: it sits right where their camera is,
			// so it would cover their screen. (Only how this one screen draws it changes, nothing
			// the game plays by, so it's safe that each computer sets it for its own player.)
			let me = players[consoleplayer];
			cs.bInvisible = me.camera == mo && !(me.cheats & CF_CHASECAM);
		}
	}

	// Ella's HUD face: the add-on's copy of the mod's SBARINFO shows TURI's Ella faces (graphics/TPF*,
	// from "Ella Over Tilin") instead of Tilin's to whoever holds TPVC_EllaFace. The HUD only ever shows the player it belongs to
	// (or the one being spied on), so only players dressed as Ella get it.
	void SetEllaFace(PlayerPawn mo, bool on)
	{
		bool has = mo.CountInv("TPVC_EllaFace") > 0;
		if (on && !has) mo.GiveInventory("TPVC_EllaFace", 1);
		else if (!on && has) mo.TakeInventory("TPVC_EllaFace", 1);
	}

	void Dress(TPVC_Costume cs, PlayerPawn mo)
	{
		int c = cs.charIdx;
		cs.Angle = mo.Angle;
		cs.FloorClip = mo.FloorClip;
		cs.Scale = (chScale[c], chScale[c]);
		cs.bBright = false;
		if (mo.health <= 0)
		{
			if (cs.deathTic < 0) cs.deathTic = level.maptime;
			ShowDeath(cs, c, level.maptime - cs.deathTic);
			return;
		}
		cs.deathTic = -1;
		int role = ROLE_STAND;
		bool flash = false;
		State st = mo.CurState;
		if (st)
		{
			// Melee is where Doom puts the player while their gun flashes (Tilin's own F frame).
			flash = mo.InStateSequence(st, mo.FindState("Melee"));
			if (mo.InStateSequence(st, mo.FindState("Pain"))) role = ROLE_PAIN;
			else if (flash || mo.InStateSequence(st, mo.FindState("Missile"))) role = ROLE_ATTACK;
			else if (mo.InStateSequence(st, mo.FindState("See"))) role = ROLE_WALK;
		}
		if (role == ROLE_ATTACK)
		{
			// The first attack frame, or the second (the shot) while the gun flashes, lit up the
			// way Tilin's is. Characters with one attack frame show it either way.
			bool shot = flash && roleLen[c * 5 + ROLE_ATTACK] > 1;
			ShowRole(cs, c, role, shot ? 1 : 0);
			cs.bBright = shot;
		}
		else ShowRole(cs, c, role, level.maptime / 4);
	}

	// Show frame k (wrapping) of a role; a character without that role uses its standing frame.
	void ShowRole(Actor cs, int c, int role, int k)
	{
		int idx = c * 5 + role;
		if (roleLen[idx] == 0) idx = c * 5 + ROLE_STAND;
		int n = roleLen[idx];
		if (n <= 0) return;
		int j = roleStart[idx] + (k % n);
		cs.sprite = frS[j];
		cs.frame = frF[j];
	}

	// The death animation, about a second long whatever its length, then its last frame stays.
	void ShowDeath(Actor cs, int c, int elapsed)
	{
		int idx = c * 5 + ROLE_DEATH;
		int n = roleLen[idx];
		if (n <= 0) { ShowRole(cs, c, ROLE_STAND, 0); return; }
		int per = clamp(32 / n, 2, 5);
		int k = min(n - 1, max(0, elapsed) / per);
		cs.sprite = frS[roleStart[idx] + k];
		cs.frame = frF[roleStart[idx] + k];
	}

	String CharacterOf(int i)
	{
		int c = WantedCharacter(i);
		return c > 0 ? chLabel[c] : "Tilin";
	}

	int FindCharacter(String id)
	{
		for (int c = 1; c < chId.Size(); c++) if (chId[c] == id && chOk[c]) return c;
		return 0;
	}

	bool Active()
	{
		return multiplayer && !deathmatch && modPresent && playeringame[0] && players[0].mo != null;
	}

	static bool IsGuestPawn(Actor a)
	{
		return a != null && a.player != null && a.player.mo == a && a.PlayerNumber() > 0;
	}

	void Dbg(String s)
	{
		if (tpvc_debug) Console.Printf("\cu[co-op]\c- %s", s);
	}

	override void WorldLoaded(WorldEvent e)
	{
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			placeNow[i] = 0;
			haveSafe[i] = 0;
		}
		hostPosValid = false;
		hostRespawned = false;
		hostSpeedKnown = false;
		resync = true;
		testStage = 0;
		hudPrev = -1;
		for (int i = 0; i < MAXPLAYERS; i++) resyncP[i] = 1;
		homeSceneSeen = false;
		homeArmWait = 0;

		// Stand-in bodies (see PlayerSpawned) are replaced and deleted by the engine when the
		// guests arrive. Remove any that weren't, and never leave a player pointing at one.
		loadByTravel = !e.IsSaveGame && standInsWanted > 0;
		if (e.IsSaveGame) { standInsWanted = 0; standInsMade = 0; }
		standInsLeft = 0;
		Array<Actor> left;
		let sit = ThinkerIterator.Create("TPVC_TravelStandIn");
		for (Actor a = Actor(sit.Next()); a; a = Actor(sit.Next())) left.Push(a);
		for (int k = 0; k < left.Size(); k++)
		{
			for (int i = 0; i < MAXPLAYERS; i++) if (players[i].mo == left[k]) players[i].mo = null;
			left[k].Destroy();
			standInsLeft++;
		}

		// Character costumes: a new map starts without any (UpdateCharacters makes them). A save
		// has the old ones in it; drop those that belong to a living player so they aren't doubled.
		for (int i = 0; i < MAXPLAYERS; i++) costumes[i] = null;
		for (int i = 0; i < MAXPLAYERS; i++) icons[i] = null;
		if (e.IsSaveGame)
		{
			Array<Actor> old;
			let cit = ThinkerIterator.Create("TPVC_Costume");
			for (let a = TPVC_Costume(cit.Next()); a; a = TPVC_Costume(cit.Next())) if (!a.orphan) old.Push(a);
			let iit = ThinkerIterator.Create("TPVC_WeaponIcon");
			for (let a = TPVC_WeaponIcon(iit.Next()); a; a = TPVC_WeaponIcon(iit.Next())) old.Push(a);
			for (int k = 0; k < old.Size(); k++) old[k].Destroy();
		}

		// The Pib validators on this map (A_NEW_DAY, MY NAME, SUPER).
		pibs.Clear();
		if (pibClass && multiplayer && modPresent)
		{
			let pit = ThinkerIterator.Create(pibClass);
			for (Actor a = Actor(pit.Next()); a; a = Actor(pit.Next())) if (a.GetClass() == pibClass) pibs.Push(a);
		}

		if (!multiplayer || !modPresent) return;

		// Every map start: guests spawn on the host's start spot (the mod's maps only have one),
		// so move them next to the host. A loaded save keeps everyone where they were.
		if (!e.IsSaveGame)
			for (int i = 1; i < MAXPLAYERS; i++) placeNow[i] = 1;

		// Enemy copies are made once, when a map starts fresh. A save already contains them.
		multiplyPending = !e.IsSaveGame;
		if (multiplyPending) { mapOriginals = 0; mapCopies = 0; mapExpected = 0; mapWaveCopies = 0; waveAcc = 0; }
		newSpawns.Clear();
		myCopies.Clear();

		// The per-tic work runs in a thinker that ticks after everything else, so a fade,
		// speed change or teleport a script gives the host reaches everyone the same tic.
		let it = ThinkerIterator.Create("TPVC_Late", LATE_STATNUM);
		if (!it.Next())
		{
			let t = TPVC_Late(new("TPVC_Late"));
			if (t) t.ChangeStatNum(LATE_STATNUM);
		}
	}

	// GZDoom starts every net game on MAP01, which here is Doom 2's Entryway. Go to the
	// mod's first map instead (or the one the host picked with tpvc_startmap).
	bool CheckStartMap()
	{
		if (startChecked) return false;
		startChecked = true;
		if (!(level.MapName ~== "MAP01")) return false;
		String target = tpvc_startmap;
		if (target == "" || !LevelInfo.MapExists(target)) target = "A_NEW_DAY";
		if (!LevelInfo.MapExists(target)) return false;
		Console.Printf("\cfPink Valley co-op:\c- starting %s", target);
		level.ChangeLevel(target, 0, CHANGELEVEL_NOINTERMISSION | CHANGELEVEL_RESETINVENTORY | CHANGELEVEL_RESETHEALTH, -1);
		return true;
	}

	// Co-op respawns put you back on the map's start spot. Come back next to a friend instead:
	// guests next to the host, the host next to a guest (or where they last stood).
	override void PlayerRespawned(PlayerEvent e)
	{
		if (!Active()) return;
		int i = e.PlayerNumber;
		if (i < 0 || i >= MAXPLAYERS) return;
		placeNow[i] = 1;
		resyncP[i] = 1;
		nRespawns++;
		if (i == 0) hostRespawned = true;

		// The old body stays behind as a corpse: its costume stays with it and finishes the death
		// animation on its own. The new body gets a new costume next tic.
		let cs = costumes[i];
		if (cs)
		{
			cs.orphan = true;
			if (cs.deathTic < 0) cs.deathTic = level.maptime;
			costumes[i] = null;
		}
	}

	override void PlayerDisconnected(PlayerEvent e)
	{
		int i = e.PlayerNumber;
		if (i < 0 || i >= MAXPLAYERS || i >= costumes.Size()) return;
		if (costumes[i]) { costumes[i].Destroy(); costumes[i] = null; }
		if (icons[i]) { icons[i].Destroy(); icons[i] = null; }
	}

	override void PlayerEntered(PlayerEvent e)
	{
		int i = e.PlayerNumber;
		if (i >= 0 && i < MAXPLAYERS) resyncP[i] = 1;
	}

	override void WorldUnloaded(WorldEvent e)
	{
		standInsWanted = 0;
		standInsMade = 0;
	}

	// The mod's maps only have a player 1 start, so on a level change the guests arrive with no
	// body on the new map. GZDoom then doesn't run the map's ENTER script for them, but UZDoom 5
	// runs it on a throwaway body it deletes right away. That copy runs with nobody as its
	// activator, and before the host's: everything it spawns is doubled, and the scripts it starts
	// get bound to nobody, so they never see the host's items. On Home the family-room scene
	// never armed (script 2 counted nobody's locked-door tries); Melancolia's ending walk and
	// Pink's Monono check went the same way.
	// UZDoom skips that ENTER copy when the player already has a body on the map. The host's body
	// is spawned first, while the map loads, so give each travelling guest a stand-in body then;
	// a moment later the engine swaps in the guest's real body and deletes the stand-in.
	override void PlayerSpawned(PlayerEvent e)
	{
		if (!multiplayer || deathmatch || !modPresent || e.PlayerNumber != 0 || level.maptime > 0) return;
		let host = players[0].mo;
		for (int i = 1; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i] || players[i].mo || players[i].playerstate != PST_LIVE) continue;
			standInsWanted++;
			let d = PlayerPawn(Actor.Spawn("TPVC_TravelStandIn", host ? host.pos : (0, 0, 0)));
			if (!d) continue;
			d.health = players[i].health;	// the map loader copies the body's health to the player
			players[i].mo = d;
			standInsMade++;
		}
	}

	// ------------------------------------------------------------------------
	// Only the host triggers things
	// ------------------------------------------------------------------------

	override void WorldLinePreActivated(WorldEvent e)
	{
		if (!Active()) return;
		Actor a = e.Thing;
		if (!a) return;
		Actor who = a;
		if (!a.player && a.bMissile) who = a.target;	// a guest's projectile
		if (!IsGuestPawn(who)) return;

		Line ln = e.ActivatedLine;
		if (who == a && (e.ActivationType & SPAC_Use) && IsGuestDoor(ln))
		{
			// One of the mod's doors: run its script for this guest (it only teleports whoever
			// pressed Use). ACS_ExecuteAlways, so the host can use the same door at the same
			// time, and the line itself is left untouched for the host.
			e.ShouldActivate = false;
			level.ExecuteSpecial(226, who, ln, false, ln.args[0], 0, ln.args[2], ln.args[3], ln.args[4]);
			nGuestDoors++;
			Dbg(String.Format("player %d opened a door (line %d, script %d)", who.PlayerNumber() + 1, ln.Index(), ln.args[0]));
			return;
		}

		int rk = RattleIndex(ln);
		if (who == a && (e.ActivationType & SPAC_Use) && rk >= 0)
		{
			// A locked door the story counts, on the host (Home: three tries arm the family-room
			// scene). The guest hears their own rattle, and the try counts for the host too.
			e.ShouldActivate = false;
			level.ExecuteSpecial(226, who, ln, false, ln.args[0], 0, ln.args[2], ln.args[3], ln.args[4]);
			players[0].mo.GiveInventory((Class<Inventory>)(ClassByName(rattleItems[rk])), 1);
			nRattles++;
			Dbg(String.Format("player %d tried a locked door (line %d, script %d): counted for the host", who.PlayerNumber() + 1, ln.Index(), ln.args[0]));
			return;
		}

		e.ShouldActivate = false;
		nBlocked++;
		Dbg(String.Format("blocked player %d from line %d (special %d)", who.PlayerNumber() + 1, ln.Index(), ln.special));
	}

	// Home: three tries of a locked door (script 1 gives L each time) make script 2 arm the
	// family-room line (id 6) with script 3, and crossing it starts the parents' screaming.
	// Script 2 checks whoever started it. With the stand-ins (PlayerSpawned) that is the host
	// again, and guests' tries count for the host (WorldLinePreActivated). A game saved on Home
	// with the old version on UZDoom still has a script 2 that checks nobody, so if the host has
	// the tries and the line still isn't armed a second later, arm it the way script 2 would.
	void HomeSceneCheck(PlayerPawn host)
	{
		if (!host || !(level.MapName ~== "HOME")) return;
		int l6 = FirstLineWithId(6);
		int l26 = FirstLineWithId(26);
		int l8 = FirstLineWithId(8);
		if (l6 < 0 || l26 < 0 || l8 < 0) return;
		Line ln6 = level.Lines[l6];
		Line ln26 = level.Lines[l26];
		Line ln8 = level.Lines[l8];
		bool armed = ln6.special == 80 && ln6.args[0] == 3;
		if (armed || (ln26.special == 80 && ln26.args[0] == 12)) homeSceneSeen = true;
		bool doorLocked = ln8.special == 80 && ln8.args[0] == 1;	// script 4 opens it once the scene ends
		let lc = (Class<Inventory>)(ClassByName('L'));
		if (homeSceneSeen || !doorLocked || !lc || host.CountInv(lc) <= 2) { homeArmWait = 0; return; }
		if (++homeArmWait < 35) return;
		homeArmWait = 0;
		homeSceneSeen = true;
		level.ExecuteSpecial(82, host, null, false, 2, 0);	// ACS_Terminate: the stuck script 2
		let it = level.CreateLineIDIterator(6);
		for (int li = it.Next(); li >= 0; li = it.Next())
		{
			level.Lines[li].special = 80;
			level.Lines[li].args[0] = 3;
			for (int a = 1; a < 5; a++) level.Lines[li].args[a] = 0;
		}
		nHomeArmed++;
		Dbg("Home: the host has tried three locked doors but the family-room line wasn't armed: armed it");
	}

	int FirstLineWithId(int id)
	{
		let it = level.CreateLineIDIterator(id);
		return it.Next();
	}

	int RattleIndex(Line ln)
	{
		if (!ln || (ln.special != 80 && ln.special != 226) || ln.args[1] != 0) return -1;
		String key = String.Format("%s#%d", level.MapName.MakeUpper(), ln.args[0]);
		int k = rattleKeys.Find(key);
		return k < rattleKeys.Size() ? k : -1;
	}

	bool IsGuestDoor(Line ln)
	{
		if (!ln || (ln.special != 80 && ln.special != 226)) return false;	// ACS_Execute / ACS_ExecuteAlways
		if (ln.args[1] != 0) return false;	// a script on another map
		String key = String.Format("%s#%d", level.MapName.MakeUpper(), ln.args[0]);
		return guestDoors.Find(key) != guestDoors.Size();
	}

	// A monster or NPC with a death special runs it with its killer as the activator.
	// If a guest got the kill, run it for the host instead, exactly as single player would.
	override void WorldThingDied(WorldEvent e)
	{
		if (!Active()) return;
		Actor t = e.Thing;
		if (!t || t.player || !t.special) return;
		if (t.activationtype & THINGSPEC_ThingActs) return;
		if (level.actownspecial && !(t.activationtype & THINGSPEC_TriggerActs)) return;

		Actor killer = t.target;	// Die() sets target to the killer before this event
		if (!IsGuestPawn(killer)) return;
		if (e.Inflictor != killer && (!e.Inflictor || e.Inflictor.target != killer)) return;

		Actor host = players[0].mo;
		int sp = t.special;
		t.special = 0;	// so Die() doesn't run it again with the guest
		level.ExecuteSpecial(sp, host, null, false, t.args[0], t.args[1], t.args[2], t.args[3], t.args[4]);
		nRerouted++;
		Dbg(String.Format("%s killed by player %d: ran its special %d as the host", t.GetClassName(), killer.PlayerNumber() + 1, sp));
	}

	// ------------------------------------------------------------------------
	// Per-tic work (called from TPVC_Late)
	// ------------------------------------------------------------------------

	void LateTick()
	{
		if (!Active()) return;
		if (CheckStartMap()) return;

		if (multiplyPending)
		{
			multiplyPending = false;
			MultiplyEnemies();
		}
		if (newSpawns.Size() > 0) CopyScriptWaves();

		PlayerPawn host = players[0].mo;

		if (!announced)
		{
			announced = true;
			Console.Printf("\cfPink Valley co-op:\c- player 1 drives the story. Press J to warp to them.");
		}

		HomeSceneCheck(host);

		bool hostNewBody = hostRespawned;
		hostRespawned = false;

		// A respawned host gets a fresh body with default speed, but the map's scripts set the
		// speed once on entry (slow-walks, no jumping). Put back what the scripts had set.
		if (hostNewBody && hostSpeedKnown)
		{
			host.Speed = hostSpeed;
			host.JumpZ = hostJumpZ;
		}
		if (host.health > 0)
		{
			hostSpeed = host.Speed;
			hostJumpZ = host.JumpZ;
			hostSpeedKnown = true;
		}

		// Host got teleported (by a script or a teleporter): bring everyone along.
		if (host.health > 0 && hostPosValid && !hostNewBody && tpvc_follow)
		{
			Vector2 d = host.pos.xy - hostLastPos.xy;
			if (d.Length() > JUMP_DIST)
			{
				for (int i = 1; i < MAXPLAYERS; i++)
					if (playeringame[i] && players[i].mo && players[i].mo.health > 0) placeNow[i] = 1;
				Dbg(String.Format("host jumped %d units, bringing everyone along", int(d.Length())));
			}
		}

		if (placeNow[0]) { placeNow[0] = 0; DoPlace(0); }
		for (int i = 1; i < MAXPLAYERS; i++)
		{
			if (placeNow[i]) { placeNow[i] = 0; DoPlace(i); }
		}
		if (host.health > 0) { hostLastPos = host.pos; hostPosValid = true; }

		// Last safe spot for each player, used when nobody alive is around to respawn next to.
		if ((level.maptime & 7) == 0)
		{
			for (int i = 0; i < MAXPLAYERS; i++)
			{
				if (!playeringame[i]) continue;
				let mo = players[i].mo;
				if (mo && mo.health > 0 && mo.pos.z <= mo.floorz + 1)
				{
					safeX[i] = mo.pos.x; safeY[i] = mo.pos.y; safeZ[i] = mo.pos.z;
					haveSafe[i] = 1;
				}
			}
		}

		// The Pib validator (an invisible actor at each bus stop) only checks the Pib ticket of
		// the player it's looking at. Keep it looking at the host, or the host's swipe never counts.
		if (host.health > 0)
			for (int p = 0; p < pibs.Size(); p++)
				if (pibs[p] && pibs[p].health > 0) pibs[p].target = host;

		// HUD: the mod only draws it while you hold IsPlaying. Scripts take it from the host in story
		// scenes and the host earns it back by getting hurt or attacking. Follow the host when it
		// changes, but let a guest earn it back on their own the same way.
		if (hudItem)
		{
			int hostHud = host.CountInv(hudItem) > 0 ? 1 : 0;
			if (hostHud != hudPrev)
			{
				for (int i = 1; i < MAXPLAYERS; i++)
				{
					if (!playeringame[i]) continue;
					let g = players[i].mo;
					if (!g || g.health <= 0) continue;
					bool gh = g.CountInv(hudItem) > 0;
					if (hostHud && !gh) g.GiveInventory(hudItem, 1);
					else if (!hostHud && gh) g.TakeInventory(hudItem, g.CountInv(hudItem));
				}
				hudPrev = hostHud;
			}
		}

		for (int i = 1; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			let g = players[i].mo;
			if (!g || g.health <= 0) continue;
			MirrorTo(host, g);
			GuestPickups(g);
		}

		// Health, armor and ammo anyone gains (pickups, script gives) are shared with everyone.
		ShareSupplies();
		resync = false;

		// Tilin has no pain frame (PLAY G) in the mod, so GZDoom would show Doomguy's from
		// DOOM2.WAD. Players only see each other in co-op: show Tilin's standing frame instead.
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			let mo = players[i].mo;
			if (mo && mo.sprite == playSprite && mo.frame == 6) mo.frame = 0;
		}

		// Whoever picked a character gets drawn as it.
		UpdateCharacters();
		UpdateWeaponIcons();

		if (testStage > 0) SelfTestStep();
	}

	void MirrorTo(PlayerPawn host, PlayerPawn g)
	{
		// Guests use lines (IsGuestDoor decides which) and pick things up through GuestPickups,
		// never through the engine's own touch, which would also take keys and weapons.
		g.bPickup = false;
		g.UseRange = GetDefaultByType((class<PlayerPawn>)(g.GetClass())).UseRange;

		// Scripted slow-walks, freezes, no-jump sections and screen fades.
		g.Speed = host.Speed;
		g.JumpZ = host.JumpZ;
		g.player.BlendR = host.player.BlendR;
		g.player.BlendG = host.player.BlendG;
		g.player.BlendB = host.player.BlendB;
		g.player.BlendA = host.player.BlendA;

		// Same weapons as the host.
		for (int w = 0; w < mirrorWeapons.Size(); w++)
		{
			let cls = mirrorWeapons[w];
			bool hostHas = host.FindInventory(cls) != null;
			let gw = g.FindInventory(cls);
			if (hostHas && !gw)
			{
				GiveWeaponSilently(g, cls);
			}
			else if (!hostHas && gw)
			{
				g.TakeInventory(cls, gw.Amount);
				let comp = companionOf[w];
				if (comp && g.FindInventory(comp)) g.TakeInventory(comp, 1);
			}
		}

		// When the story locks the host into empty hands, the guest is locked in too.
		let hw = host.player.ReadyWeapon;
		let hp = host.player.PendingWeapon;
		for (int f = 0; f < forcedWeapons.Size(); f++)
		{
			let fc = forcedWeapons[f];
			bool hostOn = (hw && hw.GetClass() == fc) || (hp && hp != WP_NOCHANGE && hp.GetClass() == fc);
			if (!hostOn) continue;
			let gw = Weapon(g.FindInventory(fc));
			if (gw && g.player.ReadyWeapon != gw && g.player.PendingWeapon != gw) g.player.PendingWeapon = gw;
		}

		// Empty-handed guest: raise what the host is holding (the Pib ticket in Act 1, for one).
		let gp = g.player.PendingWeapon;
		if (!g.player.ReadyWeapon && (!gp || gp == WP_NOCHANGE) && hw)
		{
			let same = Weapon(g.FindInventory(hw.GetClass()));
			if (same) g.player.PendingWeapon = same;
		}

		// Key cards, so guests get through the locked doors the host can open. A key box counts as
		// its card (some doors accept either). The boxes themselves stay with the host.
		for (int k = 0; k < keyCards.Size(); k++)
		{
			let card = (Class<Inventory>)(ClassByName(keyCards[k]));
			let box = ClassByName(keyBoxes[k]);
			if (!card) continue;
			bool hostHas = host.CountInv(card) > 0 || (box && host.FindInventory((Class<Inventory>)(box)) != null);
			if (hostHas && g.CountInv(card) == 0) g.GiveInventory(card, 1);
		}
	}

	// Guests pick up health, armor, ammo and backpacks they walk over (not keys, weapons or story
	// items, and nothing with a special, since that would run a script for the guest).
	void GuestPickups(PlayerPawn g)
	{
		Array<Inventory> touched;
		let it = BlockThingsIterator.Create(g, 64);
		while (it.Next())
		{
			let inv = Inventory(it.thing);
			if (!inv || inv.Owner || !inv.bSpecial || inv.special) continue;
			if (!GuestMayTake(inv)) continue;
			double blockdist = inv.radius + g.radius;
			if (abs(inv.pos.x - g.pos.x) >= blockdist || abs(inv.pos.y - g.pos.y) >= blockdist) continue;
			if (inv.pos.z > g.pos.z + g.height || inv.pos.z + inv.height < g.pos.z) continue;
			touched.Push(inv);
		}
		for (int i = 0; i < touched.Size(); i++)
		{
			let inv = touched[i];
			if (!inv || inv.Owner) continue;
			inv.Touch(g);
			if (!inv || inv.Owner || !inv.bSpecial) nGuestPickups++;
		}
	}

	bool GuestMayTake(Inventory inv)
	{
		if (inv is "Health" || inv is "BasicArmorPickup" || inv is "BasicArmorBonus" || inv is "BackpackItem") return true;
		let am = Ammo(inv);
		if (!am) return false;
		Class<Actor> base = am.GetParentAmmo();
		for (int i = 0; i < ammoDeny.Size(); i++) if (base == ClassByName(ammoDeny[i])) return false;
		return true;
	}

	// Health, armor and ammo: whatever anyone gained since last tic (a pickup, a script give),
	// everyone else gets too. Losses (damage, firing) stay with each player.
	void ShareSupplies()
	{
		// Every ammo type anyone holds gets a slot.
		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (!playeringame[p] || !players[p].mo) continue;
			for (Inventory it = players[p].mo.Inv; it; it = it.Inv)
			{
				let am = Ammo(it);
				if (!am) continue;
				Name n = am.GetClassName();
				if (ammoDeny.Find(n) != ammoDeny.Size()) continue;
				if (ammoNames.Find(n) == ammoNames.Size() && ammoNames.Size() < MAXAMMO) ammoNames.Push(n);
			}
		}
		int na = ammoNames.Size();
		Array<Class<Inventory> > amCls;
		for (int a = 0; a < na; a++) amCls.Push((Class<Inventory>)(ClassByName(ammoNames[a])));

		Array<int> gHp;
		Array<int> gAr;
		Array<int> gAm;
		int totHp = 0;
		int hpCap = 100;
		int totAr = 0;
		BasicArmor arSrc = null;
		Array<int> totAm;
		Array<int> maxAm;
		for (int a = 0; a < na; a++) { totAm.Push(0); maxAm.Push(0); }

		for (int p = 0; p < MAXPLAYERS; p++)
		{
			gHp.Push(0);
			gAr.Push(0);
			for (int a = 0; a < na; a++) gAm.Push(0);
			if (!playeringame[p] || !players[p].mo) continue;
			let mo = players[p].mo;
			if (mo.health <= 0) { resyncP[p] = 1; continue; }
			if (resync || resyncP[p]) continue;

			if (lastHealth[p] > 0 && mo.health > lastHealth[p])
			{
				gHp[p] = mo.health - lastHealth[p];
				totHp += gHp[p];
				hpCap = max(hpCap, mo.health);
			}
			let ar = BasicArmor(mo.FindInventory("BasicArmor"));
			int arNow = ar ? ar.Amount : 0;
			if (arNow > lastArmor[p])
			{
				gAr[p] = arNow - lastArmor[p];
				totAr += gAr[p];
				if (!arSrc || (ar && ar.SavePercent > arSrc.SavePercent)) arSrc = ar;
			}
			for (int a = 0; a < na; a++)
			{
				let am = amCls[a] ? Ammo(mo.FindInventory(amCls[a])) : null;
				int now = am ? am.Amount : 0;
				int d = now - ammoLastP[p * MAXAMMO + a];
				if (d > 0)
				{
					gAm[p * na + a] = d;
					totAm[a] += d;
					maxAm[a] = max(maxAm[a], am.MaxAmount);
				}
			}
		}

		// Hand out what the others gained.
		for (int q = 0; q < MAXPLAYERS; q++)
		{
			if (!playeringame[q] || !players[q].mo) continue;
			let mo = players[q].mo;
			if (mo.health <= 0 || resync || resyncP[q]) continue;

			int hp = totHp - gHp[q];
			if (hp > 0) mo.GiveBody(hp, hpCap);

			int ar = totAr - gAr[q];
			if (ar > 0 && arSrc)
			{
				let ga = BasicArmor(mo.FindInventory("BasicArmor"));
				if (ga)
				{
					if (ga.Amount <= 0 || arSrc.SavePercent > ga.SavePercent)
					{
						ga.SavePercent = arSrc.SavePercent;
						ga.MaxAbsorb = arSrc.MaxAbsorb;
						ga.MaxFullAbsorb = arSrc.MaxFullAbsorb;
						ga.ArmorType = arSrc.ArmorType;
						ga.Icon = arSrc.Icon;
					}
					ga.MaxAmount = max(ga.MaxAmount, arSrc.MaxAmount);
					ga.Amount = min(ga.Amount + ar, max(arSrc.Amount, arSrc.MaxAmount));
				}
			}

			for (int a = 0; a < na; a++)
			{
				int give = totAm[a] - gAm[q * na + a];
				if (give <= 0) continue;
				if (amCls[a]) GiveAmmoTo(mo, amCls[a], give, maxAm[a]);
			}
		}

		// Remember where everyone is now.
		for (int p = 0; p < MAXPLAYERS; p++)
		{
			if (!playeringame[p] || !players[p].mo) continue;
			let mo = players[p].mo;
			if (mo.health <= 0) continue;
			lastHealth[p] = mo.health;
			let ar = BasicArmor(mo.FindInventory("BasicArmor"));
			lastArmor[p] = ar ? ar.Amount : 0;
			for (int a = 0; a < na; a++)
			{
				let am = amCls[a] ? Ammo(mo.FindInventory(amCls[a])) : null;
				ammoLastP[p * MAXAMMO + a] = am ? am.Amount : 0;
			}
			resyncP[p] = 0;
		}
	}

	static void GiveAmmoTo(Actor g, Class<Inventory> cls, int amount, int hostMax)
	{
		let a = Ammo(g.FindInventory(cls));
		if (!a)
		{
			a = Ammo(Actor.Spawn(cls, g.pos));
			if (!a) return;
			a.ClearCounters();
			a.Amount = 0;
			a.AttachToOwner(g);
		}
		if (a.MaxAmount < hostMax) a.MaxAmount = hostMax;
		a.Amount = min(a.Amount + amount, a.MaxAmount);
	}

	// Gives a weapon without its ammo (the host's ammo gain is mirrored separately)
	// and without switching to it.
	static void GiveWeaponSilently(PlayerPawn g, Class<Weapon> cls)
	{
		let w = Weapon(Actor.Spawn(cls, g.pos));
		if (!w) return;
		w.ClearCounters();
		w.AmmoGive1 = 0;
		w.AmmoGive2 = 0;
		w.bDropped = true;	// a placed weapon would "stay" in co-op instead of being taken
		let keepReady = g.player.ReadyWeapon;
		let keepPending = g.player.PendingWeapon;
		if (!w.CallTryPickup(g))
		{
			if (w) w.Destroy();
			return;
		}
		if (w && !w.Owner) w.Destroy();
		if (keepReady) g.player.PendingWeapon = keepPending;
	}

	// ------------------------------------------------------------------------
	// Enemy multiplier (tpvc_enemymult): extra copies of the enemies the map places
	// ------------------------------------------------------------------------

	// How many of each enemy: tpvc_enemymult, or one per player in the game when it is 0 (the
	// launcher's default, since the host can start before every slot is filled).
	double EnemyMult()
	{
		double m = tpvc_enemymult;
		if (m <= 0.001)
		{
			m = 0;
			for (int i = 0; i < MAXPLAYERS; i++) if (playeringame[i]) m++;
		}
		return min(m, 10.0);	// up to 10 players, so up to 10 of each enemy
	}

	bool CanCopy(Actor a)
	{
		if (!a.bIsMonster || !a.bCountKill || a.bFriendly || a.bBoss || a.bBossDeath || a.player) return false;
		if (a.health <= 0 || a.tid != 0 || a.special != 0 || a.bDormant) return false;
		// Placed by the map, not spawned by a script or another monster.
		if (!(a.SpawnFlags & (MTF_SINGLE | MTF_COOPERATIVE | MTF_DEATHMATCH))) return false;
		// Civilians and props never attack.
		if (!a.FindState("Missile") && !a.FindState("Melee")) return false;
		if (copyDeny.Find(a.GetClassName()) != copyDeny.Size()) return false;
		return true;
	}

	void MultiplyEnemies()
	{
		mapOriginals = 0;
		mapCopies = 0;
		mapExpected = 0;
		double mult = EnemyMult();
		if (mult < 1.001) return;

		Array<Actor> originals;
		let it = ThinkerIterator.Create("Actor");
		for (Actor a = Actor(it.Next()); a; a = Actor(it.Next()))
			if (CanCopy(a)) originals.Push(a);

		if (tpvc_debug)
		{
			// Why hostile monsters on this map were or weren't copied.
			int nHostile = 0;
			int rTagged = 0;
			int rScripted = 0;
			int rNoAttack = 0;
			int rDenied = 0;
			int rBoss = 0;
			int rDormant = 0;
			Array<Name> skippedNames;
			it = ThinkerIterator.Create("Actor");
			for (Actor a = Actor(it.Next()); a; a = Actor(it.Next()))
			{
				if (!a.bIsMonster || !a.bCountKill || a.bFriendly || a.player || a.health <= 0) continue;
				nHostile++;
				if (a.bBoss || a.bBossDeath) rBoss++;
				else if (a.tid != 0 || a.special != 0) rTagged++;
				else if (a.bDormant) rDormant++;
				else if (!(a.SpawnFlags & (MTF_SINGLE | MTF_COOPERATIVE | MTF_DEATHMATCH))) rScripted++;
				else if (!a.FindState("Missile") && !a.FindState("Melee")) { rNoAttack++; if (skippedNames.Find(a.GetClassName()) == skippedNames.Size()) skippedNames.Push(a.GetClassName()); }
				else if (copyDeny.Find(a.GetClassName()) != copyDeny.Size()) rDenied++;
			}
			String na = "";
			for (int i = 0; i < skippedNames.Size(); i++) na = na .. " " .. skippedNames[i];
			Dbg(String.Format("monsters on map: %d hostile; skipped boss %d, tagged/special %d, dormant %d, script-spawned %d, never attack %d (%s), story %d",
				nHostile, rBoss, rTagged, rDormant, rScripted, rNoAttack, na, rDenied));
		}

		double extraEach = mult - 1;
		double acc = 0;
		spawningCopies = true;
		for (int i = 0; i < originals.Size(); i++)
		{
			int extra = int(extraEach);
			acc += extraEach - extra;
			if (acc >= 0.999) { extra++; acc -= 1; }
			mapExpected += extra;
			for (int k = 0; k < extra; k++)
			{
				let c = SpawnCopy(originals[i], k);
				if (c) { myCopies.Push(c); mapCopies++; }
			}
		}
		spawningCopies = false;
		mapOriginals = originals.Size();
		Dbg(String.Format("enemy multiplier x%.2f: %d placed enemies, %d extra spawned (%d wanted)", mult, mapOriginals, mapCopies, mapExpected));
	}

	// Script waves: monsters a script spawns as a tagged group (Un bacio's waves all share one
	// tag, and its script waits until nothing with that tag is left). Copies join the group, so
	// the script waits for them too. One-off spawns with a tag of their own stay single.
	override void WorldThingSpawned(WorldEvent e)
	{
		if (spawningCopies || !multiplayer || !modPresent || EnemyMult() < 1.001) return;
		Actor a = e.Thing;
		if (!a || !a.bIsMonster || a.player) return;
		if (a.SpawnFlags & (MTF_SINGLE | MTF_COOPERATIVE | MTF_DEATHMATCH)) return;	// map-placed: handled at map start
		newSpawns.Push(a);
	}

	bool CanCopyWave(Actor a)
	{
		if (!a.bIsMonster || !a.bCountKill || a.bFriendly || a.bBoss || a.bBossDeath || a.player) return false;
		if (a.health <= 0 || a.tid == 0 || a.special != 0 || a.bDormant) return false;
		if (!a.FindState("Missile") && !a.FindState("Melee")) return false;
		if (copyDeny.Find(a.GetClassName()) != copyDeny.Size()) return false;
		return true;
	}

	static int CountTid(int tid)
	{
		int n = 0;
		let it = level.CreateActorIterator(tid);
		for (Actor a = it.Next(); a; a = it.Next()) if (a.health > 0) n++;
		return n;
	}

	void CopyScriptWaves()
	{
		Array<Actor> cands;
		for (int i = 0; i < newSpawns.Size(); i++)
		{
			let a = newSpawns[i];
			if (a && myCopies.Find(a) == myCopies.Size() && CanCopyWave(a)) cands.Push(a);
		}
		newSpawns.Clear();
		if (cands.Size() == 0) return;

		double mult = EnemyMult();
		double extraEach = mult - 1;
		int made = 0;
		spawningCopies = true;
		for (int i = 0; i < cands.Size(); i++)
		{
			let o = cands[i];
			if (!o || CountTid(o.tid) < 2) continue;
			int extra = int(extraEach);
			waveAcc += extraEach - extra;
			if (waveAcc >= 0.999) { extra++; waveAcc -= 1; }
			for (int k = 0; k < extra && mapWaveCopies + made < MAX_WAVE_COPIES; k++)
			{
				let c = SpawnCopy(o, k);
				if (c) { c.ChangeTid(o.tid); myCopies.Push(c); made++; }
			}
		}
		spawningCopies = false;
		mapWaveCopies += made;
		if (made > 0) Dbg(String.Format("enemy multiplier: %d extra enemies joined a scripted wave", made));
	}

	static Actor SpawnCopy(Actor o, int k)
	{
		static const double ANGS[] = { 180, 90, -90, 0, 135, -135, 45, -45 };
		let cls = (Class<Actor>)(o.GetClass());
		for (int d = 0; d < 3; d++)
		{
			double dist = o.radius * (d == 0 ? 2.5 : (d == 1 ? 4.5 : 6.5)) + 8;
			for (int a = 0; a < 8; a++)
			{
				double ang = o.angle + ANGS[(a + k * 3) % 8];
				FLineTraceData tr;
				o.LineTrace(ang, dist + o.radius, 0, TRF_THRUACTORS, o.height * 0.5, 0, 0, tr);
				if (tr.HitType != TRACE_HitNone) continue;
				Vector2 p = o.Vec2Angle(dist, ang);
				let c = Actor.Spawn(cls, (p.x, p.y, o.pos.z));
				if (!c) return null;
				c.FindFloorCeiling();
				if (!c.bNoGravity) c.SetZ(c.floorz);
				bool ok = (c.bNoGravity || abs(c.floorz - o.floorz) <= 24) && c.ceilingz - c.floorz >= c.height && c.TestMobjLocation();
				if (!ok)
				{
					c.ClearCounters();
					c.Destroy();
					continue;
				}
				c.angle = o.angle;
				c.bAmbush = o.bAmbush;
				c.bStandStill = o.bStandStill;
				c.Scale = o.Scale;
				c.Translation = o.Translation;
				return c;
			}
		}
		return null;
	}

	// ------------------------------------------------------------------------
	// Placement
	// ------------------------------------------------------------------------

	void DoPlace(int i)
	{
		let mo = players[i].mo;
		if (!mo || mo.health <= 0) return;

		Actor anchor = null;
		if (i > 0)
		{
			let h = players[0].mo;
			if (h && h.health > 0) anchor = h;
		}
		else
		{
			for (int j = 1; j < MAXPLAYERS; j++)
			{
				if (playeringame[j] && players[j].mo && players[j].mo.health > 0) { anchor = players[j].mo; break; }
			}
		}

		if (anchor)
		{
			PutBeside(mo, anchor, i > 0 ? i - 1 : 0);	// spread friends around the host
			nPlaced++;
			Dbg(String.Format("placed player %d next to player %d", i + 1, anchor.PlayerNumber() + 1));
		}
		else if (haveSafe[i])
		{
			mo.SetOrigin((safeX[i], safeY[i], safeZ[i]), false);
			mo.vel = (0, 0, 0);
			mo.ClearInterpolation();
			nPlaced++;
			Dbg(String.Format("placed player %d at their last safe spot", i + 1));
		}
		if (i == 0) { hostLastPos = mo.pos; hostPosValid = true; }
	}

	static bool PutBeside(Actor mo, Actor anchor, int rot = 0)
	{
		static const double ANGS[] = { 180, 90, -90, 135, -135, 45, -45, 0 };
		static const double DISTS[] = { 48, 72, 96, 32, 128 };
		for (int d = 0; d < 5; d++)
		{
			for (int a = 0; a < 8; a++)
			{
				double ang = anchor.angle + ANGS[(a + rot) % 8];
				double dist = DISTS[d];
				FLineTraceData tr;
				anchor.LineTrace(ang, dist + mo.radius, 0, TRF_THRUACTORS, anchor.height * 0.5, 0, 0, tr);
				if (tr.HitType != TRACE_HitNone) continue;
				if (TryPlaceAt(mo, anchor.Vec2Angle(dist, ang), anchor)) return true;
			}
		}
		// Nowhere free next to them: share their spot (players pass through each other
		// with sv_noplayerclip, which the launchers turn on).
		mo.SetOrigin(anchor.pos, false);
		mo.angle = anchor.angle;
		mo.vel = (0, 0, 0);
		mo.ClearInterpolation();
		return false;
	}

	static bool TryPlaceAt(Actor mo, Vector2 p, Actor anchor)
	{
		Vector3 old = mo.pos;
		mo.SetOrigin((p.x, p.y, anchor.pos.z), false);
		mo.FindFloorCeiling();
		double fz = mo.floorz;
		bool ok = abs(fz - anchor.floorz) <= 24 && mo.ceilingz - fz >= mo.height;
		if (ok)
		{
			mo.SetZ(fz);
			ok = mo.TestMobjLocation();
		}
		// Players can overlap (sv_noplayerclip), so keep friends from landing on each other.
		for (int i = 0; ok && i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			let other = players[i].mo;
			if (other && other != mo && other != anchor && (other.pos.xy - mo.pos.xy).Length() < mo.radius * 2) ok = false;
		}
		if (!ok)
		{
			mo.SetOrigin(old, false);
			mo.FindFloorCeiling();
			return false;
		}
		mo.angle = anchor.angle;
		mo.vel = (0, 0, 0);
		if (mo.player) mo.player.vel = (0, 0);
		mo.ClearInterpolation();
		return true;
	}

	// ------------------------------------------------------------------------
	// Console: netevent tpvc_warp | tpvc_status | tpvc_selftest
	// ------------------------------------------------------------------------

	override void NetworkProcess(ConsoleEvent e)
	{
		if (!multiplayer || !modPresent) return;
		if (e.Name ~== "tpvc_warp")
		{
			if (!Active()) return;
			if (e.Player == 0)
			{
				for (int i = 1; i < MAXPLAYERS; i++)
					if (playeringame[i] && players[i].mo && players[i].mo.health > 0) placeNow[i] = 1;
			}
			else if (e.Player > 0 && e.Player < MAXPLAYERS)
			{
				placeNow[e.Player] = 1;
			}
		}
		else if (e.Name ~== "tpvc_status")
		{
			PrintStatus();
		}
		else if (e.Name ~== "tpvc_selftest")
		{
			StartSelfTest();
		}
	}

	void PrintStatus()
	{
		int nLive = 0;
		int nCorpse = 0;
		let cit = ThinkerIterator.Create("TPVC_Costume");
		for (let a = TPVC_Costume(cit.Next()); a; a = TPVC_Costume(cit.Next())) { if (a.orphan) nCorpse++; else nLive++; }
		Console.Printf("\cf[co-op status]\c- map %s tic %d  mod=%d  blocked=%d doors=%d rattles=%d pickups=%d rerouted=%d placed=%d respawns=%d  enemies x%.2f: %d placed, %d extra, %d extra in waves  costumes %d (+%d on corpses)  stand-ins %d/%d (%d left)  home armed %d",
			level.MapName, level.maptime, modPresent ? 1 : 0, nBlocked, nGuestDoors, nRattles, nGuestPickups, nRerouted, nPlaced, nRespawns, EnemyMult(), mapOriginals, mapCopies, mapWaveCopies, nLive, nCorpse,
			standInsMade, standInsWanted, standInsLeft, nHomeArmed);
		for (int i = 0; i < MAXPLAYERS; i++)
		{
			if (!playeringame[i]) continue;
			let mo = players[i].mo;
			if (!mo) { Console.Printf("  P%d: no body", i + 1); continue; }
			int nw = 0;
			for (Inventory it = mo.Inv; it; it = it.Inv) if (it is "Weapon") nw++;
			String rw = mo.player.ReadyWeapon ? String.Format("%s", mo.player.ReadyWeapon.GetClassName()) : "none";
			Console.Printf("  P%d: hp %d  pos (%d, %d, %d)  speed %.2f jumpz %.1f  userange %d pickup %d  hud %d  weapons %d (%s)  blendA %.2f  looks like %s",
				i + 1, mo.health, int(mo.pos.x), int(mo.pos.y), int(mo.pos.z), mo.Speed, mo.JumpZ, int(mo.UseRange), mo.bPickup ? 1 : 0,
				hudItem ? mo.CountInv(hudItem) : -1, nw, rw, mo.player.BlendA, CharacterOf(i));
		}
	}

	// ------------------------------------------------------------------------
	// Self-test: exercises every rule in the running game and prints PASS/FAIL.
	// Changes game state (kills and respawns both players), so it's only for testing.
	// ------------------------------------------------------------------------

	void StartSelfTest()
	{
		if (!Active()) { Console.Printf("tpvc_selftest: needs a net game with the mod loaded"); return; }
		testGuest = -1;
		for (int i = 1; i < MAXPLAYERS; i++)
			if (playeringame[i] && players[i].mo && players[i].mo.health > 0) { testGuest = i; break; }
		if (testGuest < 0 || players[0].mo.health <= 0) { Console.Printf("tpvc_selftest: needs a living host and guest"); return; }
		testStage = 1;
		testPass = 0;
		testFail = 0;
		Console.Printf("\cf[co-op selftest]\c- starting on %s with player %d as the guest", level.MapName, testGuest + 1);
	}

	void Check(bool ok, String what)
	{
		if (ok) { testPass++; Console.Printf("\cd  PASS\c- %s", what); }
		else { testFail++; Console.Printf("\cg  FAIL\c- %s", what); }
	}

	void SelfTestStep()
	{
		PlayerPawn host = players[0].mo;
		PlayerPawn g = players[testGuest].mo;
		if (!playeringame[testGuest] || !g || !host)
		{
			Console.Printf("\cf[co-op selftest]\c- lost a player, stopping");
			testStage = 0;
			return;
		}

		if (testStage == 1)
		{
			Dbg(String.Format("selftest: guest slot %d, guest pawn is player %d, host pawn is player %d", testGuest, g.PlayerNumber(), host.PlayerNumber()));
			// 1. The guest can't activate lines.
			int tried = 0;
			bool blockedOk = false;
			for (int l = 0; l < level.Lines.Size() && tried < 30; l++)
			{
				Line ln = level.Lines[l];
				if (!ln.special) continue;
				if (IsGuestDoor(ln) || RattleIndex(ln) >= 0) continue;
				int type = 0;
				if (ln.activation & SPAC_Cross) type = SPAC_Cross;
				else if (ln.activation & SPAC_Use) type = SPAC_Use;
				if (!type) continue;
				tried++;
				int before = nBlocked;
				bool ran = ln.Activate(g, 0, type);
				if (nBlocked == before + 1 && !ran) { blockedOk = true; break; }
			}
			Check(blockedOk, String.Format("guest is blocked from activating a scripted line (%d tried)", tried));

			// Locked doors the story counts on the host (Home): a guest's try counts for the host.
			for (int l = 0; l < level.Lines.Size(); l++)
			{
				Line ln = level.Lines[l];
				int rk = RattleIndex(ln);
				if (rk < 0 || !(ln.activation & SPAC_Use)) continue;
				let cls = (Class<Inventory>)(ClassByName(rattleItems[rk]));
				int had = host.CountInv(cls);
				ln.Activate(g, 0, SPAC_Use);
				int now = host.CountInv(cls);
				Check(now == had + 1, String.Format("a guest trying a locked door counts for the host (%s %d -> %d)", rattleItems[rk], had, now));
				host.TakeInventory(cls, now - had);
				break;
			}

			// Guests who travelled in had a stand-in body while the map loaded, so the map's start
			// (ENTER) script ran once, for the host, and none of the stand-ins is still around.
			if (loadByTravel)
			{
				int still = 0;
				let sit = ThinkerIterator.Create("TPVC_TravelStandIn");
				while (sit.Next()) still++;
				Check(standInsMade == standInsWanted && standInsLeft == 0 && still == 0,
					String.Format("guests arrived without their own run of the map's start script (stand-ins %d of %d, %d left over, %d now)", standInsMade, standInsWanted, standInsLeft, still));
			}

			// 2. A guest kill runs the victim's death special as the host.
			let d = Actor.Spawn("TPVC_Dummy", g.pos);
			int hostTid = host.tid;
			int guestTid = g.tid;
			int before = nRerouted;
			d.special = 176;	// Thing_ChangeTID(0 = activator, 31337)
			d.args[0] = 0;
			d.args[1] = 31337;
			d.DamageMobj(g, g, 1000, 'None', DMG_FORCED);
			Check(nRerouted == before + 1 && host.tid == 31337 && g.tid == guestTid, "a guest kill runs the death special with the host as activator");
			if (host.tid != hostTid) host.ChangeTid(hostTid);
			if (g.tid != guestTid) g.ChangeTid(guestTid);

			// 3. Pickups: a health bonus under the guest gets picked up next tic and the host gets the
			//    +1 too; a key box under the guest stays put.
			tHostHp = host.health;
			tGuestHp = g.health;
			tHealth = Actor.Spawn("HealthBonus", g.pos);
			// The key box only means something if the host isn't standing on it too (in the tiniest
			// start rooms several players share one spot, and the host may take it, as they should).
			tBox = Actor.Spawn("CAJALLAVER", g.pos);
			if (tBox && max(abs(host.pos.x - g.pos.x), abs(host.pos.y - g.pos.y)) <= host.radius + tBox.radius + 2) { tBox.Destroy(); tBox = null; }
			GuestPickups(g);	// now, before next tic's teleport check moves the guest away

			// HUD: pretend a story scene took it from the host.
			tHudSet = false;
			if (hudItem)
			{
				host.TakeInventory(hudItem, host.CountInv(hudItem));
				hudPrev = 1;
				tHudSet = true;
			}

			// Key card: the host gets one, the guest should too.
			tKeyGiven = false;
			if (host.CountInv("RedCard") == 0 && !host.FindInventory("CAJALLAVER"))
			{
				host.GiveInventory("RedCard", 1);
				tKeyGiven = true;
			}

			// 4. Enemy multiplier made its copies when the map started.
			if (EnemyMult() > 1.001 && mapOriginals > 0)
				Check(mapCopies > 0 && mapCopies * 2 >= mapExpected, String.Format("enemy multiplier x%.2f: %d extra enemies next to %d placed ones (%d wanted)", EnemyMult(), mapCopies, mapOriginals, mapExpected));
			else
				Console.Printf("  SKIP enemy multiplier (x%.2f, %d copyable enemies on this map)", EnemyMult(), mapOriginals);

			// 5. A scripted wave (three monsters sharing a tag) gets extra members with the same tag.
			tWaveBefore = mapWaveCopies;
			if (EnemyMult() > 1.001)
			{
				for (int w = 0; w < 3; w++)
				{
					let foe = Actor.Spawn("TPVC_TestFoe", host.pos + (0, 0, 4));
					if (foe) foe.ChangeTid(31001);
				}
			}

			// Set up the mirrored checks for the next tic.
			tWeap = null;
			for (int w = 0; w < mirrorWeapons.Size(); w++)
			{
				let cls = mirrorWeapons[w];
				if (forcedWeapons.Find(cls) != forcedWeapons.Size()) continue;
				if (!host.FindInventory(cls) && !g.FindInventory(cls)) { tWeap = cls; break; }
			}
			if (tWeap) GiveWeaponSilently(host, tWeap);

			tAmmo = null;
			for (Inventory it = host.Inv; it; it = it.Inv)
			{
				let am = Ammo(it);
				if (am && ammoDeny.Find(am.GetClassName()) == ammoDeny.Size() && am.Amount + 3 <= am.MaxAmount)
				{
					tAmmo = (Class<Ammo>)(am.GetClass());
					let ga = g.FindInventory(tAmmo);
					tAmmoGuest = ga ? ga.Amount : 0;
					am.Amount += 3;
					break;
				}
			}

			// Ammo the guest gains reaches the host too.
			tAmmoG = null;
			for (Inventory it = g.Inv; it; it = it.Inv)
			{
				let am = Ammo(it);
				if (!am || (tAmmo && am.GetClass() == tAmmo)) continue;
				if (ammoDeny.Find(am.GetClassName()) != ammoDeny.Size() || am.Amount + 2 > am.MaxAmount) continue;
				let ha2 = host.FindInventory((Class<Inventory>)(am.GetClass()));
				if (ha2 && ha2.Amount + 2 > ha2.MaxAmount) continue;
				tAmmoG = (Class<Ammo>)(am.GetClass());
				tAmmoHost = ha2 ? ha2.Amount : 0;
				am.Amount += 2;
				break;
			}

			tSpeed = host.Speed;
			tBlendR = host.player.BlendR; tBlendG = host.player.BlendG;
			tBlendB = host.player.BlendB; tBlendA = host.player.BlendA;
			host.Speed = 0.37;
			host.player.BlendR = 1; host.player.BlendG = 0; host.player.BlendB = 0; host.player.BlendA = 0.3;

			// Pretend the host just got teleported.
			tPlacedBefore = nPlaced;
			hostLastPos = host.pos + (1000, 0, 0);

			// Pain frame.
			let pain = g.FindState("Pain");
			if (pain) g.SetState(pain);

			// Characters: every one was found, and every frame they use exists in the mod (or in
			// this add-on's TEXTURES, for Ella's turned frames). Then dress the guest as Ella.
			int nOk = 0;
			for (int c = 1; c < chId.Size(); c++) if (chOk[c]) nOk++;
			Check(chId.Size() > 1 && nOk == chId.Size() - 1, String.Format("all %d characters are available (%d found)", chId.Size() - 1, nOk));
			int iconPics = 0;
			int iconWeapons = 0;
			for (int k = 0; k < wiFrame.Size(); k++)
			{
				if (TexMan.CheckForTexture(String.Format("TPWI%c0", 65 + wiFrame[k]), TexMan.Type_Sprite).IsValid()) iconPics++;
				if (ClassByName(wiClass[k]) != null) iconWeapons++;
			}
			Check(wiSprite >= 0 && iconPics == wiFrame.Size() && iconWeapons == wiClass.Size(), String.Format("every weapon icon has its picture and weapon (%d pictures, %d weapons of %d)", iconPics, iconWeapons, wiClass.Size()));
			int missing = 0;
			String firstMissing = "";
			for (int k = 0; k < frName.Size(); k++)
			{
				String fn = frName[k];
				bool have = TexMan.CheckForTexture(fn .. "1", TexMan.Type_Sprite).IsValid() || TexMan.CheckForTexture(fn .. "0", TexMan.Type_Sprite).IsValid();
				if (!have) { missing++; if (firstMissing == "") firstMissing = fn; }
			}
			Check(missing == 0, String.Format("every character frame exists (%d frames, %d missing%s%s)", frName.Size(), missing, missing ? ", first " : "", firstMissing));
			tCharSave = forceChar[testGuest];
			tCharIdx = FindCharacter("ella");
			tCostume = null;
			if (tCharIdx > 0) forceChar[testGuest] = tCharIdx;

			testStage = 2;
			return;
		}

		if (testStage == 2)
		{
			bool picked = !tHealth || Inventory(tHealth).Owner != null;
			Check(picked && g.health == tGuestHp + 1, String.Format("guest picks up a health bonus (%d -> %d)", tGuestHp, g.health));
			Check(host.health == tHostHp + 1, String.Format("the host gets the guest's pickup too (%d -> %d)", tHostHp, host.health));
			if (tBox) Check(Inventory(tBox).Owner == null, "guest leaves a key box for the host");
			else Console.Printf("  SKIP key box (the host is standing on the guest's spot)");
			if (tBox && !Inventory(tBox).Owner) tBox.Destroy();
			if (tHealth && !Inventory(tHealth).Owner) tHealth.Destroy();

			if (tAmmoG)
			{
				let ha2 = host.FindInventory((Class<Inventory>)(tAmmoG));
				int now = ha2 ? ha2.Amount : 0;
				Check(now == tAmmoHost + 2, String.Format("the host gets ammo the guest gains (%s %d -> %d)", tAmmoG.GetClassName(), tAmmoHost, now));
				if (ha2) ha2.Amount -= 2;
				let ga2 = g.FindInventory((Class<Inventory>)(tAmmoG));
				if (ga2) ga2.Amount -= 2;
			}

			if (tHudSet)
			{
				Check(g.CountInv(hudItem) == 0, "guest's HUD hides when a story scene hides the host's");
				g.GiveInventory(hudItem, 1);	// the guest gets hurt or attacks
			}

			if (tKeyGiven)
			{
				Check(g.CountInv("RedCard") > 0, "guest gets the key card the host has");
				host.TakeInventory("RedCard", 1);
				g.TakeInventory("RedCard", 1);
			}

			if (pibs.Size() > 0 && pibs[0] && pibs[0].health > 0)
				Check(pibs[0].target == host, "the Pib validator checks the host's ticket");

			if (tWeap) Check(g.FindInventory(tWeap) != null, String.Format("guest gets the weapon the host picks up (%s)", tWeap.GetClassName()));
			else Console.Printf("  SKIP weapon mirror (host already has every weapon)");

			if (tAmmo)
			{
				let ga = g.FindInventory(tAmmo);
				int now = ga ? ga.Amount : 0;
				Check(now == min(tAmmoGuest + 3, ga ? ga.MaxAmount : 3), String.Format("guest gets the ammo the host picks up (%s %d -> %d)", tAmmo.GetClassName(), tAmmoGuest, now));
				let ha = host.FindInventory(tAmmo);
				if (ha) ha.Amount -= 3;
				if (ga) ga.Amount = tAmmoGuest;
			}
			else Console.Printf("  SKIP ammo mirror (host has no ammo with room)");

			Check(abs(g.Speed - 0.37) < 0.001, String.Format("guest copies the host's scripted speed (%.2f)", g.Speed));
			Check(abs(g.player.BlendA - 0.3) < 0.001 && abs(g.player.BlendR - 1) < 0.001, "guest copies the host's screen fade");
			host.Speed = tSpeed;
			host.player.BlendR = tBlendR; host.player.BlendG = tBlendG;
			host.player.BlendB = tBlendB; host.player.BlendA = tBlendA;

			double dist = (g.pos.xy - host.pos.xy).Length();
			Check(nPlaced > tPlacedBefore && dist < 150, String.Format("guest follows the host after a teleport (now %d units away)", int(dist)));

			int nGuests = 0;
			bool allNear = true;
			bool allApart = true;
			for (int i = 1; i < MAXPLAYERS; i++)
			{
				if (!playeringame[i] || !players[i].mo) continue;
				nGuests++;
				if ((players[i].mo.pos.xy - host.pos.xy).Length() >= 150) allNear = false;
				for (int j = i + 1; j < MAXPLAYERS; j++)
					if (playeringame[j] && players[j].mo && (players[i].mo.pos.xy - players[j].mo.pos.xy).Length() < 8) allApart = false;
			}
			if (nGuests > 1)
			{
				Check(allNear, String.Format("all %d friends land next to the host", nGuests));
				if (!allApart) Console.Printf("  NOTE not enough room here for everyone to have their own spot; some friends share one until they walk off");
			}

			Check((g.sprite == playSprite && g.frame != 6) || costumes[testGuest] != null, "a hurt Tilin shows Tilin, not Doomguy's pain frame");

			if (tCharIdx > 0)
			{
				let cs = costumes[testGuest];
				bool dressed = cs != null && cs.charIdx == tCharIdx && g.sprite == tnt1Sprite && !g.bInvisible && (cs.pos - g.pos).Length() < 1 && abs(cs.Scale.X - chScale[tCharIdx]) < 0.001;
				bool frameOk = false;	// any of Ella's living frames (the guest is in its pain state here)
				int fs = roleStart[tCharIdx * 5];
				int fe = roleStart[tCharIdx * 5 + ROLE_DEATH];
				for (int k = fs; k < fe && cs; k++) if (cs.sprite == frS[k] && cs.frame == frF[k]) frameOk = true;
				Check(dressed && frameOk, String.Format("a guest who picks Ella is drawn as Ella where they stand (costume %s, placed %d, frame %d)", cs ? "there" : "missing", dressed ? 1 : 0, frameOk ? 1 : 0));
				tCostume = cs;
				bool faces = TexMan.CheckForTexture("TPFST00", TexMan.Type_Any).IsValid() && TexMan.CheckForTexture("TPFDEAD0", TexMan.Type_Any).IsValid();
				Check(g.CountInv("TPVC_EllaFace") > 0 && faces, String.Format("a guest dressed as Ella gets Ella's HUD face (faces %s)", faces ? "found" : "MISSING"));

				// The picture of the guest's weapon floats over their (Ella's) head, or there is
				// none if what they hold has no picture.
				let gw = players[testGuest].ReadyWeapon;
				int want = IconFrame(gw);
				let ic = icons[testGuest];
				bool icOk = want < 0 ? ic == null : (ic != null && ic.sprite == wiSprite && ic.frame == want && ic.pos.z > g.pos.z + 40);
				Check(icOk, String.Format("the guest's weapon icon matches what they hold (%s, icon %s)", gw ? String.Format("%s", gw.GetClassName()) : "nothing", ic ? "shown" : "none"));

				// Monsters still see a player who looks like someone else.
				let eye = Actor.Spawn("TPVC_Dummy", g.pos + (0, 0, 8));
				bool seen = eye && eye.CheckSight(g);
				Check(seen, "monsters can still see a guest dressed as Ella");
				if (eye) eye.Destroy();
			}

			if (EnemyMult() > 1.001)
			{
				int inWave = CountTid(31001);
				int wanted = 3 + int(3 * (EnemyMult() - 1) + 0.001);
				Check(mapWaveCopies > tWaveBefore && inWave > 3 && inWave <= wanted + 1, String.Format("a scripted wave of 3 grows to %d with the same tag (x%.2f)", inWave, EnemyMult()));
				tInWave = inWave;
			}

			if (tWeap) host.TakeInventory(tWeap, 1);
			testStage = 3;
			return;
		}

		if (testStage == 3)
		{
			if (tHudSet)
			{
				Check(g.CountInv(hudItem) > 0 && host.CountInv(hudItem) == 0, "a guest who earns the HUD back keeps it");
				host.GiveInventory(hudItem, 1);
				tHudSet = false;
			}
			if (tWeap) Check(g.FindInventory(tWeap) == null, "guest loses a weapon when the host loses it");
			Check(abs(g.Speed - host.Speed) < 0.001, "guest speed follows the host back");

			if (EnemyMult() > 1.001)
			{
				// The copies must not get copied again on the next tic.
				int inWave = CountTid(31001);
				Check(inWave == tInWave, String.Format("the wave stays at %d a tic later (copies aren't copied again)", inWave));
				Array<Actor> foes;
				let fi = level.CreateActorIterator(31001);
				for (Actor f = fi.Next(); f; f = fi.Next()) foes.Push(f);
				for (int k = 0; k < foes.Size(); k++) if (foes[k]) { foes[k].ClearCounters(); foes[k].Destroy(); }
				mapWaveCopies = tWaveBefore;
			}

			// 4. Guest dies and respawns: should come back next to the host, not at the map start.
			tRespawnsBefore = nRespawns;
			tPlacedBefore = nPlaced;
			g.DamageMobj(null, null, 1000000, 'Telefrag', DMG_FORCED);	// telefrag damage gets through god mode
			testWait = 0;
			testStage = 4;
			return;
		}

		if (testStage == 4 || testStage == 6)
		{
			// Wait for the death, then do what pressing +use does.
			int pi = testStage == 4 ? testGuest : 0;
			let who = players[pi].mo;
			if (players[pi].playerstate == PST_DEAD) players[pi].playerstate = PST_REBORN;
			if (nRespawns > tRespawnsBefore && who && who.health > 0) testStage++;
			else if (++testWait > 70) { Check(false, "player respawned within 2 seconds"); testStage = 0; }
			return;
		}

		if (testStage == 5)
		{
			double dist = (g.pos.xy - host.pos.xy).Length();
			Check(nPlaced > tPlacedBefore && dist < 150, String.Format("a respawned guest comes back next to the host (%d units away)", int(dist)));

			if (tCharIdx > 0 && tCostume)
			{
				// The old body's costume stays on the corpse, playing Ella's death; the new body has its own.
				int ds = roleStart[tCharIdx * 5 + ROLE_DEATH];
				int dn = roleLen[tCharIdx * 5 + ROLE_DEATH];
				bool dying = false;
				for (int k = ds; k < ds + dn; k++) if (tCostume.sprite == frS[k] && tCostume.frame == frF[k]) dying = true;
				Check(tCostume.orphan && dying, "the costume stays on the corpse and plays the character's death");
				let cs = costumes[testGuest];
				Check(cs != null && cs != tCostume && cs.charIdx == tCharIdx && g.sprite == tnt1Sprite, "the respawned guest is still Ella");
				Check(tCostume.body != null && tCostume.body != g && tCostume.body.sprite == tnt1Sprite, "the guest's old Tilin body stays hidden under the costume");
				forceChar[testGuest] = 0;	// back to Tilin, checked at the end
			}

			// 5. Host dies and respawns: should come back next to the guest.
			tRespawnsBefore = nRespawns;
			tPlacedBefore = nPlaced;
			host.DamageMobj(null, null, 1000000, 'Telefrag', DMG_FORCED);	// telefrag damage gets through god mode
			testWait = 0;
			testStage = 6;
			return;
		}

		if (testStage == 7)
		{
			double dist = (g.pos.xy - host.pos.xy).Length();
			Check(nPlaced > tPlacedBefore && dist < 150, String.Format("a respawned host comes back next to the guest (%d units away)", int(dist)));
			Check(abs(host.Speed - tSpeed) < 0.001, String.Format("a respawned host keeps the map's scripted speed (%.2f)", host.Speed));
			// Doors: the guest can use one of this map's doors (its script teleports them a moment later).
			Line door = null;
			for (int l = 0; l < level.Lines.Size(); l++)
			{
				Line ln = level.Lines[l];
				if ((ln.activation & SPAC_Use) && IsGuestDoor(ln)) { door = ln; break; }
			}
			if (door)
			{
				int before = nGuestDoors;
				door.Activate(g, 0, SPAC_Use);
				Check(nGuestDoors == before + 1, String.Format("guest opens a door (line %d, script %d)", door.Index(), door.args[0]));
			}
			else Console.Printf("  SKIP doors (none a guest can open on this map)");

			if (tCharIdx > 0)
			{
				Check(costumes[testGuest] == null && g.sprite != tnt1Sprite && !g.bInvisible, "switching back to Tilin shows Tilin again");
				Check(g.CountInv("TPVC_EllaFace") == 0, "and gives back Tilin's HUD face");
				forceChar[testGuest] = tCharSave;
				if (tCostume) tCostume.Destroy();
				tCostume = null;
				tCharIdx = 0;
			}

			Console.Printf("\cf[co-op selftest]\c- %d passed, %d failed", testPass, testFail);
			testStage = 0;
		}
	}
}

// Runs after players, actors and ACS every tic. Only exists in net games.
class TPVC_Late : Thinker
{
	override void Tick()
	{
		let h = TPVC_Handler(StaticEventHandler.Find("TPVC_Handler"));
		if (!h || !multiplayer)
		{
			Destroy();
			return;
		}
		h.LateTick();
	}
}

// What a player who picked a character looks like to everyone else. It has no body of its own:
// the handler moves it onto the player every tic and picks its frame from what the player is
// doing. When the player respawns, the old one stays with the corpse and finishes dying.
class TPVC_Costume : Actor
{
	int pnum;
	int charIdx;
	int deathTic;
	bool orphan;
	Actor body;		// orphans: the player's old body (Tilin's corpse), kept hidden
	int bodyTries;

	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+NOGRAVITY
		+DONTSPLASH
		+NOTONAUTOMAP
		+NOTELEPORT
		+NOTARGET
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}

	override void Tick()
	{
		Super.Tick();
		if (!orphan) return;
		bInvisible = false;	// a corpse now: its player looks out of their new body
		let h = TPVC_Handler(StaticEventHandler.Find("TPVC_Handler"));
		if (deathTic >= 0 && h && charIdx > 0 && charIdx < h.chId.Size()) h.ShowDeath(self, charIdx, level.maptime - deathTic);

		// The old body stays behind too. Find it (the nearest dead player body that no player is
		// using) and keep it hidden, or Tilin's corpse would lie next to the character's.
		if (!body && bodyTries < 35)
		{
			bodyTries++;
			double best = 1e9;
			let it = BlockThingsIterator.Create(self, 96);
			while (it.Next())
			{
				let pp = PlayerPawn(it.thing);
				if (!pp || pp.health > 0 || (pp.player && pp.player.mo == pp)) continue;
				double d = Distance2D(pp);
				if (d < best) { best = d; body = pp; }
			}
		}
		int tnt1 = GetSpriteIndex('TNT1');
		if (body && body.sprite != tnt1) body.sprite = tnt1;
	}
}

// The picture of a player's weapon over their head (see UpdateWeaponIcons). No body of its own;
// the handler moves it with the player every tic.
class TPVC_WeaponIcon : Actor
{
	Default
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+NOGRAVITY
		+DONTSPLASH
		+NOTONAUTOMAP
		+NOTELEPORT
		+NOTARGET
		+BRIGHT
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}
}

// Never spawned. Lists sprite names that only exist in this add-on (Ella's turned frames and the
// weapon icons in TEXTURES, Beta Tilin in sprites/), so the engine knows them.
class TPVC_SpriteNames : Actor
{
	States
	{
	Spawn:
		TPEL ABC -1;
		TPBT ABCDEFGHIJK -1;
		TPWI ABCDEFGHIJKLMNOPQRS -1;
		Stop;
	}
}

// Held by players dressed as Ella: the add-on's SBARINFO then draws Ella's face in their HUD.
// Does nothing else; the handler gives and takes it every tic as characters change.
class TPVC_EllaFace : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.UNCLEARABLE
	}
}

// Self-test prop.
class TPVC_Dummy : Actor
{
	Default
	{
		Health 10;
		Radius 1;
		Height 1;
		+SHOOTABLE
		+NOBLOOD
		+NOGRAVITY
		+NOBLOCKMAP
		+DONTSPLASH
		+NOTONAUTOMAP
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	Death:
		TNT1 A 1;
		Stop;
	}
}

// A travelling guest's body for the moment a map loads (see TPVC_Handler.PlayerSpawned). The
// engine replaces it with the guest's real body and deletes it before the map's first tic.
class TPVC_TravelStandIn : PlayerPawn
{
	Default
	{
		+NOBLOCKMAP
		+NOSECTOR
		+NOINTERACTION
		+INVISIBLE
		-SOLID
		-SHOOTABLE
		-PICKUP
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	}
}

// Self-test prop: an inert "monster" for the scripted-wave check.
class TPVC_TestFoe : Actor
{
	Default
	{
		Monster;
		Radius 4;
		Height 8;
		-SOLID
		+NOGRAVITY
		+NOTONAUTOMAP
		+NEVERTARGET
	}
	States
	{
	Spawn:
		TNT1 A -1;
		Stop;
	Missile:
		TNT1 A -1;
		Stop;
	}
}
