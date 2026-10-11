# omaapps: Launchpad-style app grid for Omarchy

## Context
The user wants a macOS Launchpad equivalent: a **4-finger touchpad swipe up** opens a full-screen grid of all installed apps to **browse visually**. The grid has a search box and pages they can swipe between. A **4-finger swipe down**, Esc, a click on empty space, or launching an app closes it. It will be a new Omarchy shell plugin in its own repo, so it can be published later like omawallet. It follows https://plugins.omarchy.org/develop.html.

Decisions made in chat:
- kind `menu`, so the plugin receives the shell's `appLibrary` facade.
- Name `omaapps`.
- Repo `~/Projects/omaapps`.
- id `io.github.aaquar1uss.omaapps`.
- Folders and reordering are out of scope for v1.

## Findings that shape the design
- **Menu and overlay plugins use the same loader** (`/usr/share/omarchy/shell/shell.qml:1145,1301`). Only `menu` plugins get `shell.appLibrary` (`shell.qml:603`). It provides `sortedEntries(query)`, `entryName`, `iconSource`, `launch(id,name)` and `refreshIcons`. It also applies `launcher.hides` and NoDisplay filtering, and shows the Launching OSD. `plugins/menu/Menu.qml:80,293,741` shows how to use it.
- **Contract for the entry root, taken from `plugins/emojis/Emojis.qml`:** properties `shell`, `manifest` and `opened`, and functions `open(payloadJson)`, `close()` and `toggle()`. To dismiss itself, the plugin calls `shell.hide(manifest.id)`.
- **The full-screen window pattern is in Emojis.qml:** a `PanelWindow` anchored on all four sides with `WlrLayer.Overlay`, `WlrKeyboardFocus.Exclusive` and `ExclusionMode.Ignore`, and `visible: root.opened`.
- **Triggering needs no IpcHandler:** `omarchy-shell shell summon|hide|toggle <id>`.
- **Hyprland is 0.56.2 with Lua config, and no gestures are active.** The commented examples in `~/.config/hypr/input.lua:51-57` show the syntax `hl.gesture({ fingers=…, direction=…, action=function() hl.dispatch(…) end })`. The exec dispatcher is `hl.dsp.exec_cmd(cmd)` (`default/hypr/helpers.lua:102`).
- **Repo tooling to copy from omabudget:**
  - `scripts/dev.sh`: link, unlink, reload, watch and logs, with a symlink into `~/.config/omarchy/plugins/<id>` named after the manifest id.
  - `package.json` with `node --test tests/*.test.mjs`.
  - `tests/load.mjs`: a loader for `.js` files written in QML style.
  - README and MIT LICENSE.

## Design
**Repo layout (`~/Projects/omaapps`)**
```
manifest.json      kinds ["menu"], entryPoints.menu "Launchpad.qml", keepLoaded true
Launchpad.qml      root Item: shell/manifest/opened, open/close/toggle, PanelWindow + key handling
ui/AppTile.qml     icon (Image from appLibrary.iconSource) + elided name, hover/press states, click → launch
ui/PageDots.qml    page indicator, clickable
ui/Paging.js       pure logic: gridShape(w,h), paginate(entries, perPage), clampPage, nextPage
tests/paging.test.mjs  node tests for Paging.js
scripts/dev.sh     adapted from omabudget (PLUGIN_ID changed)
package.json, README.md, LICENSE (MIT), .gitignore
```
`keepLoaded: true` keeps the window mounted, so the gesture opens it instantly.

**How it behaves**
- **Opening:** `open()` reloads `appLibrary.sortedEntries("")`, clears the search, jumps to page 0 and fades and scales the content in (about 150 ms). The scrim is dimmed and themed; the shell's theme colours come from `qs.Ui`, as omabudget's panel uses them.
- **Layout:**
  - A search field at the top centre.
  - Below it, a horizontal `ListView` with `snapMode: SnapOneItem` and `highlightRangeMode: StrictlyEnforceRange`. Each delegate is one page: a `Grid` of `AppTile`.
  - `gridShape` picks columns and rows from the screen size, about 7×5 on 1080p.
  - Page dots at the bottom.
