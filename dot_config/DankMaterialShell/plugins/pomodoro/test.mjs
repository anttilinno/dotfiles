// node test.mjs — checks the timer logic in pomodoro.js
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const src = readFileSync(new URL("./pomodoro.js", import.meta.url), "utf8").replace(".pragma library", "")
const P = new Function(src + "; return { reset, click, remaining, isDone, format, slot, view, nextBreak, until }")()

const WORK = 25 * 60 * 1000, BREAK = 5 * 60 * 1000
const cfg = { work: WORK, brk: BREAK, startHour: 0, endHour: 0 } // no schedule: manual timer
let s = P.reset()
assert.equal(P.remaining(s, 0, cfg), WORK)

s = P.click(s, 1000, cfg) // start
assert.equal(s.endAt, 1000 + WORK)
assert.equal(P.remaining(s, 61000, cfg), WORK - 60000)

s = P.click(s, 61000, cfg) // pause
assert.equal(s.endAt, 0)
assert.equal(P.remaining(s, 999999, cfg), WORK - 60000)

s = P.click(s, 100000, cfg) // resume
assert.equal(P.remaining(s, 100000, cfg), WORK - 60000)
assert.ok(!P.isDone(s, s.endAt - 1))
assert.ok(P.isDone(s, s.endAt))
assert.equal(P.remaining(s, s.endAt + 5000, cfg), 0)

s = P.click(s, s.endAt + 5000, cfg) // done -> break
assert.equal(s.phase, "break")
s = P.click(s, s.endAt, cfg) // break done -> work
assert.equal(s.phase, "work")

assert.equal(P.remaining(P.reset(), 0, { work: 60000, brk: 1 }), 60000) // config change applies when idle
assert.equal(P.format(WORK), "25:00")
assert.equal(P.format(61001), "1:02")
assert.equal(P.format(0), "0:00")
// Schedule: 9-17, fixed slots from 9:00.
const day = { work: WORK, brk: BREAK, startHour: 9, endHour: 17 }
const at = (h, m, sec = 0) => new Date(2026, 9, 5, h, m, sec).getTime()
assert.equal(P.slot(at(8, 59), day), null)
assert.equal(P.slot(at(17, 0), day), null)
assert.deepEqual(P.slot(at(9, 0), day), { phase: "work", start: at(9, 0), endAt: at(9, 25) })
assert.deepEqual(P.slot(at(9, 41), day), { phase: "work", start: at(9, 30), endAt: at(9, 55) }) // late join -> shorter
assert.deepEqual(P.slot(at(9, 57), day), { phase: "break", start: at(9, 55), endAt: at(10, 0) })
assert.deepEqual(P.slot(at(16, 58), day), { phase: "break", start: at(16, 55), endAt: at(17, 0) })

let v = P.view(P.reset(), at(9, 41), day)
assert.equal(v.auto, true)
assert.equal(v.remaining, 14 * 60000)
assert.ok(v.running && !v.warn && !v.overlay) // work: no overlay
assert.ok(!P.view(P.reset(), at(9, 51), day).overlay) // 4 min before the break: still nothing
v = P.view(P.reset(), at(9, 52, 30), day) // 3 min before the break: blink
assert.ok(v.warn && v.overlay && v.phase === "work" && v.remaining === 150000)
v = P.view(P.reset(), at(9, 57), day) // break: steady overlay, counting down to work
assert.ok(v.overlay && !v.warn && v.phase === "break" && v.remaining === 3 * 60000)
assert.ok(!P.view(P.reset(), at(8, 58), day).active) // before the day: nothing

assert.equal(P.nextBreak(at(8, 0), day), at(9, 25))
assert.equal(P.nextBreak(at(9, 41), day), at(9, 55))
assert.equal(P.nextBreak(at(9, 55), day), at(10, 25)) // in a break: the following one
assert.equal(P.nextBreak(at(16, 56), day), at(9, 25) + 86400000) // tomorrow
assert.equal(P.nextBreak(at(9, 0), { ...day, endHour: 9 }), 0) // schedule off
// End hour cuts a work slot short: no break follows, so no blink.
const short = { ...day, endHour: 10, work: 40 * 60000, brk: 10 * 60000 } // 9:00 work, 9:40 break, 9:50 work -> 10:00
assert.ok(!P.view(P.reset(), at(9, 58), short).warn)
assert.equal(P.until(12 * 60000), "in 12 min")
assert.equal(P.until(125 * 60000), "in 2 h 5 min")

s = P.click(P.reset(), at(10, 0), day) // meeting: schedule off for today
v = P.view(s, at(11, 0), day)
assert.ok(!v.running && !v.active)
assert.ok(!P.view(s, at(10, 53), day).overlay) // off today: no overlay
assert.ok(P.view(s, at(9, 0) + 86400000, day).running) // back on next day
assert.ok(P.view(P.click(s, at(11, 0), day), at(11, 0), day).running) // click again -> on

// Stale manual timer left from the morning doesn't blink after hours.
assert.ok(!P.view({ phase: "work", endAt: at(8, 55), pausedLeft: 0, offDay: "" }, at(17, 5), day).done)

// Micro breaks: 55 work + 5 break, 30 s eye relief every 25 min of work, none 5 min before the break.
const eyes = { ...day, work: 55 * 60000, micro: 25 * 60000 }
assert.equal(P.view(P.reset(), at(9, 24, 59), eyes).phase, "work")
v = P.view(P.reset(), at(9, 25, 10), eyes)
assert.ok(v.phase === "micro" && v.overlay && v.remaining === 20000)
assert.equal(P.view(P.reset(), at(9, 25, 30), eyes).phase, "work")
assert.equal(P.view(P.reset(), at(9, 25, 30), eyes).remaining, 29.5 * 60000) // still counts to the break
assert.equal(P.view(P.reset(), at(9, 50, 10), eyes).phase, "work") // break 5 min away: skipped
assert.equal(P.view(P.reset(), at(10, 25, 10), eyes).phase, "micro") // next hour
assert.ok(!P.view(P.click(P.reset(), at(9, 0), eyes), at(9, 25, 10), eyes).overlay) // off today: none
assert.equal(P.view(P.reset(), at(9, 25, 10), { ...eyes, micro: 0 }).phase, "work") // 0 = off
console.log("ok")
