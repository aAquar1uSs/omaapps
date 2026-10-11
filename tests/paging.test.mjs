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

test("swipe: one page per gesture, inertia ignored until it settles", () => {
  const opts = { threshold: 100, cooldown: 300, idle: 150 }
  let s = Paging.newSwipe()
  let r = Paging.swipe(s, -60, 0, opts); s = r.state
  assert.equal(r.step, 0)
  r = Paging.swipe(s, -60, 10, opts); s = r.state
  assert.equal(r.step, 1)
  // Inertia keeps arriving: swallowed, and it keeps the lock alive.
  r = Paging.swipe(s, -200, 200, opts); s = r.state
  assert.equal(r.step, 0)
  r = Paging.swipe(s, -200, 450, opts); s = r.state
  assert.equal(r.step, 0)
  // After a quiet cooldown, the opposite direction pages back.
  r = Paging.swipe(s, 120, 900, opts); s = r.state
  assert.equal(r.step, -1)
})

test("swipe: small scrolls separated by idle gaps never add up", () => {
  const opts = { threshold: 100, cooldown: 300, idle: 150 }
  let s = Paging.newSwipe()
  let r = Paging.swipe(s, -60, 0, opts); s = r.state
  r = Paging.swipe(s, -60, 500, opts); s = r.state
  assert.equal(r.step, 0)
})
