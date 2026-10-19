# The Pink Valley: tag-along co-op (unofficial add-on)

Play The Pink Valley with up to 3 friends (4 players). Player 1 (the host) plays the game
exactly as in single player and is the only one who triggers story events. Everyone else is
another Tilin who tags along: they move, fight, open doors and pick up supplies. An optional enemy
multiplier adds more enemies so the fights hold up with more people.

This is a fan add-on, not part of the mod. It doesn't replace or include any of Vamvilodon's
files, so it only works on top of his `THE_PINK_VALLEY - ENG.pk3`. In single player it does
nothing.

## What everyone needs

- **UZDoom 5.0.3** (recommended) or GZDoom **4.14.2**: everyone on the same engine and the same version
- the same IWAD as everyone else: `DOOM2.WAD`, or `freedoom2.wad` if your group uses Freedoom.
  It has to be the exact same file for everyone, or UZDoom won't let you join
- `THE_PINK_VALLEY - ENG.pk3` (version 1.1, from ModDB)
- this whole `TPV co-op` folder (keep the `launcher` folder next to the .bat files)
- to play over the internet: everyone in the same **Radmin VPN** network (free), or Tailscale /
  ZeroTier. Or the host forwards **UDP port 5029** on their router, and then friends need nothing.

Unzip the folder anywhere, for example into your UZDoom folder. The first time you run one of
the .bat files it finds UZDoom, the IWAD and the Pink Valley pk3 by itself (next to the folder,
in the folder above it, on your desktop or in Downloads). If it can't, a window opens so you can
point at them, and it remembers them after that.

## How to play

1. The host runs **Host co-op.bat**. It shows the address your friends need and copies it, so you
   can paste it to them in Discord. Then pick New game or Continue, the difficulty and your character.
