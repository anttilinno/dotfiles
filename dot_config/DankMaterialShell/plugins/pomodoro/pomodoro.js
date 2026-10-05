.pragma library

// Inside working hours the timer follows fixed clock slots counted from the start hour
// (9:00 work, 9:25 break, 9:30 work, ...) and runs by itself. Outside them it's a manual timer.
// "Pomodoro" in the UI means the break: work is the normal state, the overlay only shows
// around breaks.
//
// State, shared by all bar instances via plugin state:
//   { phase: "work" | "break", endAt: epoch ms (0 = not running), pausedLeft: ms (0 = not paused),
//     offDay: "Y-M-D" when the schedule was switched off for that day }
// cfg = { work: ms, brk: ms, startHour, endHour }, from the right-click popout.

var WARN_MS = 3 * 60000 // overlay blinks this long before a scheduled break starts
var STALE_MS = 3600000 // ponytail: a finished manual timer nobody clicked is dropped after an hour

function duration(phase, cfg) {
    return phase === "break" ? cfg.brk : cfg.work
}

function reset() {
    return { phase: "work", endAt: 0, pausedLeft: 0, offDay: "" }
}

function dayKey(now) {
    var d = new Date(now)
    return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate()
}

// Current scheduled slot { phase, start, endAt }, or null outside working hours.
function slot(now, cfg) {
    var d = new Date(now)
    var dayStart = new Date(d.getFullYear(), d.getMonth(), d.getDate(), cfg.startHour).getTime()
    var dayEnd = new Date(d.getFullYear(), d.getMonth(), d.getDate(), cfg.endHour).getTime()
    if (now < dayStart || now >= dayEnd)
        return null
    var pos = (now - dayStart) % (cfg.work + cfg.brk)
    var isWork = pos < cfg.work
    var start = now - pos + (isWork ? 0 : cfg.work)
    return {
        phase: isWork ? "work" : "break",
        start: start,
        endAt: Math.min(dayEnd, start + (isWork ? cfg.work : cfg.brk))
    }
}

// Start of the next scheduled break after now (today or tomorrow), or 0 when the schedule is off.
function nextBreak(now, cfg) {
    if (cfg.startHour >= cfg.endHour)
        return 0
    var d = new Date(now)
    var cycle = cfg.work + cfg.brk
    for (var i = 0; i < 2; i++) {
        var first = new Date(d.getFullYear(), d.getMonth(), d.getDate() + i, cfg.startHour).getTime() + cfg.work
        var dayEnd = new Date(d.getFullYear(), d.getMonth(), d.getDate() + i, cfg.endHour).getTime()
        var t = now < first ? first : first + (Math.floor((now - first) / cycle) + 1) * cycle
        if (t < dayEnd)
            return t
    }
    return 0
}

function remaining(s, now, cfg) {
    if (s.endAt > 0)
        return Math.max(0, s.endAt - now)
    return s.pausedLeft > 0 ? s.pausedLeft : duration(s.phase, cfg)
}

function isDone(s, now) {
    return s.endAt > 0 && now >= s.endAt
}

// What the bar and overlay show. overlay: show the big timer on the second monitor.
// warn: blink, a break starts within WARN_MS. done: blink, manual timer is up.
function view(s, now, cfg) {
    var sl = slot(now, cfg)
    if (sl) {
        var off = s.offDay === dayKey(now)
        var warn = !off && sl.phase === "work" && sl.endAt === nextBreak(now, cfg) && sl.endAt - now <= WARN_MS
        return {
            auto: true, phase: sl.phase, remaining: sl.endAt - now, running: !off, active: !off,
            overlay: !off && (warn || sl.phase === "break"), done: false, warn: warn
        }
    }
    if (s.endAt > 0 && now - s.endAt > STALE_MS)
        s = reset()
    var paused = s.endAt === 0 && s.pausedLeft > 0
    return {
        auto: false, phase: s.phase, remaining: remaining(s, now, cfg),
        running: s.endAt > 0, active: s.endAt > 0 || paused, overlay: s.endAt > 0 || paused,
        done: isDone(s, now), warn: false
    }
}

// Left click. In working hours: switch the schedule off/on for today (meetings).
// Otherwise: start -> pause -> resume; when time is up, start the next phase.
function click(s, now, cfg) {
    if (slot(now, cfg)) {
        var today = dayKey(now)
        return { phase: "work", endAt: 0, pausedLeft: 0, offDay: s.offDay === today ? "" : today }
    }
    if (isDone(s, now)) {
        var next = s.phase === "work" ? "break" : "work"
        return { phase: next, endAt: now + duration(next, cfg), pausedLeft: 0, offDay: s.offDay }
    }
    if (s.endAt > 0)
        return { phase: s.phase, endAt: 0, pausedLeft: s.endAt - now, offDay: s.offDay }
    return { phase: s.phase, endAt: now + remaining(s, now, cfg), pausedLeft: 0, offDay: s.offDay }
}

// "in 12 min", "in 3 h 5 min"
function until(ms) {
    var m = Math.ceil(ms / 60000)
    return "in " + (m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min")
}

function format(ms) {
    var t = Math.ceil(ms / 1000)
    var sec = t % 60
    return Math.floor(t / 60) + ":" + (sec < 10 ? "0" : "") + sec
}
