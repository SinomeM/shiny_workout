// Workout player. Runs a plan compiled in R (player_plan()) with its own clock, so
// timing never waits on Shiny.
// R -> JS: "sw-player-load" {plan} (plan is null when the workout can't run).
// JS -> R: <ns>log (JSON string of the session log, to download), <ns>edit (back to editor).
// Times are measured on an "active" clock that stops while paused. An auto step ends
// exactly at its start + duration, so steps never drift, even in a throttled background tab.
(function () {
  var PREFS_KEY = "shiny_workout.player";
  var root = null, plan = null, pending = null, hasPending = false;
  var state = "idle";            // idle | ready | running | paused | confirm | finished
  var pausedBeforeConfirm = false;
  var now = function () { return performance.now(); };
  var pausedAt = null, pausedTotal = 0;
  var idx = 0, stepStart = 0, runStart = 0;
  var startedAt = null, finishedAt = null, completed = false, activeTotal = 0;
  var log = [], cue = {}, cumEst = [];
  var timer = null, wakeLock = null, audio = null, realFull = false;
  var prefs = loadPrefs();

  // Clock -------------------------------------------------------------------

  function active() { return (pausedAt !== null ? pausedAt : now()) - pausedTotal; }
  function elapsed() { return (active() - stepStart) / 1000; }
  function step() { return plan.steps[idx]; }

  function fmt(sec) {
    sec = Math.max(0, Math.floor(sec + 1e-6));
    var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
    var ss = (s < 10 ? "0" : "") + s;
    return h ? h + ":" + (m < 10 ? "0" : "") + m + ":" + ss : m + ":" + ss;
  }

  // Flow --------------------------------------------------------------------

  function load(newPlan) {
    if (state === "running" || state === "paused" || state === "confirm" || state === "finished") {
      pending = newPlan; hasPending = true;   // applied when this run is closed
      return;
    }
    setPlan(newPlan);
    setState(plan ? "ready" : "idle");
  }

  function setPlan(p) {
    plan = p; hasPending = false; pending = null;
    cumEst = [0];
    if (plan) {
      plan.steps.forEach(function (s, i) { cumEst.push(cumEst[i] + (s.est || 0)); });
      text("workout", plan.name);
    }
  }

  function start() {
    if (!plan || !plan.steps.length) return;
    unlockAudio();
    idx = 0; log = []; pausedAt = null; pausedTotal = 0; completed = false;
    startedAt = new Date(); finishedAt = null;
    runStart = stepStart = active();
    setState("running");
    requestWake();
    if (!timer) timer = setInterval(tick, 100);
    enter();
  }

  function enter() {
    cue = {};
    var s = step();
    root.setAttribute("data-kind", s.kind);
    text("kind", s.kind_label === s.label ? "" : s.kind_label);
    text("title", s.label);
    text("sub", s.sub);
    text("notes", [s.weight, s.notes].filter(Boolean).join(" · "));
    text("next", s.next_text || "Finish");
    beep(idx === 0 ? "start" : "change");
    speak(s.speech);
    render();
  }

  function logStep(how, at) {
    var s = step();
    log.push({ index: s.index, title: s.title, kind: s.kind, round: s.round, side: s.side,
               planned: s.duration, actual: Math.round((at - stepStart) / 100) / 10, ended: how });
  }

  function finishStep(how, at) {
    logStep(how, at);
    stepStart = at;
    if (idx + 1 >= plan.steps.length) return finish(true);
    idx += 1;
    enter();
  }

  function prev() {
    if (idx === 0) { stepStart = active(); enter(); return; }
    // Redo the previous step: its log entry is replaced when it ends again.
    for (var i = log.length - 1; i >= 0; i--) {
      if (log[i].index === plan.steps[idx - 1].index) { log.splice(i, 1); break; }
    }
    idx -= 1;
    stepStart = active();
    enter();
  }

  function pause() {
    if (state !== "running") return;
    pausedAt = now();
    setState("paused");
    releaseWake();
    render();
  }

  function resume() {
    if (pausedAt !== null) { pausedTotal += now() - pausedAt; pausedAt = null; }
    setState("running");
    requestWake();
    render();
  }

  function askStop() {
    pausedBeforeConfirm = state === "paused";
    if (state === "running") pausedAt = now();
    setState("confirm");
  }

  function keepGoing() {
    if (pausedBeforeConfirm) { setState("paused"); render(); } else resume();
  }

  function finish(done) {
    completed = done;
    finishedAt = new Date();
    if (pausedAt !== null) { pausedTotal += now() - pausedAt; pausedAt = null; }
    if (!done) logStep("stopped", active());
    activeTotal = (active() - runStart) / 1000;
    clearInterval(timer); timer = null;
    releaseWake();
    setState("finished");
    beep(done ? "finish" : "change");
    speak(done ? "Workout complete. Well done!" : "Workout stopped.");
    renderEnd(activeTotal);
  }

  function close(runAgain) {
    if (hasPending) setPlan(pending);
    setState(plan ? "ready" : "idle");
    if (runAgain) start();
  }

  function tick() {
    if (state !== "running") return;
    // Auto steps whose time is up end at their planned time, not at this tick.
    for (var guard = 0; guard < 1000 && state === "running"; guard++) {
      var s = step();
      if (!(s.auto && s.duration !== null && elapsed() >= s.duration)) break;
      finishStep("auto", stepStart + s.duration * 1000);
    }
    if (state === "running") { cues(); render(); }
  }

  // Sound cues, each played once per step (`cue` is reset on every step).
  function cues() {
    var s = step(), e = elapsed();
    if (s.hold !== null) {
      var cycle = s.hold + s.relax, n = Math.floor(e / cycle);
      var phase = e >= s.duration ? "end" : n + (e - n * cycle < s.hold ? "hold" : "relax");
      if (cue.phase !== undefined && cue.phase !== phase) {
        beep(phase === "end" ? (s.auto ? null : "over") : /hold$/.test(phase) ? "hold" : "release");
      }
      cue.phase = phase;
      return;
    }
    if (s.duration === null) return;
    var left = Math.ceil(s.duration - e);
    if (s.duration >= 5 && left >= 1 && left <= 3 && cue.count !== left) { cue.count = left; beep("count"); }
    if (!s.auto && left <= 0 && !cue.over) { cue.over = true; beep("over"); }
  }

  // Rendering ---------------------------------------------------------------

  var els = {};
  function el(name) {
    if (!els[name] || !root.contains(els[name])) els[name] = root.querySelector('[data-p="' + name + '"]');
    return els[name];
  }
  function text(name, value) { var e = el(name); if (e) e.textContent = value || ""; }

  function render() {
    if (!plan || !(state === "running" || state === "paused" || state === "confirm")) return;
    var s = step(), e = elapsed(), clock, target = s.target || "", hint = "", over = false, up = false;
    if (s.hold !== null) {
      var cycle = s.hold + s.relax, n = Math.floor(e / cycle), within = e - n * cycle;
      if (e < s.duration) {
        var holding = within < s.hold;
        clock = fmt(Math.ceil((holding ? s.hold : cycle) - within));
        target = "Rep " + (n + 1) + "/" + s.reps + " · " + (holding ? "Hold" : "Relax");
      } else {
        clock = "+" + fmt(e - s.duration); over = true;
        target = s.reps + " reps done";
      }
    } else if (s.duration !== null) {
      var left = s.duration - e;
      if (left > 0) clock = fmt(Math.ceil(left - 1e-6));
      else { clock = "+" + fmt(-left); over = !s.auto; }
    } else {
      clock = fmt(e); up = true;
    }
    if (state === "paused") hint = "Paused · press P or tap to resume";
    else if (!s.auto) hint = over ? "Time's up · press Space when done" : "Press Space when done";
    else if (s.target && s.duration !== null && s.hold === null) hint = "Space to finish early";
    text("clock", clock);
    text("target", target);
    text("hint", hint);
    el("clock").classList.toggle("sw-p-over", over);
    el("clock").classList.toggle("sw-p-up", up);

    var est = s.est || 0;
    var done = cumEst[idx] + Math.min(e, est), total = cumEst[cumEst.length - 1];
    el("progress").style.width = (total ? Math.min(100, 100 * done / total) : 0) + "%";
    text("times", fmt((active() - runStart) / 1000) + " · ≈ " + fmt(Math.max(0, total - done)) + " left");
  }

  function renderEnd(activeSec) {
    text("end-title", completed ? "Workout complete" : "Workout stopped");
    var last = {};
    log.forEach(function (r) { last[r.index] = r.ended; });
    var doneN = 0, skipped = 0;
    log.forEach(function (r) { if (r.ended === "skipped") skipped++; else if (r.ended !== "stopped") doneN++; });
    var wall = (finishedAt - startedAt) / 1000;
    var stats = [[fmt(activeSec), "active time"]];
    if (wall - activeSec >= 1) stats.push([fmt(wall), "with pauses"]);
    stats.push([doneN + "/" + plan.steps.length, "steps done"]);
    if (skipped) stats.push([skipped, "skipped"]);
    plan.blocks.forEach(function (b) {
      var full = 0;
      for (var r = 1; r <= b.times; r++) {
        var rows = plan.steps.filter(function (s) { return s.block === b.block && s.round_n === r; });
        if (rows.length && rows.every(function (s) { return last[s.index] === "done" || last[s.index] === "auto"; })) full++;
      }
      stats.push([full + "/" + b.times, b.label]);
    });
    el("end-stats").innerHTML = stats.map(function (x) {
      return '<div><div class="sw-stat-value">' + esc(x[0]) + '</div><div class="small text-muted">' +
        esc(x[1]) + "</div></div>";
    }).join("");
    el("end-table").innerHTML =
      '<table class="table table-sm"><thead><tr><th>Step</th><th></th><th class="text-end">Planned</th>' +
      '<th class="text-end">Actual</th><th></th></tr></thead><tbody>' +
      log.map(function (r) {
        var note = r.ended === "skipped" || r.ended === "stopped" ? r.ended : "";
        return "<tr" + (note ? ' class="text-muted"' : "") + "><td>" + esc(r.title) +
          '</td><td class="small text-muted">' + esc(r.round || "") + '</td><td class="text-end">' +
          (r.planned === null ? "–" : fmt(r.planned)) + '</td><td class="text-end">' + fmt(r.actual) +
          '</td><td class="small">' + note + "</td></tr>";
      }).join("") + "</tbody></table>";
  }

  function esc(x) {
    return String(x).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  function setState(s) {
    state = s;
    if (root) root.setAttribute("data-state", s);
  }

  function sendLog() {
    if (!window.Shiny || !log.length) return;
    var data = {
      workout: plan.name, started: iso(startedAt), finished: iso(finishedAt), completed: completed,
      active_seconds: activeTotal,
      wall_seconds: (finishedAt - startedAt) / 1000, entries: log
    };
    Shiny.setInputValue(root.dataset.swPlayer + "log", JSON.stringify(data), { priority: "event" });
  }

  // Local time, no zone: "2026-11-04T10:00:00".
  function iso(d) {
    var p = function (n) { return (n < 10 ? "0" : "") + n; };
    return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + "T" +
      p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds());
  }

  // Sound and voice ---------------------------------------------------------

  // Notes as [frequency Hz, length s]. Yoga, pilates and physio get softer sine chimes.
  var SOUNDS = {
    count: [[880, 0.08]],
    change: [[660, 0.12], [990, 0.16]],
    start: [[523, 0.12], [784, 0.2]],
    over: [[440, 0.45]],
    hold: [[784, 0.14]],
    release: [[523, 0.14]],
    finish: [[523, 0.14], [659, 0.14], [784, 0.35]]
  };

  function unlockAudio() {
    try {
      if (!audio) audio = new (window.AudioContext || window.webkitAudioContext)();
      if (audio.state === "suspended") audio.resume();
    } catch (e) { audio = null; }
  }

  function beep(name) {
    if (!name || !prefs.sound || !audio || prefs.volume <= 0) return;
    try {
      var soft = plan && plan.soft, t = audio.currentTime + 0.01;
      SOUNDS[name].forEach(function (n) {
        var o = audio.createOscillator(), g = audio.createGain();
        var len = soft ? n[1] * 4 : n[1], vol = prefs.volume * (soft ? 0.4 : 0.3);
        o.type = soft ? "sine" : "triangle";
        o.frequency.value = n[0];
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(vol, t + 0.01);
        g.gain.exponentialRampToValueAtTime(0.0001, t + len);
        o.connect(g); g.connect(audio.destination);
        o.start(t); o.stop(t + len + 0.05);
        t += n[1] + 0.04;
      });
    } catch (e) { /* no sound is better than a broken player */ }
  }

  // Browsers often default to the first voice in their list, which on a Mac is a novelty
  // voice (Albert, Bad News, ...). Pick a natural English voice instead, or the one chosen.
  var NOVELTY = /^(Albert|Bad News|Bahh|Bells|Boing|Bubbles|Cellos|Good News|Jester|Junior|Organ|Superstar|Ralph|Fred|Kathy|Trinoids|Whisper|Wobble|Zarvox|Eddy|Flo|Grandma|Grandpa|Reed|Rocko|Sandy|Shelley)\b/;
  var GOOD = /^(Daniel|Samantha|Karen|Moira|Tessa|Serena|Ava|Allison|Susan|Tom|Evan|Nathan|Zoe|Joelle|Noelle|Aaron|Nicky|Martha|Arthur|Catherine|Gordon|Lee)\b/;

  function englishVoices() {
    if (!window.speechSynthesis) return [];
    return speechSynthesis.getVoices().filter(function (v) {
      return /^en([-_]|$)/i.test(v.lang) && !NOVELTY.test(v.name);
    });
  }

  function voiceScore(v) {
    var region = (navigator.language || "en-US").replace("_", "-").toLowerCase();
    var score = 0;
    if (/premium|enhanced|natural|neural/i.test(v.name)) score += 8;
    if (GOOD.test(v.name)) score += 4;
    if (/^Google/.test(v.name)) score += 3;
    if (v.lang.replace("_", "-").toLowerCase() === region) score += 2;
    if (/^en[-_](us|gb)/i.test(v.lang)) score += 1;
    return score;
  }

  function pickVoice() {
    var voices = englishVoices();
    for (var i = 0; i < voices.length; i++) if (voices[i].name === prefs.voiceName) return voices[i];
    var best = null;
    voices.forEach(function (v) { if (!best || voiceScore(v) > voiceScore(best)) best = v; });
    return best;
  }

  function fillVoices() {
    var sel = root && root.querySelector('[data-pact="voicename"]');
    if (!sel) return;
    var voices = englishVoices().sort(function (a, b) { return voiceScore(b) - voiceScore(a) || a.name.localeCompare(b.name); });
    var auto = pickVoice();
    // Chrome fires "voiceschanged" several times; rebuilding an open menu closes it.
    var key = voices.map(function (v) { return v.name; }).join("|") + "#" + prefs.voiceName + "#" + (auto && auto.name);
    if (sel.getAttribute("data-key") === key) return;
    sel.setAttribute("data-key", key);
    sel.innerHTML = '<option value="">Automatic' + (auto && !prefs.voiceName ? " (" + esc(auto.name) + ")" : "") + "</option>" +
      voices.map(function (v) {
        return '<option value="' + esc(v.name) + '">' + esc(v.name + " · " + v.lang) + "</option>";
      }).join("");
    sel.value = voices.some(function (v) { return v.name === prefs.voiceName; }) ? prefs.voiceName : "";
  }

  var speakTimer = null;
  function speak(words) {
    if (!prefs.voice || !words || !window.speechSynthesis) return;
    try {
      // Cancel only when something is playing, and give the engine a moment before the next
      // phrase: speaking straight after cancel() can glitch or drop the phrase in Chrome.
      var busy = speechSynthesis.speaking || speechSynthesis.pending;
      if (busy) speechSynthesis.cancel();
      clearTimeout(speakTimer);
      speakTimer = setTimeout(function () {
        var u = new SpeechSynthesisUtterance(words);
        var v = pickVoice();
        if (v) { u.voice = v; u.lang = v.lang; } else u.lang = "en-US";
        u.volume = Math.max(0.1, prefs.volume);
        speechSynthesis.speak(u);
      }, busy ? 120 : 0);
    } catch (e) { /* ignore */ }
  }

  function loadPrefs() {
    var p = { sound: true, voice: false, volume: 0.8, voiceName: "" };
    try {
      var saved = JSON.parse(localStorage.getItem(PREFS_KEY) || "{}");
      if (typeof saved.sound === "boolean") p.sound = saved.sound;
      if (typeof saved.voice === "boolean") p.voice = saved.voice;
      if (typeof saved.volume === "number") p.volume = Math.min(1, Math.max(0, saved.volume));
      if (typeof saved.voiceName === "string") p.voiceName = saved.voiceName;
    } catch (e) { /* defaults */ }
    return p;
  }

  function savePrefs() {
    try { localStorage.setItem(PREFS_KEY, JSON.stringify(prefs)); } catch (e) { /* ignore */ }
    showPrefs();
  }

  function showPrefs() {
    if (!root) return;
    root.classList.toggle("sw-sound-on", prefs.sound);
    root.classList.toggle("sw-voice-on", prefs.voice);
    var v = root.querySelector('[data-pact="volume"]');
    if (v) v.value = prefs.volume;
  }

  function toggle(name) {
    prefs[name] = !prefs[name];
    savePrefs();
    unlockAudio();
    if (name === "sound" && prefs.sound) beep("count");
    if (name === "voice") {
      if (prefs.voice) { fillVoices(); speak("Voice on."); }
      else if (window.speechSynthesis) speechSynthesis.cancel();
    }
  }

  // Screen: wake lock and full screen ---------------------------------------

  function requestWake() {
    if (!("wakeLock" in navigator) || wakeLock || document.visibilityState !== "visible") return;
    navigator.wakeLock.request("screen").then(function (lock) {
      wakeLock = lock;
      lock.addEventListener("release", function () { if (wakeLock === lock) wakeLock = null; });
    }).catch(function () { /* not allowed here: the screen may sleep */ });
  }

  function releaseWake() {
    if (wakeLock) { var lock = wakeLock; wakeLock = null; lock.release().catch(function () {}); }
  }

  document.addEventListener("visibilitychange", function () {
    if (document.visibilityState === "visible" && state === "running") requestWake();
  });

  // Full screen falls back to filling the window when the browser refuses (e.g. in a frame).
  function toggleFull() {
    var on = !root.classList.contains("sw-p-full");
    root.classList.toggle("sw-p-full", on);
    if (on && root.requestFullscreen) {
      root.requestFullscreen().then(function () { realFull = true; }).catch(function () {});
    } else if (!on && document.fullscreenElement) {
      document.exitFullscreen().catch(function () {});
    }
  }

  document.addEventListener("fullscreenchange", function () {
    if (!document.fullscreenElement && realFull) { realFull = false; root.classList.remove("sw-p-full"); }
  });

  // Input -------------------------------------------------------------------

  function act(name) {
    var running = state === "running" || state === "paused";
    switch (name) {
      case "start": if (state === "ready") start(); break;
      case "done": if (state === "paused") resume(); else if (state === "running") finishStep("done", active()); break;
      case "next": if (running) finishStep("skipped", active()); break;
      case "prev": if (running) prev(); break;
      case "pause": case "tap": if (state === "running") pause(); else if (state === "paused") resume(); break;
      case "stop": if (running) askStop(); break;
      case "resume": if (state === "confirm") keepGoing(); break;
      case "end": if (state === "confirm") finish(false); break;
      case "again": if (state === "finished") close(true); break;
      case "log": if (state === "finished") sendLog(); break;
      case "edit":
        if (state === "finished") close(false);
        if (window.Shiny) Shiny.setInputValue(root.dataset.swPlayer + "edit", Date.now(), { priority: "event" });
        break;
      case "sound": case "voice": toggle(name); return;
      case "full": toggleFull(); return;
    }
    render();
  }

  var KEYS = {
    ready: { " ": "start", Enter: "start" },
    running: { " ": "done", p: "pause", ArrowLeft: "prev", ArrowRight: "next", Escape: "stop" },
    paused: { " ": "done", p: "pause", ArrowLeft: "prev", ArrowRight: "next", Escape: "stop" },
    confirm: { " ": "resume", p: "resume", Escape: "end", Enter: "end" },
    finished: {}
  };

  function visible() { return root && root.getClientRects().length > 0; }
  function isTyping(t) {
    return t && (t.isContentEditable || /^(TEXTAREA|SELECT)$/.test(t.tagName) ||
                 (t.tagName === "INPUT" && t.type !== "range"));
  }

  document.addEventListener("keydown", function (e) {
    if (!visible() || isTyping(e.target) || e.ctrlKey || e.metaKey || e.altKey) return;
    if (document.querySelector(".modal.show")) return;
    var key = e.key.length === 1 && e.key !== " " ? e.key.toLowerCase() : e.key;
    var name = (KEYS[state] || {})[key] ||
      { f: "full", s: "sound", v: "voice" }[key];
    if (!name) return;
    e.preventDefault();
    e.stopPropagation();
    if (!e.repeat) act(name);
  }, true);

  document.addEventListener("click", function (e) {
    var t = e.target.closest && e.target.closest("[data-pact]");
    if (!t || !root || !root.contains(t) || /^(INPUT|SELECT)$/.test(t.tagName)) return;
    act(t.getAttribute("data-pact"));
    if (t.blur) t.blur();   // so Space doesn't also press the focused button
  });

  document.addEventListener("input", function (e) {
    if (e.target.matches && e.target.matches('[data-pact="volume"]')) {
      prefs.volume = parseFloat(e.target.value);
      savePrefs();
    }
  });
  document.addEventListener("change", function (e) {
    if (!e.target.matches) return;
    if (e.target.matches('[data-pact="volume"]')) { unlockAudio(); beep("count"); e.target.blur(); }
    if (e.target.matches('[data-pact="voicename"]')) {
      prefs.voiceName = e.target.value;
      savePrefs();
      fillVoices();
      e.target.blur();
      var v = pickVoice();
      if (v) speak("Hello, I'm " + v.name.replace(/\s*\(.*\)$/, "") + ".");
    }
  });

  // Setup -------------------------------------------------------------------

  function init() {
    root = document.querySelector("[data-sw-player]");
    // Firefox's speech on macOS crackles at the end of every phrase, whatever the voice.
    if (root && /Firefox\//.test(navigator.userAgent)) root.classList.add("sw-firefox");
    showPrefs();
    // Voices load asynchronously in most browsers.
    if (window.speechSynthesis) {
      fillVoices();
      if (speechSynthesis.addEventListener) speechSynthesis.addEventListener("voiceschanged", fillVoices);
      else speechSynthesis.onvoiceschanged = fillVoices;
    }
    if (window.Shiny && Shiny.addCustomMessageHandler) {
      Shiny.addCustomMessageHandler("sw-player-load", function (msg) { load(msg.plan); });
    }
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();

  // For tests in the browser console: drive the clock by hand.
  window.swPlayer = {
    setClock: function (fn) { now = fn; },
    tick: tick,
    state: function () { return state; },
    log: function () { return log; },
    index: function () { return idx; },
    plan: function () { return plan; },
    active: function () { return activeTotal; },
    voice: function () { var v = pickVoice(); return v ? v.name : null; },
    act: act
  };
})();
