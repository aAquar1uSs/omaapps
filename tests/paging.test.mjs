import { test } from "node:test"
import assert from "node:assert/strict"
import { Paging } from "./load.mjs"

test("gridShape fits whole cells and respects the caps", () => {
  assert.deepEqual(Paging.gridShape(1500, 860, 200, 160), { columns: 7, rows: 5 })
  assert.deepEqual(Paging.gridShape(3840, 2000, 200, 160), { columns: 8, rows: 6 })
})

test("gridShape never drops below one cell", () => {
  assert.deepEqual(Paging.gridShape(0, 0, 200, 160), { columns: 1, rows: 1 })
  assert.deepEqual(Paging.gridShape(150, 100, 200, 160), { columns: 1, rows: 1 })
})

test("paginate splits into pages of perPage", () => {
  assert.deepEqual(Paging.paginate([], 4), [])
  assert.deepEqual(Paging.paginate([1, 2, 3, 4], 4), [[1, 2, 3, 4]])
  assert.deepEqual(Paging.paginate([1, 2, 3, 4, 5], 2), [[1, 2], [3, 4], [5]])
  assert.deepEqual(Paging.paginate([1, 2], 0), [[1], [2]])
})

test("clampPage keeps the page in range", () => {
  assert.equal(Paging.clampPage(3, 0), 0)
  assert.equal(Paging.clampPage(-1, 3), 0)
  assert.equal(Paging.clampPage(5, 3), 2)
  assert.equal(Paging.clampPage(1, 3), 1)
})

test("moveIndex: horizontal moves cross pages, clamped to the list", () => {
  // 2 columns x 2 rows = 4 per page, 6 items
  assert.equal(Paging.moveIndex(3, 1, 0, 2, 2, 6), 4)
  assert.equal(Paging.moveIndex(5, 1, 0, 2, 2, 6), 5)
  assert.equal(Paging.moveIndex(0, -1, 0, 2, 2, 6), 0)
  assert.equal(Paging.moveIndex(-1, 1, 0, 2, 2, 6), 0)
  assert.equal(Paging.moveIndex(0, 1, 0, 2, 2, 0), -1)
})

test("moveIndex: vertical moves stay on the current page", () => {
  assert.equal(Paging.moveIndex(0, 0, 1, 2, 2, 6), 2)
  assert.equal(Paging.moveIndex(2, 0, 1, 2, 2, 6), 2)
  assert.equal(Paging.moveIndex(2, 0, -1, 2, 2, 6), 0)
  // page 2 holds items 4,5 in its first row; down has no target
  assert.equal(Paging.moveIndex(5, 0, 1, 2, 2, 6), 5)
  // 5 items: down from 2 (col 0) lands on 4; down from 3 (col 1) clamps to 4
  assert.equal(Paging.moveIndex(1, 0, 1, 2, 3, 5), 3)
  assert.equal(Paging.moveIndex(3, 0, 1, 2, 3, 5), 4)
})

// Recorded on a real touchpad: a two-finger swipe is a ~100-150 ms burst of
// wheel events ~8 ms apart, summing to |1000..3600|, with no kinetic tail.
// The grid follows the fingers during the burst and commits on release.

test("gestureStep: commits a page past the threshold, positive is next", () => {
  assert.equal(Paging.gestureStep(1200, 120), 1)
  assert.equal(Paging.gestureStep(-1200, 120), -1)
  assert.equal(Paging.gestureStep(120, 120), 1)
  assert.equal(Paging.gestureStep(80, 120), 0)
  assert.equal(Paging.gestureStep(-80, 120), 0)
})

test("dragOffset follows the fingers, capped at one page", () => {
  assert.equal(Paging.dragOffset(1000, 0.4, 1000, 0, 3), 400)
  assert.equal(Paging.dragOffset(-1000, 0.4, 1000, 1, 3), -400)
  assert.equal(Paging.dragOffset(5000, 0.4, 1000, 0, 3), 1000)
})

test("dragOffset rubber-bands past the first and last page", () => {
  assert.equal(Paging.dragOffset(-1000, 0.4, 1000, 0, 3), -100)
  assert.equal(Paging.dragOffset(1000, 0.4, 1000, 2, 3), 100)
  assert.equal(Paging.dragOffset(1000, 0.4, 1000, 0, 1), 100)
  assert.equal(Paging.dragOffset(1000, 0.4, 1000, 0, 0), 100)
})
