# Adding your own character

In co-op, every player can pick what the others see them as: Tilin, Beta Tilin, Ella, Paco and so
on. This guide shows how a new character gets added, the same way Beta Tilin was.

A character only changes how you look to the other players. You still play as Tilin, with Tilin's
size, speed and weapons, and you still see your own hands and HUD.

There are two ways to do it:

- **Easy:** draw the pictures and send them to gore. He adds the character and it comes in the
  next update for everyone. You only need **Part 1**.
- **Yourself:** add the character to the add-on's source and try it on your own PC. That's
  **Part 2**.

Either way, you can only use a new character online once it's in an official update. Everyone in
a game needs exactly the same add-on file, or UZDoom won't let them join.

## Part 1: the pictures

A character can have up to five kinds of pictures. Only the first is needed. Anything that's
missing shows the standing picture instead.

| What | When it shows | How many pictures |
|---|---|---|
| Standing | not moving | 1 (more makes an idle animation) |
| Walking | moving | usually 4 |
| Attacking | firing | 1, plus an optional 2nd that shows while the gun goes off (Beta Tilin's BANG!). The 2nd one is drawn lit up. |
| Hurt | getting hit | 1 or more |
| Dying | dying | a few, played once over about a second. The last one stays as the body. |

Rules:

- **PNG with a transparent background.**
- **Feet at the bottom of the picture.**
- **Size:** Tilin is 56 units tall. A picture 56 pixels tall shows at Tilin's height. Bigger
  pictures are fine; they just get shrunk (112 pixels tall: half size).
- **Angles:** each picture can be drawn once and used from every side, or from 5 angles:
  front, front diagonal, side, back diagonal and back. Draw the side and the diagonals facing the
  **left** of the picture. The game mirrors them for the other side.

Beta Tilin (drawn by TURI) is a full example: 4 walking frames from 5 angles, an attack, a
BANG! frame and a 4-frame death.
See the pictures in [src/sprites](https://github.com/charliee1w/tpv-coop/tree/main/src/sprites).

**If you're sending them to gore, you're done.** Give the files names that say what they are (for
example `walk1_front.png`, `walk1_side.png`, `attack.png`, `dead.png`), zip them and send them.
If someone else drew them, say who, so they get credit. If there's no hurt picture, gore can make
one like Beta Tilin's (a red flash when hit).

## Part 2: adding it yourself

You need:

- the add-on's source: on [the GitHub page](https://github.com/charliee1w/tpv-coop) click
  **Code**, then **Download ZIP**, and unzip it
- [SLADE](https://slade.mancubus.net/) (free) to set where the feet are
- optional: Python, to build the add-on with one command

### 1. Name the files

Every picture gets a Doom sprite name: **4-character name + frame letter + angle**.

- **Name:** 4 letters or numbers that nothing else uses. Start it with `TP` so it can't clash with
  the mod. The add-on already uses `TPEL` and `TPBT`. This guide uses `TPWF` as the example.
- **Frame letter:** one letter per picture: A, B, C and so on. For example A to D for walking,
  E for the attack, F for the gun going off, G for hurt, H to J for dying. Standing is usually A,
  the first walking frame.
- **Angle:** `0` if one picture is used from every side. Otherwise `1` front, `2` front diagonal,
  `3` side, `4` back diagonal, `5` back. The side and diagonal files also name the side they're
  mirrored to, with the frame letter repeated: `TPWFA2A8` means "frame A, angle 2, and the same
  picture mirrored for angle 8".

So walking frame A from 5 angles is these 5 files:

```
TPWFA1.png  TPWFA2A8.png  TPWFA3A7.png  TPWFA4A6.png  TPWFA5.png
```

Each frame needs either all 5 angles or a single `0` file, never part of a set. Otherwise the game
won't start (see Problems below).

### 2. Set where the feet are

The game needs to know where the feet are in each picture (the "offsets"), or the character floats
or sinks into the floor.

1. In SLADE, use **File > Open Directory** on the folder with your PNGs.
2. Select all the pictures, right-click, and pick **Graphics > Modify Gfx Offsets**.
3. Choose the automatic offsets for a monster: **Monster (GL-friendly)**. Click OK, then save.

This puts the middle of the bottom edge on the floor. For Beta Tilin, on a 41x56 picture, that's
x 20, y 56.

### 3. Copy them in

Put the PNGs in `src/sprites/`.

### 4. Add the character

Open `src/zscript.zs` in a text editor (Notepad works) and find `void BuildCharacters()`. At the
end of its list, after the Beta Tilin line, add one line for your character:

```
		AddCharacter("wolfie|Wolfie|1|TPWF A|TPWF ABCD|TPWF EF|TPWF G|TPWF HIJ");
```

The parts, separated by `|`, are:

1. **id**: lowercase, no spaces. It's what you type after `tpvc_character` in the console.
2. **name**: shown in the menus.
3. **scale**: 1 is the picture's own size, 0.5 is half. Use a dot, not a comma.
4. **standing**
5. **walking**
6. **attacking**: the first letter is the attack, an optional second one is the gun going off.
7. **hurt**
8. **dying**

Each picture part is the sprite name, one space, then the frame letters in order.

- **Never leave a part empty.** If there's no hurt or dying picture, repeat the standing one:
  `TPWF A`.
- To use frames from two sprite names, put a comma between them with no spaces:
  `TPWF HI,TPWG AB`.
- **Always add new characters at the end of the list.** Characters are remembered by their
  place in the list.

In the same file, find `class TPVC_SpriteNames` and add a line with your sprite name and every
frame letter you used:

```
		TPWF ABCDEFGHIJ -1;
```

The game only knows sprite names that something uses, and this line is that something.

### 5. Put it in the menus

- `src/menudef.tpvc`: in `OptionString "TPVC_Characters"`, add `"wolfie", "Wolfie"`.
- `launcher/tpv-coop.ps1`: in `$Characters`, add `@('wolfie', 'Wolfie')`.

### 6. Build the add-on file

- **With Python:** open a command window in the source folder and run `python build.py`. It
  makes `TPV_TagAlong_Coop.pk3` from `src/`.
- **Without Python:** open `src`, select everything in it, right-click, and pick
  **Send to > Compressed (zipped) folder**. Rename the zip to `TPV_TagAlong_Coop.pk3`. If you can't
  see the `.zip` ending, turn on **View > File name extensions** in Explorer first. The files must
  sit at the top of the zip, not inside a `src` folder.

### 7. Try it

1. In your TPV co-op folder, open `launcher\settings.json` in Notepad and change
   `"autoUpdate": true` to `"autoUpdate": false`. Otherwise the launcher puts the official add-on
   back every time it starts.
2. Copy your new `TPV_TagAlong_Coop.pk3` over the one in your TPV co-op folder, and your edited
   `tpv-coop.ps1` into its `launcher` folder.
3. Run **Try it on this PC (two windows).bat** and pick your character for the second window.
   From the first window, look at the second player while it stands, walks and shoots.
4. To check that every picture was found, open the console (the `~` key) in the first window and
   type `netevent tpvc_selftest`. Look for **every character frame exists**. The test moves and
   kills players to check other things, so only run it in the Try windows.

In a game you can also switch characters in the console: `tpvc_character wolfie`.

### 8. Get it to everyone

Send gore your PNGs from `src/sprites/` and your `AddCharacter` line, or open a pull request on
GitHub. Once it's in an update, set `"autoUpdate"` back to `true`. The launcher installs the update,
and everyone has your character.

## Problems

- **The game won't start: "Sprite TPWF frame B is missing rotations".** A frame has some angles but
  not all 5, or a mirrored name is wrong. The frame letter must repeat: `TPWFB2B8`, not `TPWFB2A8`.
- **The character floats or sinks into the floor.** The offsets aren't set (step 2).
- **You still look like Tilin.** Check that:
  - the sprite name is in `TPVC_SpriteNames`
  - the sprite name is exactly 4 characters
  - no part of the `AddCharacter` line is empty
  - there's no space after a comma
- **Friends can't join and it stays on "Contacting host".** Your add-on file is different from
  theirs. Compare the files code both launchers show.
