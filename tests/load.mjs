// Loads the plugin's QML JavaScript libraries (`.pragma library` files) as
// plain objects for Node tests.
import { readFileSync } from "node:fs"
import { join, dirname } from "node:path"
import { fileURLToPath } from "node:url"

const uiDir = join(dirname(fileURLToPath(import.meta.url)), "../ui")

function topLevelNames(src) {
  const names = new Set()
  for (const m of src.matchAll(/^(?:function\s+([A-Za-z_$][\w$]*)|var\s+([A-Za-z_$][\w$]*))/gm))
    names.add(m[1] || m[2])
  return [...names]
}

export function loadLibrary(file) {
  const src = readFileSync(join(uiDir, file), "utf8").replace(/^\.pragma library\s*$/m, "")
  return new Function(src + "\nreturn {" + topLevelNames(src).join(",") + "}")()
}

export const Paging = loadLibrary("Paging.js")
export const Apps = loadLibrary("Apps.js")