- **Paging inputs:**
  - Drag or flick (from the ListView).
  - 2-finger horizontal touchpad scroll, via a `WheelHandler` on `angleDelta.x`/`pixelDelta.x`, with a threshold and cooldown so one swipe moves exactly one page.
  - Vertical mouse wheel.
  - Left/Right and PageUp/PageDown keys.
  - Clicking a dot.
- **Search:** typing anywhere focuses the field. A non-empty query switches the view to `sortedEntries(query)`, still paginated. Enter launches the first match. Esc clears the query first, then closes the grid.
- **Arrow keys:** they move a highlighted tile and Enter launches it. This is cheap to add and makes the grid usable from the keyboard.
- **Launching:** `appLibrary.launch(entry.id, name)`, then `shell.hide(manifest.id)`.
- **Closing:** Esc, a click on the scrim outside the tiles, launching an app, `omarchy-shell shell hide <id>`, or a 4-finger swipe down.
- **If `appLibrary` is null:** the plugin isn't loaded as a menu. Show a "no app library" message instead of crashing.

**Gesture (user config, following the omarchy skill)**
1. Back up `~/.config/hypr/input.lua`.
2. Append:
   ```lua
   hl.gesture({ fingers = 4, direction = "up",   action = function() hl.dispatch(hl.dsp.exec_cmd("omarchy-shell -q shell summon io.github.aaquar1uss.omaapps '{}'")) end })
   hl.gesture({ fingers = 4, direction = "down", action = function() hl.dispatch(hl.dsp.exec_cmd("omarchy-shell -q shell hide io.github.aaquar1uss.omaapps")) end })
   ```
3. Validate with `hyprctl reload` and `hyprctl configerrors`.
4. If the function-action form errors on 0.56, use the dispatcher-string action form from the Hyprland docs instead.

The README documents this snippet for other users.

## Implementation steps
1. Brainstorming spec: commit this design as `docs/superpowers/specs/2026-10-11-omaapps-design.md` in the new repo, after `git init`.
2. Scaffold: write the manifest, package.json, LICENSE and .gitignore, and copy dev.sh and load.mjs from omabudget.
3. Use TDD for `ui/Paging.js`, the testable logic:
   - `gridShape`: the min/max columns and rows across screen sizes.
   - `paginate`: an empty list, an exact multiple, a remainder.
   - `clampPage`.
   - The wheel accumulator, which crosses the threshold once per swipe.
4. Write `Launchpad.qml`, `AppTile.qml` and `PageDots.qml`.
5. `scripts/dev.sh link`, which validates, symlinks, rescans and enables.
6. Add the Hyprland gestures and validate them.
7. Write a README with a screenshot, install steps and the gesture snippet. Commit.

## Verification
- `npm test` passes.
- `omarchy plugin validate .` passes.
- `qmllint -I "$OMARCHY_PATH/shell" Launchpad.qml ui/*.qml` exits cleanly.
- `omarchy plugin list --json | jq '.[]|select(.id=="io.github.aaquar1uss.omaapps")'` shows the plugin as enabled.
- `omarchy-shell shell summon io.github.aaquar1uss.omaapps '{}'` opens the grid and `… hide …` closes it. Check `qs log -p "$OMARCHY_PATH/shell" --tail 100` for errors.
- Manual checklist from the develop docs:
  - The 4-finger swipe up opens the grid and the swipe down closes it.
  - A 2-finger horizontal swipe moves exactly one page.
  - Search filters, and Enter launches the first match.
  - Clicking an app launches it (Launching OSD) and closes the grid.
  - Esc and clicking empty space close it.
  - Disable then re-enable the plugin, restart the shell, and confirm it still works.
- `hyprctl configerrors` is empty after the gesture edit.
