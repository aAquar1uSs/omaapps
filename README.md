# omaapps

A Launchpad-style app grid for [Omarchy](https://omarchy.org). Swipe up with
four fingers and every installed app appears as a full-screen grid of icons.
Flip between pages, type to search, and click an app to launch it.

- Full-screen icon grid, sized to your screen (up to 8 × 6 per page)
- Pages: two-finger horizontal swipe, mouse wheel, PageUp/PageDown, or click the dots
- Type anywhere to search by name, generic name, keywords or desktop id; Enter launches the first match
- Arrow keys move a highlight; Enter launches it
- Esc clears the search, then closes; clicking empty space or launching an app also closes
- Hides the same apps as the Omarchy launcher (NoDisplay, `launcher.hides`, entries hidden for this desktop)
- Follows the current Omarchy theme (menu colours and font)

## Install

```sh
omarchy plugin add https://github.com/aAquar1uSs/omaapps.git --enable
```

Try it:

```sh
omarchy-shell shell toggle io.github.aaquar1uss.omaapps '{}'
```

## Touchpad gesture

Add the gesture to `~/.config/hypr/input.lua`:

```lua
hl.gesture({ fingers = 4, direction = "up", action = function() hl.exec_cmd("omarchy-shell -q shell summon io.github.aaquar1uss.omaapps '{}'") end })
hl.gesture({ fingers = 4, direction = "down", action = function() hl.exec_cmd("omarchy-shell -q shell hide io.github.aaquar1uss.omaapps") end })
hl.layer_rule({ match = { namespace = "^omaapps$" }, no_anim = true })
```

Then check it with `hyprctl reload && hyprctl configerrors`.

Prefer a key? Bind one in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + A", "Apps grid", "omarchy-shell -q shell toggle io.github.aaquar1uss.omaapps '{}'")
```

## Development

```sh
scripts/dev.sh link     # validate, symlink into ~/.config/omarchy/plugins, enable
scripts/dev.sh reload   # restart the shell after edits (hot reload skips symlinks)
npm test                # paging and app-list logic (node --test)
omarchy plugin validate .
```

`ui/Paging.js` (grid shape, pages, keyboard moves, swipe recognizer) and
`ui/Apps.js` (filtering, search ranking) hold the logic and are unit-tested;
`Launchpad.qml` is the overlay window.

### Why not the shell's app library?

The Omarchy shell offers `shell.appLibrary` to `menu`-kind plugins. In Omarchy
4.0.4, third-party panel/overlay/menu plugins receive their manifest through an
`Instantiator`, where `kinds` is not a JS `Array`. `manifestHasKind()` checks
`Array.isArray`, so it returns false and `appLibrary` is always `null`. omaapps
therefore reads `DesktopEntries` itself.

## License

MIT
