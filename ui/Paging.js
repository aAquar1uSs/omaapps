.pragma library

// Pure paging logic for the app grid, kept out of QML so it is unit-tested.

var MAX_COLUMNS = 8
var MAX_ROWS = 6

// How many whole cells of cellWidth x cellHeight fit, capped so huge
// screens keep Launchpad-sized tiles instead of a dense wall of icons.
function gridShape(width, height, cellWidth, cellHeight) {
  var columns = Math.floor(width / Math.max(1, cellWidth))
  var rows = Math.floor(height / Math.max(1, cellHeight))
  return {
    columns: Math.max(1, Math.min(MAX_COLUMNS, columns)),
    rows: Math.max(1, Math.min(MAX_ROWS, rows))
  }
}

function paginate(items, perPage) {
  var size = Math.max(1, perPage | 0)
  var pages = []
  for (var i = 0; i < items.length; i += size) pages.push(items.slice(i, i + size))
  return pages
}

function clampPage(page, count) {
  if (count <= 0) return 0
  return Math.max(0, Math.min(count - 1, page))
}

// Moves a global selection index. dx walks the list (crossing pages);
// dy moves by rows but never leaves the current page. Returns -1 for an
// empty list.
function moveIndex(index, dx, dy, columns, rows, total) {
  if (total <= 0) return -1
  if (index < 0) return 0
  var next = index
  if (dx !== 0) next = index + dx
  if (dy !== 0) {
    var perPage = columns * rows
    var pageStart = Math.floor(index / perPage) * perPage
    var local = index - pageStart
    var row = Math.floor(local / columns) + dy
    if (row < 0 || row >= rows) return index
    next = pageStart + row * columns + (local % columns)
    if (next >= total) next = total - 1
    if (next < pageStart + row * columns) return index
  }
  return Math.max(0, Math.min(total - 1, next))
}

// Touchpad paging. A two-finger swipe arrives as a short burst of wheel
// deltas with no kinetic tail. While it lasts the grid follows the fingers
// (dragOffset); once the burst ends the accumulated delta decides whether
// to commit a page (gestureStep). Positive delta is the next page.

// Pixels to shift the grid for an accumulated delta: proportional to the
// swipe, capped at one page, and damped (rubber band) past either end.
function dragOffset(acc, gain, width, page, pageCount) {
  var offset = acc * gain
  var pastEnd = (offset > 0 && page >= pageCount - 1) || (offset < 0 && page <= 0)
  if (pastEnd) offset *= 0.25
  return Math.max(-width, Math.min(width, offset))
}

function gestureStep(acc, threshold) {
  if (acc >= threshold) return 1
  if (acc <= -threshold) return -1
  return 0
}
