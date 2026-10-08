#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
run_node_test <<'JS'
const strict = require('node:assert/strict')
const fs = require('fs')
const os = require('os')
const vm = require('vm')
const child = require('child_process')
const qml = fs.readFileSync(path.join(root, 'shell/plugins/lock/Service.qml'), 'utf8')

function functionText(source, start) {
  const open = source.indexOf('{', start)
  let depth = 1
  let end = open + 1
  // The selected production functions contain no braces in string literals.
  while (depth && end < source.length) {
    if (source[end] === '{') depth++
    if (source[end] === '}') depth--
    end++
  }
  strict.strictEqual(depth, 0)
  return source.slice(start, end)
}

function fixture(source) {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'omarchy-lock-intent-'))
  const marker = path.join(home, '.local/state/omarchy/session-guard/locked')
  const timer = () => ({ running: false, stop() {}, start() {}, restart() {} })
  const ctx = {
    passwordPamConfigured: true, lockRequested: false, lockIntentReady: false, lockGeneration: '',
    armIntentOutput: { text: '' },
    pendingSessionLock: false, fingerprintConfigured: false,
    sessionLock: { locked: false, secure: false },
    sessionLockStabilizeTimer: timer(), pendingSessionLockTimer: timer(),
    fingerprintRetryTimer: timer(), idleBlankTimer: timer(),
    resetAuthenticationState() {}, armBlankTimer() {}, logEvent() {}, runWake() {},
    refreshBackground() {}, refreshFingerprintStatus() {}, hasRealScreen() { return true },
    Qt: { callLater(fn) { fn() } }, PamResult: { Success: 0 },
    queueSessionLock() {
      strict(fs.existsSync(marker), 'intent must exist before a lock request reaches the compositor')
      ctx.requestSessionLock()
    },
  }
  ctx.root = ctx
  Object.defineProperty(ctx, 'locked', { get() { return ctx.lockRequested || ctx.sessionLock.locked } })
  vm.createContext(ctx)
  for (const name of ['beginLock', 'beginSecureLock', 'finishUnlock', 'finishAuthenticatedUnlock', 'requestSessionLock', 'handleFingerprintFinished']) {
    const start = source.indexOf('function ' + name + '(')
    if (start >= 0) vm.runInContext(functionText(source, start), ctx)
  }
  for (const [id, mode] of [['armIntentProcess', '--arm'], ['clearIntentProcess', '--prepare-unlock'], ['releaseIntentProcess', '--clear']]) {
    const idStart = source.indexOf('id: ' + id)
    let callback = () => {}
    if (idStart >= 0) {
      const start = source.indexOf('function(exitCode, exitStatus)', idStart)
      callback = vm.runInContext('(' + functionText(source, start) + ')', ctx)
    }
    const process = { active: false }
    Object.defineProperty(process, 'running', {
      get() { return process.active },
      set(value) {
        process.active = value
        if (!value) return
        if (id === 'releaseIntentProcess') strict.strictEqual(ctx.sessionLock.locked, false, 'intent cleanup only starts after the protocol unlock')
        const generation = id === 'releaseIntentProcess' ? process.generation : ctx.lockGeneration
        const arguments = mode === '--arm' ? [mode] : [mode, generation]
        const result = child.spawnSync(path.join(root, 'bin/omarchy-session-guard'), arguments, {
          env: { ...global.process.env, HOME: home, OMARCHY_PATH: root }, encoding: 'utf8',
        })
        if (id === 'armIntentProcess') ctx.armIntentOutput.text = result.stdout
        process.active = false
        callback(result.status, result.signal ? 1 : 0)
      },
    })
    ctx[id] = process
  }
  return { ctx, home, marker, cleanup() { fs.rmSync(home, { recursive: true, force: true }) } }
}

let f = fixture(qml)
try {
  strict.strictEqual(f.ctx.beginLock(), true)
  strict.strictEqual(f.ctx.sessionLock.locked, true)
  strict(fs.existsSync(f.marker))
  // A refused fingerprint does not clear durable intent or the protocol lock.
  f.ctx.handleFingerprintFinished(1)
  strict(fs.existsSync(f.marker))
  strict.strictEqual(f.ctx.sessionLock.locked, true)
  f.ctx.handleFingerprintFinished(0)
  strict.strictEqual(f.ctx.sessionLock.locked, false)
  strict(!fs.existsSync(f.marker))
} finally { f.cleanup() }

f = fixture(qml)
try {
  f.ctx.beginLock()
  fs.unlinkSync(f.marker)
  fs.mkdirSync(f.marker)
  f.ctx.finishUnlock()
  strict.strictEqual(f.ctx.sessionLock.locked, true, 'failed intent clearing keeps the protocol lock')
  strict(fs.existsSync(f.marker))
} finally { f.cleanup() }

f = fixture(qml)
try {
  const directory = path.dirname(f.marker)
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 })
  fs.chmodSync(directory, 0o755)
  f.ctx.beginLock()
  strict.strictEqual(f.ctx.sessionLock.locked, false, 'failed intent persistence never requests a secure lock')
  strict.strictEqual(f.ctx.lockRequested, false)
} finally { f.cleanup() }

if (global.process.env.OMARCHY_LOCK_OLD_SOURCE) {
  f = fixture(fs.readFileSync(global.process.env.OMARCHY_LOCK_OLD_SOURCE, 'utf8'))
  try {
    strict.throws(() => f.ctx.beginLock(), /intent must exist/, 'old production beginLock reaches the compositor without durable intent')
  } finally { f.cleanup() }
}
JS