2. Each friend runs **Join co-op.bat**. The first time, type the host's name and address; after that
   just pick them from the list (it remembers everyone you've joined).
3. On UZDoom the host's waiting window lists everyone who has joined. When everyone's there, the
   host clicks **Start Game**. Any number from 2 to 4 works, and the enemy multiplier matches
   however many of you there are. (On GZDoom the host types the number of players instead and
   the game starts when that many have joined.)

Nobody can join a game that has already started, so start together. If someone drops out,
save, and start again with **Continue**.

To try it alone, run **Try it on this PC (two windows).bat**. It opens a host window and a
friend window on the same computer. Only the window you click into gets your keyboard.

If something goes wrong, the window stays open and says what happened. The same text is saved
in `launcher\last-run.txt`: send a screenshot or that file to whoever gave you the co-op files.

## Updates

Every time you run one of the .bat files it checks for a newer version and installs it before the
game starts, so everyone who plays together always has the same files. Each launcher shows a
**files code**: if a friend can't join, compare codes. If they differ, run the .bat again with
the internet on. New versions are posted at https://github.com/charliee1w/tpv-coop/releases.

## Pick your character

Everyone, the host too, can pick who they look like to everyone else: Tilin, Beta Tilin,
Ella, Frida, a civilian (man, woman, boy or girl), Paco, Paca, Riot Paco, Perro Paco, ODIO,
Bipedo, Bipeda, Cuadrupedo, the Oppressive or Love Machine.

- The host and join .bat files ask for it. Press Enter to keep the one you had last time.
- In game: **Options > Pink Valley co-op > Your character**. It changes right away.
- Console: `tpvc_character ella` (or `betatilin`, `paco`, `lovemachine`, and so on).

Want to add your own character? See
[CHARACTERS.md](https://github.com/charliee1w/tpv-coop/blob/main/CHARACTERS.md).

It only changes how you look. You still play as Tilin, with the same speed, weapons, sounds
and size, and you still see your own hands and HUD. The others see the character walk,
attack, flinch and die with the mod's own sprites. Ella's sprites in the mod only face one
way, so the add-on turns her turning-around frames into proper rotations; she has no
walking animation, so she bobs as she walks. Beta Tilin is Tilin in a green hoodie, with his
own walk, aim and BANG! frames. He has no hurt or death sprites, so the add-on makes him flash
red when he's hit and fall over when he dies.

Pick Ella and your own HUD shows Ella's face instead of Tilin's (TURI's faces from Ella Over
Tilin). Everyone else keeps Tilin's face.

## What the tag-along player can and can't do

- **Can:** walk, run and fight with the same weapons the host has, including the Pib ticket.
- **Can open doors:** the mod's house doors, including locked ones once the host has that
  key (key cards are copied to everyone). Doors that also start a scene, change the music or
  autosave are left to the host.
- **Can't:** press switches, cross trigger lines or kick off scripted events. Their kills
  still count: if they kill something whose death starts a script, it runs as if the host
  got the kill.
- **Picks up health, armor and ammo, and it's shared.** Whatever anyone picks up, or a
  script gives the host, everyone gets too, so nobody runs dry. Keys, key boxes, weapons,
  Monono and story items are left for the host; weapons the host gets are copied to everyone.
- **HUD:** it hides in story scenes when the host's does, and comes back the way it does in
  single player: when you get hurt or attack.
- **The Pib ticket machines** at the bus stops always check the host's ticket, so the
  host's swipe works no matter who the machine noticed first.
- **Follows the host.** When a script or teleporter moves the host, everyone comes along.
  Fades, slow walks and no-jump sections happen to everyone.
- **Press J** to warp to the host. If the host presses J, it pulls everyone to them.
- **Respawning:** if someone dies, pressing Use brings them back next to the other player
  instead of at the start of the map.

## Enemy multiplier

The host picks how many of each enemy there are: 1 is normal, 2 is double, and 1.5 works
too. The default is one per player, counting everyone who actually joined. Extra enemies appear next to the originals, with
the same facing and settings.

- **Enemies the maps place** get copies when a map starts.
- **Scripted waves** get copies too. These are groups of enemies that a script spawns under
  one shared tag, like Un bacio's waves. The copies join the group, so the script waits for
  them to die like the rest of the wave.
- **Never copied:** bosses (Sirena, the Oppressive, Corroded Monono, Dinocorydontosaurus,
  Idola), story enemies (Matriarca, Juzgador, Big, the Dinoclowns T-Rexes), civilians, and
  any enemy a script handles one by one (a tag of its own or a special). This keeps scripted
  scenes working the way Vamvilodon wrote them.
- If there's no room next to an enemy, it doesn't get a copy. As a safety limit, a map never
  gets more than 400 extra wave enemies.

Some maps have few enemies the multiplier can copy, because most of their fights are
scripted story scenes. Bosses keep their normal health.

## Saving and loading

Anyone can save during co-op, and every player gets a copy of the save. To continue later, the
host picks **Continue** in Host co-op.bat and chooses the save from the list (newest first). On
UZDoom everyone who joins loads the same save automatically. On GZDoom, friends answer "y" when
Join co-op.bat asks and pick the same save. You can't load from the menu during a net game.

## Host settings (console, ~)

- `tpvc_follow 0/1`: pull friends along when the host gets teleported (default 1)
- `tpvc_startmap <map>`: map a new co-op game starts on (default A_NEW_DAY). The host .bat
  asks for it.
- `tpvc_enemymult <n>`: enemy multiplier, 1 to 8, or 0 for one per player (the host .bat asks
  for it). It takes effect the next time a map starts.
- `tpvc_debug 0/1`: print what the add-on does to the console

## Known limits

- Story text that scripts print on screen (about 15 places, such as the endings) only
  appears on the host's screen.
- The guests' screens fade and freeze with the host, but their view isn't turned for them
  in cutscenes.
- In very small rooms there may not be a free spot for every friend. The ones without a spot
  share the host's spot until they walk away (players pass through each other).
- If the host dies, they respawn next to a friend instead of having to reload. Load a save
  if a scripted sequence gets confused.
- The Un bacio scene that waits for your health to drop to 30 only counts the host's health.
- Some characters are much bigger or smaller than Tilin (Love Machine, Cuadrupedo, the kids).
  Only the picture changes: everyone still takes up Tilin's space and gets hit like Tilin.
- GZDoom starts every net game on Doom 2's MAP01. The add-on moves everyone to the mod's
  first map right away, and gives MAP01 a level group with no Doom 2 story text so that
  screen doesn't show. Nothing in single player goes to MAP01.
- The host .bat turns on `sv_noplayerclip` (players walk through each other) and
  `alwaysapplydmflags`, and turns off `sv_weaponstay` (weapons disappear when picked up, like
  single player). GZDoom remembers these settings. They don't change anything in single
  player.
- Built and tested against The Pink Valley 1.1 (English). When Vamvilodon's next update comes
  out, the add-on's weapon list may need updating.
- To show Ella's face, the add-on carries its own copy of the mod's status bar (SBARINFO), the
  same as 1.1's apart from the face. If an update changes the mod's status bar, the add-on's copy
  has to be updated too.

## How it was tested

The add-on was tested in real GZDoom 4.14.2 net games on one PC, with 2 and with 4 players
(a host window plus joined windows), on all 19 maps. On every map a built-in self-test
(`netevent tpvc_selftest`) checked these things:

- line blocking, and a guest opening one of the map's doors
- kill rerouting
- a guest picking up a health bonus, the host getting it too, and a key box left alone
- ammo shared both ways
- the HUD hiding with the host's and a guest earning it back
- key cards copied to guests
- the Pib ticket machine checking the host
- weapon, ammo, speed and fade mirroring
- following teleports
- the pain frame
- weapon loss
- guest respawn
- host respawn
- the host keeping its scripted speed after a respawn
- with more than one friend: every friend landing next to the host on their own spot
- with the enemy multiplier: map copies, and a scripted wave growing under its tag
- characters: every character's frames exist, a guest dressed as Ella is drawn
  where they stand and gets Ella's HUD face, the costume stays on the corpse and plays the
  death, and switching back to Tilin shows Tilin again

Every check passed on every map, with no desyncs, on GZDoom 4.14.2 and on UZDoom 5.0.3. A co-op
save was also made, then loaded into a new two-player session, and every check passed there too.
It has been played over Radmin VPN, but nobody has played the whole story in co-op yet.

## Files

- `TPV_TagAlong_Coop.pk3`: the add-on (load it after the Pink Valley pk3)
- `Host co-op.bat`, `Join co-op.bat`, `Try it on this PC (two windows).bat`: start here
- `launcher/`: what the .bat files run. `launcher/settings.json` keeps your friends list, your
  character and where your game files are; delete it to start over.
- Source: https://github.com/charliee1w/tpv-coop

The Pink Valley is by Vamvilodon; all credit for the game goes to him. Ella's HUD faces are by
TURI (from Ella Over Tilin). This co-op add-on is an unofficial fan project by gore.
