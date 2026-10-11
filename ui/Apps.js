.pragma library

// App list from Quickshell DesktopEntries, filtered and ranked the way the
// Omarchy launcher does (NoDisplay, launcher.hides, desktop-hidden entries).
// Plain objects in, plain objects out, so it is unit-tested under Node.

// "foo.desktop\nbar\n" -> { foo: true, bar: true }
function parseIds(text) {
  var out = {}
  var lines = String(text || "").split(/\n/)
  for (var i = 0; i < lines.length; i++) {
    var id = lines[i].trim()
    if (id.slice(-8) === ".desktop") id = id.slice(0, -8)
    if (id) out[id] = true
  }
  return out
}

function keywords(entry) {
  try {
    if (entry.keywords && typeof entry.keywords.join === "function") return entry.keywords.join(" ")
  } catch (e) { }
  return ""
}

// -1 when a term misses; otherwise higher ranks first.
function score(entry, name, query) {
  var terms = query.split(/\s+/)
  var haystack = [name, entry.genericName, entry.comment, keywords(entry), entry.id].join(" ").toLowerCase()
  for (var i = 0; i < terms.length; i++)
    if (terms[i] && haystack.indexOf(terms[i]) < 0) return -1
  var lower = name.toLowerCase()
  var at = lower.indexOf(query)
  if (at === 0) return 3
  if (at > 0) return 2
  return 1
}

// entries: DesktopEntry-like objects; hidden: { id: true }.
// Returns [{ id, name, icon }] sorted by rank (when searching), then name.
function list(entries, query, hidden) {
  var q = String(query || "").trim().toLowerCase()
  var rows = []
  for (var i = 0; i < entries.length; i++) {
    var entry = entries[i]
    if (!entry || entry.noDisplay) continue
    var id = String(entry.id || "")
    var name = String(entry.name || "")
    if (!id || !name || hidden[id] === true) continue
    var rank = q ? score(entry, name, q) : 0
    if (rank < 0) continue
    rows.push({ app: { id: id, name: name, icon: String(entry.icon || "") }, rank: rank, key: name.toLowerCase() })
  }
  rows.sort(function(a, b) {
    if (a.rank !== b.rank) return b.rank - a.rank
    return a.key < b.key ? -1 : a.key > b.key ? 1 : 0
  })
  return rows.map(function(row) { return row.app })
}
