# ytosc: a YouTube-style controller for mpv

ytosc replaces mpv's plain built-in controller (the "OSC", the bar with play/pause and the seek line) with a modern one that looks and behaves like YouTube's player. It follows your wallpaper colors through **matugen**, can be driven almost entirely from the keyboard with **vim-style keys**, and understands **Hyprland**.

This document is meant to be everything you need. You do not have to read any code.

---

## Contents

1. [What you get](#1-what-you-get)
2. [Requirements](#2-requirements)
3. [Install in 5 minutes](#3-install-in-5-minutes)
4. [A tour of the screen](#4-a-tour-of-the-screen)
5. [Using the mouse](#5-using-the-mouse)
6. [Using the keyboard](#6-using-the-keyboard)
7. [Menus and panels explained](#7-menus-and-panels-explained)
8. [Opening files, folders and links](#8-opening-files-folders-and-links)
9. [The `:` command line](#9-the--command-line)
10. [View modes: theater and miniplayer (Hyprland)](#10-view-modes-theater-and-miniplayer-hyprland)
11. [Colors and matugen](#11-colors-and-matugen)
12. [Seekbar previews with thumbfast](#12-seekbar-previews-with-thumbfast)
13. [Settings reference](#13-settings-reference)
14. [Changing the keys](#14-changing-the-keys)
15. [Controlling ytosc from scripts](#15-controlling-ytosc-from-scripts)
16. [What each file does](#16-what-each-file-does)
17. [How it works, in plain words](#17-how-it-works-in-plain-words)
18. [Troubleshooting](#18-troubleshooting)
19. [Known limitations and what was tested](#19-known-limitations-and-what-was-tested)
20. [Updating and uninstalling](#20-updating-and-uninstalling)
21. [Credits and licenses](#21-credits-and-licenses)

---

## 1. What you get

- **YouTube-style controls**: thin seekbar that grows when you hover it, chapter gaps, a buffered (cached) section, a scrubber dot, a time bubble with the chapter name, a volume slider that slides out, auto-hiding controls with smooth fades.
- **Settings menu** (the gear): playback speed, subtitles/captions, audio track, video track, aspect ratio, loop, chapters. Nested pages with a back arrow, like YouTube.
- **Caption options**: font, size, color, background opacity, edge style, position, delay.
- **Playlist panel** ("Up next" style): play, remove, reorder, filter.
- **More videos strip**: a row of cards above the seekbar with thumbnails from your playlist, the rest of the folder, and recent files.
- **Open anything**: file, folder (as a playlist), URL, clipboard, recent files.
- **Vim-style keys** with counts (`5l` = forward 25 s), chords (`gg`, `ZZ`), time marks (`ma`, `'a`) and undo/redo for seeking. Every key can be changed.
- **`:` command line** for typing commands such as `seek 1:30`.
- **Theater mode and miniplayer** on Hyprland.
- **Themeable** with matugen. Colors reload automatically within about a second, in every open mpv window.
- **Borderless-window support**: a top bar with minimize/maximize/close buttons when mpv has no border.
- **Idle screen** with an Open button when nothing is playing.

---

## 2. Requirements

| Thing | Needed? | Why |
|---|---|---|
| **mpv 0.37 or newer** | Required | Runs the script. Check with `mpv --version`. |
| **ffmpeg** | Optional | Makes the thumbnails on the "More videos" cards. Without it the cards show text only. |
| **thumbfast** | Optional | Shows a small video preview when you hover the seekbar. See [section 12](#12-seekbar-previews-with-thumbfast). |
| **zenity** (or kdialog, or yad) | Optional | The file and folder chooser windows. Without one, ytosc asks you to type the path instead. |
| **wl-clipboard** (Wayland) or **xclip** (X11) | Optional | Lets "Paste and play" read your clipboard on mpv older than 0.39. |
| **Hyprland** | Optional | Needed for theater mode and the docked miniplayer. |
| **matugen** | Optional | Colors that follow your wallpaper. Without it you get a YouTube-dark theme. |

On Arch Linux:

```sh
sudo pacman -S mpv ffmpeg zenity wl-clipboard
```

---

## 3. Install in 5 minutes

### Step 1: put the files in place

You received a zip containing a folder named `ytosc`. Inside it is `scripts/ytosc/`. That inner folder is the script. Copy it into mpv's scripts folder:

```sh
unzip ytosc-final.zip
mkdir -p ~/.config/mpv/scripts
cp -r ytosc/scripts/ytosc ~/.config/mpv/scripts/
```

Afterwards this file must exist:

```
~/.config/mpv/scripts/ytosc/main.lua
```

(The folder name has to be exactly `ytosc`, and `main.lua` has to sit directly inside it.)

### Step 2: switch off mpv's own controller

Open (or create) `~/.config/mpv/mpv.conf` and add:

```ini
osc=no
osd-bar=no
```

If you want a borderless window (recommended with ytosc, because it draws its own title bar buttons), also add:

```ini
border=no
```

### Step 3: start mpv

```sh
mpv some-video.mkv
```

Move the mouse and the controller appears. That is all that is required. Everything else in this document is optional customization.

### Step 4 (optional): create the settings files

ytosc works without any settings files. If you want to change something, create the files below. They live in `~/.config/mpv/script-opts/`. Create that folder if it does not exist: `mkdir -p ~/.config/mpv/script-opts`.

**`ytosc.conf`** (general settings; every line is optional, the values shown are the defaults):

```ini
scale=1
hide_timeout=2
hide_when_paused=no
scrub_mode=live
double_click_seek=10
wheel_seek=5
volume_step=5
font=sans-serif
scrim_alpha=0.7
panel_alpha=0.92
window_controls=auto
touch_mode=no
timeoutlen=600
keymap=vim
media_extensions=mkv,mp4,avi,mov,webm,m4v,flv,wmv,ts,m2ts,mpg,mpeg,ogv,3gp,mp3,flac,ogg,opus,m4a,wav,aac,wma,mka
recursive_dir=no
autoload_dir=yes
picker_file=
picker_dir=
thumbnails=auto
strip_thumbnails=yes
strip_sources=playlist,dir,recent
mini_size=480x270
mini_corner=bottom-right
mini_margin=20
debug=no
```

**`ytosc-colors.conf`** (the color palette; matugen rewrites this file for you, see [section 11](#11-colors-and-matugen)):

```ini
primary=ff0000
on_primary=ffffff
surface=212121
surface_container=3d3d3d
on_surface=ffffff
on_surface_variant=aaaaaa
surface_variant=4d4d4d
outline=717171
error=ff6b6b
scrim=000000
```

**`ytosc-keys.conf`** (your own key changes, see [section 14](#14-changing-the-keys)). Start with an empty file or with comments only.

---

## 4. A tour of the screen

Move the mouse over the video to show the controller. It fades out after 2 seconds of stillness (it stays while the video is paused, while you hover it, and while a menu is open).

```
+--------------------------------------------------------------+
| Video title                              2/12   -   []   X   |  top bar
|                                                              |
|                                                              |
|                          (video)                             |
|                                                              |
|   [card] [card] [card]        <- More videos strip (key v)   |
| =========o==================================================  |  seekbar
| Pause Next Vol  0:10/1:40 . Chapter   ^ More videos   Open List View CC Gear Full |
+--------------------------------------------------------------+
```

**Top bar** (appears with the controls): the video title, your position in the playlist (`2/12`), and, only when the window has no border, minimize / maximize / close buttons.

**Seekbar**: the red part is what you have watched, the lighter part is already loaded (cached), and the thin gaps are chapter boundaries. Hover it and it grows, a dot appears, and a bubble shows the time and chapter name under your cursor. Click or drag to jump.

**Bottom row, left side**

| Control | What it does |
|---|---|
| Pause/Play | Toggles playback |
| Next | Plays the next playlist item (only shown when there is one) |
| Speaker | Click to mute. Hover to slide out the volume slider |
| `0:10 / 1:40` | Elapsed / total. Click to switch to remaining time (`-1:30 / 1:40`) |
| `• Chapter` | Current chapter name. Click to open the chapter list |

**Bottom row, middle**: `More videos` opens the strip of cards (only shown when the window is wide enough).

**Bottom row, right side** (left to right)

| Control | What it does |
|---|---|
| Folder | Open menu (file, folder, URL, clipboard, recent) |
| List | Playlist panel |
| Wide rectangle | View menu (default, theater, miniplayer, fullscreen) |
| CC | Subtitles on/off. Red underline = on. Dimmed = this file has no subtitles |
| Gear | Settings menu (rotates while open) |
| Corners | Fullscreen |

**Idle screen**: when mpv has nothing loaded you see "Nothing playing" and an **Open...** button.

---

## 5. Using the mouse

| Action | Result |
|---|---|
| Click the video | Pause / play |
| Double-click the middle of the video | Fullscreen |
| Double-click the left or right third | Jump back / forward 10 s. A ripple animation plays and repeated double-clicks add up ("20 seconds") |
| Mouse wheel over the video | Volume up/down |
| Mouse wheel over the seekbar | Seek 5 s per notch |
| Click or drag on the seekbar | Jump / scrub (the picture follows live, or only when you let go; see `scrub_mode`) |
| Hover the speaker | Volume slider slides out. Drag it |
| Click outside an open menu or the strip | Closes it (the click is swallowed, so it will not pause the video) |
| Wheel over a menu, panel or the strip | Scrolls it |

---

## 6. Using the keyboard

The keys are inspired by vim. If you have never used vim: just treat the tables as a cheat sheet. Everything the keys do is also available with the mouse.

### 6.1 Counts and chords

- **Counts**: type a number first and the next command repeats. `3l` = three times 5 s forward = 15 s. `2k` = volume up twice. `3J` = skip three playlist items.
- **`N%`**: type a number then `%` to jump there. `50%` = middle of the video.
- **Chords**: some commands are two keys in a row, like `gg` or `ZZ`. You have 600 ms (setting `timeoutlen`) between the keys.
- **Pending keys** show in a small box above the seekbar while ytosc waits for the next key.

### 6.2 Seeking

| Keys | Action |
|---|---|
| `h` / `l` | Back / forward 5 s |
| `H` / `L` | Back / forward 30 s |
| `Ctrl+d` / `Ctrl+u` | Forward / back 60 s |
| `Ctrl+f` / `Ctrl+b` | Forward / back 5 minutes |
| `gg` | Start of the video |
| `G` | Near the end (1 s before) |
| `50%` | Jump to 50 percent (any number) |
| `w` / `b` | Next / previous chapter |
| `,` / `.` | One frame back / forward |
| `m` then a letter (`ma`) | Remember this moment as mark `a` |
| `'` then a letter (`'a`) | Jump to mark `a` |
| `u` / `Ctrl+r` | Undo / redo the last seek (jump back to where you were) |

### 6.3 Playback, sound, subtitles

| Keys | Action |
|---|---|
| `Space` | Pause / play |
| `[` / `]` | Slower / faster by 0.25 |
| `=` | Normal speed |
| `J` / `K` | Next / previous playlist item |
| `k` / `j` | Volume up / down by 5 |
| `M` | Mute / unmute |
| `c` | Subtitles on / off |
| `C` | Next subtitle track |
| `a` | Next audio track |

### 6.4 Windows, menus and the rest

| Keys | Action |
|---|---|
| `f` | Fullscreen |
| `T` | Theater mode (Hyprland) |
| `I` | Miniplayer (Hyprland, with a fallback elsewhere) |
| `s` | Settings menu |
| `Tab` | Playlist panel |
| `v` | More videos strip |
| `o` | Open menu |
| `O` | Open a folder directly |
| `p` | Paste (URL or path from the clipboard) and play |
| `P` | Paste and add to the playlist |
| `:` | Command line |
| `t` | Switch between elapsed and remaining time |
| `i` | mpv's statistics overlay |
| `Esc` | Closes the top-most thing (text box, menu, panel, strip), otherwise leaves fullscreen |
| `q` | Quit |
| `ZZ` | Quit and remember the position (mpv's "watch later") |
| `ZQ` | Quit without remembering |

> Keys that are not listed here (for example `Shift+s` for a screenshot) keep their normal mpv behavior. ytosc only takes over the keys in the tables.

### 6.5 Keys while something is open

When a menu, the playlist panel or the strip is open, it takes over a few keys so you can steer it. They go back to normal as soon as it closes.

**Settings / Open / View menu**

| Keys | Action |
|---|---|
| `j` / `k` or Down / Up | Move the highlight |
| `g` / `G` | First / last item |
| `Enter`, `l`, Right, `Space` | Choose / go deeper |
| `h`, Left, Backspace | Go back one page |
| `Esc` or `s` | Close |

**Playlist panel**

| Keys | Action |
|---|---|
| `j` / `k` or Down / Up | Move the highlight |
| `g` / `G` | First / last |
| `Enter`, `l`, `Space` | Play the highlighted entry |
| `d` `d` (twice quickly) | Remove the entry from the playlist |
| `Alt+j` / `Alt+k` | Move the entry down / up |
| `/` | Filter by typing (see section 7.3) |
| `Esc` | Clears the filter; pressing it again closes the panel |

**More videos strip**

| Keys | Action |
|---|---|
| `h` / `l` or Left / Right | Move between cards |
| `g` / `G` | First / last card |
| `Enter` or `Space` | Play the card |
| `Esc` or `v` | Close |

**Text box** (used by Custom speed, URL entry, filter, command line)

| Keys | Action |
|---|---|
| Typing | Adds text |
| Backspace / Delete | Delete a character |
| Left / Right / Home / End | Move the cursor |
| `Ctrl+w` | Delete the previous word |
| `Ctrl+u` | Delete everything before the cursor |
| `Ctrl+v` | Paste (needs mpv 0.39 or newer) |
| `Enter` | Confirm |
| `Esc` | Cancel |

While a text box is open, all your typing goes into it, even keys that normally do something (`j`, `k`, `s`...).

---

## 7. Menus and panels explained

### 7.1 Settings menu (gear, or `s`)

| Entry | What is inside |
|---|---|
| **Playback speed** | 0.25x to 3x, plus **Custom...** where you type any speed (up to 100) |
| **Subtitles/CC** | Off, one entry per subtitle track, and **Options** (below) |
| **Audio** | Off, one entry per audio track, and **Delay** (+/- 100 ms steps, Reset) |
| **Video** | One entry per video track (shown as `1920x1080 24fps`) |
| **Aspect ratio** | Default, 16:9, 4:3, 21:9, 1:1 |
| **Loop** | None, Loop file, Loop playlist |
| **Chapters** | Only shown when the file has chapters. Pick one to jump there |

Choosing an option takes you back one page, like YouTube. The current choice has a check mark.

### 7.2 Caption options (Settings, Subtitles/CC, Options)

| Entry | Choices |
|---|---|
| **Font** | Sans, Serif, Monospace |
| **Font size** | Tiny, Small, Medium, Large, Huge |
| **Text color** | White, Yellow, Green, Cyan, Blue, Magenta, Red, Black |
| **Background opacity** | 0%, 25%, 50%, 75%, 100% (any value above 0% draws a box behind the text) |
| **Edge style** | None, Outline, Drop shadow |
| **Position** | Bottom, Raised, Higher, Middle, Top |
| **Delay** | +/- 100 ms steps, Reset (use it when subtitles are out of sync) |
| **Override embedded styling** | On = your choices win even over fancy styled subtitles |
| **Reset to defaults** | Puts everything back |

> Some subtitle files (typically anime with styled ASS subtitles) carry their own fonts, colors and positions. Those ignore most options until you switch **Override embedded styling** on.

### 7.3 Playlist panel (list icon, or `Tab`)

A panel on the right side. The playing entry has a small play arrow and bold text. Header buttons:

- **Open**: the Open menu.
- **Shuffle**: shuffles the playlist once.
- **Loop**: toggles looping the whole playlist (highlighted when on).
- **x**: closes the panel.

Type `/` to filter: you type part of a name and the list narrows as you type. `Enter` keeps the filter, `Esc` clears it. Reordering is switched off while a filter is active.

### 7.4 More videos strip (`v` or the "More videos" button)

A row of cards above the seekbar. Cards are built in this order (set by `strip_sources`):

1. The other items in your current playlist, starting after the one playing.
2. If the playlist has only one item: the other media files in the same folder (this is how you get an "Up next" feel without building a playlist).
3. Recently played files.

Each card shows a thumbnail (a frame from the video, generated by ffmpeg and cached on disk), the name, and where it came from ("In playlist", "In folder", "Recent"). Click a card, or move with `h`/`l` and press `Enter`. Arrow buttons appear on the sides when there are more cards than fit.

Thumbnails are stored in mpv's cache folder (normally `~/.cache/mpv/ytosc/thumbs/`). You can delete that folder at any time; they will be rebuilt.

### 7.5 View menu (wide-rectangle icon)

Default view, Theater mode, Miniplayer, Fullscreen. See [section 10](#10-view-modes-theater-and-miniplayer-hyprland).

---

## 8. Opening files, folders and links

Open the **Open menu** with the folder icon, `o`, or the Open button on the idle screen.

| Entry | What it does |
|---|---|
| **Open file...** | A file chooser window; you can select several files |
| **Open folder...** | Plays all media files in the folder as a playlist |
| **Open URL...** | Type or paste a link or path |
| **Paste and play** | Uses whatever is in your clipboard |
| **Add file / folder / URL to playlist...** | Same, but appends instead of replacing |
| **Recent files** | Your last 20 distinct files, newest first |

How folders and files are handled:

- Files in a folder are sorted **naturally**: `ep1, ep2, ep10` (not `ep1, ep10, ep2`).
- Only media files are used (see `media_extensions`). Subfolders are ignored unless `recursive_dir=yes`.
- **Open one file and the rest of its folder becomes the playlist**, and playback starts at the file you chose. Switch this off with `autoload_dir=no`.
- URLs are passed to mpv unchanged (mpv uses yt-dlp for sites that need it).

File chooser windows: ytosc looks for **zenity**, then **kdialog**, then **yad**. You can use your own with `picker_file` / `picker_dir`: any command that prints one path per line and exits with 0 when you pick something. With none available, ytosc shows a text box where you type the path.

Recent files are stored in `~/.local/state/mpv/ytosc-history` (a plain text file, one path per line). Delete it to clear the list.

---

## 9. The `:` command line

Press `:`, type, press `Enter`. `Esc` cancels.

| You type | Result |
|---|---|
| `seek 1:30` (also `s 1:30`) | Jump to 1 minute 30 seconds. Also `1:02:03` or plain seconds `90` |
| `seek +10` / `seek -1:00` | Jump forward 10 s / back 1 minute |
| `seek 50%` | Jump to the middle |
| `speed 1.5` | Playback speed |
| `vol 70` (or `volume 70`) | Volume |
| `chapter 3` | Go to chapter 3 |
| `open <path or URL>` (or `e`) | Open (replaces the playlist) |
| `append <path or URL>` | Add to the playlist |
| `q` / `quit` | Quit |
| `wq` | Quit and remember the position |
| anything else | Passed straight to mpv as a command, for example `set speed 2`, `add volume 5`, `cycle pause`, `show-text hello`, `sub-add /path/file.srt` |

If mpv does not understand the text you get an "Unknown command" message at the top.

---

## 10. View modes: theater and miniplayer (Hyprland)

Open the view menu (wide-rectangle icon) or use `T` and `I`. Pressing the same key again goes back.

| Mode | What it does |
|---|---|
| **Default** | The window as it normally is |
| **Theater** | Maximizes the window using Hyprland's "maximize" (bars stay visible). This is the closest thing to YouTube's theater mode. |
| **Fullscreen** | Real fullscreen (`f`) |
| **Miniplayer** | The window becomes small, floating and **pinned** (stays on every workspace), docked in a screen corner, with a compact control layout |

**Miniplayer layout**: a thin seekbar at the bottom, a play/pause button, and two buttons in the top-right: **expand** (back to normal) and **close**. Any window narrower than 420 pixels uses this compact layout too.

**Miniplayer settings** (in `ytosc.conf`):

```ini
mini_size=480x270          # width x height in pixels
mini_corner=bottom-right   # top-left, top-right, bottom-left or bottom-right
mini_margin=20             # gap to the screen edge
```

(Do not put the `#` comments on the same line in the real file; mpv settings files do not allow that. They are shown here only to explain the values.)

**Leaving the miniplayer** puts the window back exactly as it was: if it was tiled it is tiled again, if it was floating it gets its old size and position back, and it is unpinned.

**Several mpv windows**: each mpv finds its own window by its process id, so the commands never act on whichever window happens to have focus.

**Without Hyprland**: theater mode shows "Theater mode needs Hyprland". The miniplayer falls back to making the window always-on-top and smaller (it does not move it).

**Behind the scenes** ytosc runs `hyprctl clients -j` and `hyprctl monitors -j` to find your window and screen, then sends one `hyprctl --batch` line with `dispatch focuswindow`, `setfloating`, `pin`, `resizewindowpixel` and `movewindowpixel`. Hyprland's command names and arguments change slightly between versions. If the miniplayer misbehaves, run `hyprctl version` and `hyprctl clients -j` and check those commands by hand.

---

## 11. Colors and matugen

### 11.1 How colors work

ytosc reads its colors from one small text file:

```
~/.config/mpv/script-opts/ytosc-colors.conf
```

Each line is `name=RRGGBB` (a `#` in front is also accepted). Missing lines fall back to the built-in YouTube-dark palette one by one, so a partial file is fine.

ytosc **checks the file once a second**. When it changes, the colors fade to the new palette over a third of a second, in **every open mpv window**. No restart needed.

### 11.2 What each color is for

These names follow Material 3 (the system matugen produces).

| Name | Used for |
|---|---|
| `primary` | Watched part of the seekbar, the scrubber dot, the CC underline, selection outlines on cards, the current playlist arrow, active buttons (Loop), the text caret |
| `on_primary` | Text on top of `primary` (for example on the Open... button) |
| `surface` | Menus, panels, card captions, the time bubble, popups |
| `surface_container` | Highlighted or hovered menu rows, inactive header buttons |
| `on_surface` | Icons and main text |
| `on_surface_variant` | Secondary text (chapter name, counts, hints) |
| `surface_variant` | The empty part of the seekbar (the track) |
| `outline` | The loaded/cached part of the seekbar |
| `error` | The red hover color of the window close button |
| `scrim` | The dark gradient behind the controls (usually black) |

Transparency is not part of the colors file. It comes from the settings `scrim_alpha` (gradient strength) and `panel_alpha` (menus).

### 11.3 Connecting matugen

**Step 1.** Create the template file `~/.config/matugen/templates/ytosc-colors.conf` with exactly this content:

```
primary={{colors.primary.default.hex_stripped}}
on_primary={{colors.on_primary.default.hex_stripped}}
surface={{colors.surface.default.hex_stripped}}
surface_container={{colors.surface_container.default.hex_stripped}}
on_surface={{colors.on_surface.default.hex_stripped}}
on_surface_variant={{colors.on_surface_variant.default.hex_stripped}}
surface_variant={{colors.surface_variant.default.hex_stripped}}
outline={{colors.outline.default.hex_stripped}}
error={{colors.error.default.hex_stripped}}
```

**Step 2.** Add this to `~/.config/matugen/config.toml`:

```toml
[templates.ytosc]
input_path = '~/.config/matugen/templates/ytosc-colors.conf'
output_path = '~/.config/mpv/script-opts/ytosc-colors.conf'
```

**Step 3.** Generate colors as you normally do, for example `matugen image ~/Pictures/wallpaper.png`. matugen writes the file, and open mpv windows recolor within a second.

> The `{{colors...}}` variable names above are the ones used by matugen 2.x. Other versions can name them slightly differently. If the output file has empty values or the placeholders left in it, check the template syntax in your matugen version's documentation. The result you need is a file with lines like `primary=1a73e8`.

> If the colors file is empty or has no valid lines, ytosc keeps the previous colors and does not reset. The `scrim` color is not in the template, so it stays black; add a `scrim=` line to the template if you want it themed.

### 11.4 Choosing colors by hand

Skip matugen and edit `ytosc-colors.conf` yourself. For a green accent:

```ini
primary=1db954
on_primary=000000
```

### 11.5 Contrast warning

If the text color and the surface color are too similar to read comfortably, ytosc writes a warning to mpv's log. Run `mpv --msg-level=ytosc=warn file.mkv` to see it.

---

## 12. Seekbar previews with thumbfast

When you hover or drag on the seekbar, ytosc can show a small preview picture of that moment. That picture is produced by a separate mpv script called **thumbfast**; ytosc only asks it to show the picture.

1. Download `thumbfast.lua` from https://github.com/po5/thumbfast
2. Put it in `~/.config/mpv/scripts/` (next to the `ytosc` folder).
3. Restart mpv.

ytosc detects it automatically. The preview appears above the time bubble. If you do not want it, set `thumbnails=no`. If thumbfast is not installed, nothing breaks; you just get the time bubble.

(The thumbnails on the *More videos* cards are a different thing; those use ffmpeg and the setting `strip_thumbnails`.)

---

## 13. Settings reference

All settings go in `~/.config/mpv/script-opts/ytosc.conf`, one `name=value` per line, with nothing after the value. Yes/no values are written `yes` or `no`. Changes apply the next time mpv starts.

### Looks and behavior

| Setting | Default | What it does |
|---|---|---|
| `scale` | `1` | Makes the whole interface bigger or smaller. `1.25` = 25% bigger. Try `2` on a 4K screen. |
| `hide_timeout` | `2` | Seconds without mouse movement before the controls fade out. |
| `hide_when_paused` | `no` | `no` = controls stay on screen while paused. `yes` = they hide anyway. |
| `scrub_mode` | `live` | `live` = the picture follows while you drag the seekbar. `release` = it jumps only when you let go (gentler on slow files). |
| `double_click_seek` | `10` | Seconds skipped by a double-click on the left/right of the video. |
| `wheel_seek` | `5` | Seconds per mouse-wheel notch over the seekbar. |
| `volume_step` | `5` | Percent per mouse-wheel notch over the video. |
| `font` | `sans-serif` | Font for all text. Any font installed on your system (for example `Roboto`). |
| `scrim_alpha` | `0.7` | Strength of the dark gradient behind the controls, 0 to 1. |
| `panel_alpha` | `0.92` | Opacity of menus and panels, 0 to 1. Lower = more see-through. |
| `window_controls` | `auto` | Minimize/maximize/close buttons in the top bar. `auto` = only when `border=no` and not fullscreen. `yes` = always. `no` = never. |
| `touch_mode` | `no` | `yes` = larger buttons for touchscreens. |
| `debug` | `no` | `yes` draws red boxes over every clickable area. Useful when something seems unclickable. |

### Keys

| Setting | Default | What it does |
|---|---|---|
| `timeoutlen` | `600` | Milliseconds ytosc waits for the second key of a chord like `gg`. |
| `keymap` | `vim` | `vim` = the keys in this document. `mpv` = ytosc binds no keys at all, so mpv's normal keys apply (the mouse still works). |

### Opening media

| Setting | Default | What it does |
|---|---|---|
| `media_extensions` | long list | Comma-separated file types treated as media when scanning folders. |
| `recursive_dir` | `no` | `yes` = "Open folder" also includes subfolders. |
| `autoload_dir` | `yes` | Opening one file loads its whole folder as the playlist. |
| `picker_file` | empty | Your own file chooser command. Empty = auto-detect zenity, kdialog, yad. |
| `picker_dir` | empty | Your own folder chooser command. |

### Previews and strip

| Setting | Default | What it does |
|---|---|---|
| `thumbnails` | `auto` | Seekbar previews through thumbfast. `no` turns them off. |
| `strip_thumbnails` | `yes` | Thumbnails on the More videos cards (needs ffmpeg). `no` = text-only cards. |
| `strip_sources` | `playlist,dir,recent` | Where the cards come from and in what order. Remove words you do not want, for example `playlist,recent`. |

### View modes

| Setting | Default | What it does |
|---|---|---|
| `mini_size` | `480x270` | Miniplayer size in pixels, `WIDTHxHEIGHT`. |
| `mini_corner` | `bottom-right` | `top-left`, `top-right`, `bottom-left` or `bottom-right`. |
| `mini_margin` | `20` | Distance from the screen edge in pixels. |

### mpv's own settings that matter here

| Setting (in `mpv.conf`) | Why |
|---|---|
| `osc=no` | Required. Otherwise two controllers show at once. |
| `osd-bar=no` | Required. Hides mpv's own volume/seek bars. |
| `border=no` | Optional. A borderless window; ytosc then draws the minimize/maximize/close buttons. |

---

## 14. Changing the keys

Create `~/.config/mpv/script-opts/ytosc-keys.conf`. Each line is:

```
KEY=ACTION
```

- Lines starting with `;` are comments.
- `KEY=none` removes a default key.
- For a two-key chord, write the keys with a space: `g g=goto_start`.
- Key names are mpv's names: letters like `h`, capitals like `H` (Shift+h), `Ctrl+d`, `Alt+j`, `SPACE`, `ENTER`, `ESC`, `TAB`, `UP`, `DOWN`, `LEFT`, `RIGHT`, `BS` (Backspace), and punctuation such as `,` `.` `[` `]` `=` `'` `:` `%`.
- Your lines override the defaults. Restart mpv to apply.

Examples:

```ini
; use Right/Left arrows for seeking
RIGHT=seek_fwd
LEFT=seek_back

; free up the letter c (subtitle toggle) and put it on x
c=none
x=sub_toggle

; open the settings menu with F1
F1=settings_toggle
```

### All actions you can assign

| Action | What it does |
|---|---|
| `seek_back`, `seek_fwd` | 5 s back / forward (counts multiply) |
| `seek_back_big`, `seek_fwd_big` | 30 s back / forward |
| `seek_back_60`, `seek_fwd_60` | 1 minute back / forward |
| `seek_back_300`, `seek_fwd_300` | 5 minutes back / forward |
| `goto_start`, `goto_end` | Start / near the end |
| `jump_percent` | Jump to the percent you typed before (`50%`) |
| `chapter_next`, `chapter_prev` | Next / previous chapter |
| `frame_fwd`, `frame_back` | One frame forward / back |
| `mark_set`, `mark_jump` | Set / jump to a mark (asks for a letter) |
| `undo_seek`, `redo_seek` | Undo / redo the last seek |
| `pause` | Pause / play |
| `speed_down`, `speed_up`, `speed_reset` | Speed -0.25 / +0.25 / back to 1 |
| `playlist_next`, `playlist_prev` | Next / previous playlist item |
| `volume_up`, `volume_down` | Volume +5 / -5 |
| `mute` | Mute / unmute |
| `sub_toggle`, `sub_cycle` | Subtitles on/off / next subtitle track |
| `audio_cycle` | Next audio track |
| `fullscreen` | Fullscreen |
| `escape` | Close the top-most popup, otherwise leave fullscreen |
| `toggle_remaining` | Elapsed / remaining time |
| `stats` | mpv's statistics overlay |
| `settings_toggle` | Settings menu |
| `panel_toggle` | Playlist panel |
| `strip_toggle` | More videos strip |
| `theater_toggle`, `mini_toggle` | Theater mode / miniplayer |
| `command_line` | The `:` command line |
| `open_menu` | The Open menu |
| `open_dir` | The folder chooser (plays the folder) |
| `paste_play`, `paste_append` | Clipboard: play / add to playlist |
| `quit`, `quit_watch_later`, `quit_nosave` | Quit / quit and remember position / quit |

If you write an action name that does not exist, ytosc logs a warning and ignores that line.

Want to use mpv's own keys entirely? Set `keymap=mpv` in `ytosc.conf`.

---

## 15. Controlling ytosc from scripts

Other programs can talk to ytosc through mpv's messages. From inside mpv's own `input.conf` (`~/.config/mpv/input.conf`):

```
Ctrl+o script-message-to ytosc open-dir /home/you/Videos
```

| Message | Argument | Effect |
|---|---|---|
| `open` | a path or URL | Open it (replaces the playlist; follows `autoload_dir`) |
| `append` | a path or URL | Add it to the playlist |
| `open-dir` | a folder | Play the folder as a playlist |
| `reload-colors` | none | Re-read the colors file right now (normally it is checked every second anyway) |

From a terminal, if you start mpv with `--input-ipc-server=/tmp/mpvsocket` and have `socat` installed:

```sh
echo '{"command":["script-message-to","ytosc","open","/home/you/Videos/movie.mkv"]}' | socat - /tmp/mpvsocket
```

---

## 16. What each file does

All of these live in `~/.config/mpv/scripts/ytosc/`. You never need to open them; this list is only here so you know what is what.

| File | In plain words |
|---|---|
| `main.lua` | The conductor. mpv starts here. Watches the player (position, volume, tracks...), decides when to show or hide the controls, and redraws. |
| `config.lua` | The list of settings and their defaults. Reads your `ytosc.conf`. |
| `state.lua` | The shared notebook where everything writes down what is going on (is it paused, is a menu open, where is the mouse...). |
| `util.lua` | Small helpers: time formatting, text shortening and so on. |
| `anim.lua` | Smooth fades and size changes. |
| `draw.lua` | The pencil: turns rectangles, circles and text into the drawing language mpv understands. |
| `icondata.lua` | The icon shapes (Google Material Icons). |
| `icons.lua` | Places and sizes the icons. |
| `theme.lua` | Reads the colors file, watches it for changes, and fades between palettes. |
| `layout.lua` | The floor plan: works out where every button and area is for the current window size, including which areas are clickable. |
| `render.lua` | The painter: draws everything using the floor plan and the colors. |
| `input.lua` | The mouse: clicks, double-clicks, wheel, dragging, hovering. |
| `keys.lua` | The keyboard: counts, chords like `gg`, marks, your custom keys. |
| `actions.lua` | The list of things that can be done (seek, pause, toggle menus...). Keys and mouse both call these. |
| `menus.lua` | The settings, open, view and recent popups. |
| `textinput.lua` | The little text box. |
| `openers.lua` | Opening files, folders, URLs, clipboard, pickers, and the recent-files list. |
| `panel.lua` | The playlist panel. |
| `strip.lua` | The More videos strip, including making thumbnails with ffmpeg. |
| `view.lua` | Theater mode and miniplayer (talks to Hyprland). |
| `cmdline.lua` | The `:` command line. |
| `thumb.lua` | The connection to thumbfast for seekbar previews. |

---

## 17. How it works, in plain words

1. mpv loads `main.lua` when it starts, because it is inside `scripts/ytosc/`.
2. ytosc asks mpv to tell it whenever something changes (position, pause, volume, subtitle tracks, window size, playlist...) and writes it in its notebook.
3. ytosc draws the interface as a **subtitle-style overlay**. mpv already knows how to draw subtitles in a powerful drawing language (called ASS), so ytosc "draws" rectangles, circles, icons and text in it and mpv puts the result over the video. That is why there are no images to install and why the look is fully controlled by colors and settings.
4. When you move the mouse or press a key, ytosc works out what was under the cursor (it has a map of clickable areas) and runs the matching action, which simply tells mpv what to do (`seek`, `cycle pause`, ...).
5. The controls only redraw while they are visible or animating. When hidden and idle, ytosc does almost nothing.
6. **Colors** live in a text file that ytosc re-reads each second.
7. **Thumbnails on the strip** come from ffmpeg, saved as small raw picture files, and shown with mpv's overlay feature. **Seekbar previews** come from thumbfast.
8. **Hyprland** is controlled by running `hyprctl` commands.
9. **File choosers** are separate small programs (zenity and friends) that ytosc starts and waits for, without freezing the player.

---

## 18. Troubleshooting

| Problem | What to try |
|---|---|
| Nothing changed, I see mpv's old controller | `osc=no` is missing in `~/.config/mpv/mpv.conf`, or the script is in the wrong place. The file must be `~/.config/mpv/scripts/ytosc/main.lua`. |
| I see two controllers | `osc=no` is missing, or something else sets it back. Check `mpv.conf` and any profile that re-enables it. |
| How do I confirm ytosc loaded? | Run `mpv --msg-level=ytosc=v file.mkv`. You should see `[ytosc] ytosc loaded`. |
| Errors in the terminal mentioning ytosc | Copy them. They name the file and line. Run `mpv --msg-level=all=v file.mkv 2>&1 \| grep -i ytosc` to collect them. |
| Keys do nothing, or do something else | Another script or your `input.conf` may use the same key. ytosc's keys win over mpv's defaults, but another script may fight them. Try `keymap=mpv` to see whether ytosc is the cause. |
| A key I need was taken over | Remap it in `ytosc-keys.conf` (section 14), e.g. `k=none`. |
| Keys behave oddly while a menu is open | Menus capture a few keys (`j`, `k`, `h`, `l`, `Enter`...). Press `Esc` to close the menu. |
| The playlist panel makes `k`, `l` etc. behave differently | By design: the open panel owns those keys. Close it with `Esc` or `Tab`. |
| Colors do not follow matugen | Check the file `~/.config/mpv/script-opts/ytosc-colors.conf` really changed and contains lines like `primary=1a73e8`. Check the matugen template variable names (section 11.3). Run `mpv --msg-level=ytosc=warn`. |
| Menus are hard to read | Raise `panel_alpha` toward 1 or adjust `scrim_alpha`. Check the contrast warning in the log. |
| The whole thing is too small / too big | Change `scale` in `ytosc.conf` (for example `scale=1.5`). |
| Text looks wrong or is the wrong font | Set `font=` to a font you have installed (`fc-list` shows them). |
| Seekbar preview does not appear | thumbfast is not installed or `thumbnails=no`. See section 12. |
| More videos cards have no pictures | Install ffmpeg. Cards for URLs never have thumbnails. Check `strip_thumbnails=yes`. |
| "Open file..." shows a text box instead of a window | No chooser program was found. Install zenity (`sudo pacman -S zenity`) or set `picker_file`. |
| "Paste and play" says the clipboard is empty | On mpv older than 0.39 ytosc needs `wl-paste` (package `wl-clipboard`) or `xclip`. Install one. |
| Folder opens in the wrong order | Order is natural (1, 2, 10) by file name. Rename files if you need a different order. |
| A file type in my folder is ignored | Add its extension to `media_extensions`. |
| Theater / miniplayer does nothing | You are not on Hyprland, or `hyprctl` is not in your PATH, or your Hyprland version names a command differently (section 10). |
| I cannot drag the window by clicking the video | ytosc uses clicks on the video for pause. Move windows with your compositor's shortcut (in Hyprland: `SUPER` + left mouse button). |
| Controls never hide | A menu, panel or the strip is open, or the mouse is over the controls, or the video is paused (`hide_when_paused=no`). |
| A button seems unclickable | Set `debug=yes` and restart: red boxes show where each click area really is. |
| Something is broken after an update | Delete the old `~/.config/mpv/scripts/ytosc` folder first, then copy the new one (section 20). Mixing old and new files causes odd errors. |

---

## 19. Known limitations and what was tested

Being honest about this so there are no surprises.

**Tested** (automatically, with simulated mpv and with a real mpv 0.37 running without a window):

- Every key, chord, count, mark and undo.
- All menus, caption options, the text box, the command line.
- Opening folders (natural order), single files with automatic playlist, URLs, recent-files history.
- The playlist panel: play, remove, reorder, filter.
- The More videos strip, including real ffmpeg thumbnail creation.
- The color file hot reload and fade.
- The top bar, window buttons, compact miniplayer layout, touch mode.
- The Hyprland command sequences against sample data (finding the right window by pid, docking in a corner, restoring the old state).
- The drawn interface was rendered to pictures and inspected.

**Not tested** (needs a real desktop session, so please report problems):

- The actual `hyprctl` commands on a live Hyprland. Command syntax differs between Hyprland versions.
- The real thumbfast previews and the strip thumbnails drawn on screen with a real video output.
- The real file chooser windows (zenity, kdialog, yad).
- Touchscreens.

**Limitations by design**

- Clicks on the video are used for pause, so mpv's "drag the window by clicking the video" is not available. Use your compositor's window-move shortcut.
- Theater mode is Hyprland's maximize, an approximation of YouTube's theater mode.
- The Video menu has no "Auto" check mark (mpv does not say whether the track was chosen automatically).
- The More videos cards have no "resume progress" bar.
- There is no "load external subtitle" entry. Use the `:` command line with `sub-add /path/file.srt`.
- Menus use mpv's overlay drawing, so there is no real blur behind panels and no true shadows; panels are flat see-through surfaces.
- When a menu, the playlist panel or the strip is open, a few keys (`j`, `k`, `h`, `l`, `g`, `G`, `Space`, `d`) steer it instead of doing their normal job.
- Styled subtitles keep their own look unless "Override embedded styling" is on.

---

## 20. Updating and uninstalling

**Update**: delete the old folder and copy the new one.

```sh
rm -rf ~/.config/mpv/scripts/ytosc
cp -r ytosc/scripts/ytosc ~/.config/mpv/scripts/
```

Your settings in `script-opts/` are untouched.

**Uninstall**:

```sh
rm -rf ~/.config/mpv/scripts/ytosc
rm -f ~/.config/mpv/script-opts/ytosc*.conf
rm -f ~/.local/state/mpv/ytosc-history
rm -rf ~/.cache/mpv/ytosc
```

Then remove (or set to `yes`) the `osc=no` and `osd-bar=no` lines in `mpv.conf` to get mpv's normal controller back.

---

## 21. Credits and licenses

- Icons: **Google Material Icons**, licensed under the Apache License 2.0 (https://github.com/google/material-design-icons).
- Seekbar previews are made by **thumbfast** (https://github.com/po5/thumbfast), a separate project you install yourself.
- The design follows YouTube's player layout. ytosc is an independent project and is not affiliated with Google or YouTube.
- Colors are generated by **matugen** when you use it.
