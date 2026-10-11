import { test } from "node:test"
import assert from "node:assert/strict"
import { Apps } from "./load.mjs"

const entry = (id, name, extra = {}) => ({ id, name, icon: id, ...extra })

test("parseIds reads one desktop id per line, dropping .desktop and blanks", () => {
  assert.deepEqual(Apps.parseIds("btop\n  cmake-gui.desktop \n\n"), { "btop": true, "cmake-gui": true })
  assert.deepEqual(Apps.parseIds(""), {})
})

test("list skips NoDisplay, hidden and nameless entries and sorts by name", () => {
  const values = [
    entry("zed", "Zed"),
    entry("btop", "btop"),
    entry("ghost", "Ghost", { noDisplay: true }),
    entry("anon", ""),
    entry("alacritty", "Alacritty")
  ]
  const out = Apps.list(values, "", { btop: true })
  assert.deepEqual(out.map(a => a.id), ["alacritty", "zed"])
  assert.deepEqual(out[0], { id: "alacritty", name: "Alacritty", icon: "alacritty" })
})

test("list search: every term must match name, generic name, keywords or id", () => {
  const values = [
    entry("org.gnome.Nautilus", "Files", { genericName: "File Manager" }),
    entry("firefox", "Firefox", { genericName: "Web Browser", keywords: ["internet", "www"] }),
    entry("chromium", "Chromium", { genericName: "Web Browser" })
  ]
  assert.deepEqual(Apps.list(values, "nautilus", {}).map(a => a.id), ["org.gnome.Nautilus"])
  assert.deepEqual(Apps.list(values, "www", {}).map(a => a.id), ["firefox"])
  assert.deepEqual(Apps.list(values, "web chr", {}).map(a => a.id), ["chromium"])
  assert.deepEqual(Apps.list(values, "nope", {}), [])
})

test("list search ranks name prefix above name contains above other fields", () => {
  const values = [
    entry("term-tool", "Tool", { genericName: "Terminal helper" }),
    entry("xterm", "XTerm"),
    entry("terminal", "Terminal")
  ]
  assert.deepEqual(Apps.list(values, "term", {}).map(a => a.id), ["terminal", "xterm", "term-tool"])
})
