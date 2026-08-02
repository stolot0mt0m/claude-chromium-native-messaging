# Vivaldi: "No active tab" — root cause and fix

The README's Web Panel workaround gets the Claude panel to **render** in Vivaldi,
but the panel is not functional: typing a message and pressing Enter clears the
composer and nothing is sent. The panel console shows:

```
Uncaught (in promise) Error: No active tab
    at assets/sidepanel-<hash>.js
```

This document explains why, and what `patch-vivaldi.sh` / `patch-vivaldi.ps1` do
about it.

**Credit:** the diagnosis below was contributed by a user who traced it through
the deminified extension bundle on macOS. It was independently re-verified
against Claude extension `1.0.84` (`fcoeoabgfenejglbffodgkkbkcdhcgfn`) as
installed by Vivaldi stable.

## Not the cause

Each of these was tested and eliminated, so nobody has to repeat the work:

| Hypothesis | Evidence against |
|---|---|
| A Web Panel isn't a real extension context | `chrome.runtime.id` returns the correct ID; `typeof chrome.tabs` is `"object"`; `chrome.runtime.sendMessage({ping:1})` resolves |
| Service worker dead or unregistered | The worker is alive and logging; `chrome.tabs.onActivated` listeners fire normally |
| CSP inline-script failure ([claude-code#35871](https://github.com/anthropics/claude-code/issues/35871)) | The panel initialises fine; unrelated to the submit path |
| Tracker blocking (`api.segment.io` → `ERR_BLOCKED_BY_CLIENT`) | Telemetry only; does not gate submit |
| Bridge feature flag (`chrome_ext_bridge_enabled`) | The extension *does* attempt `wss://bridge.claudeusercontent.com`; unrelated to chat |
| Focus-based tab lookup | `lastFocusedWindow` appears nowhere in the extension bundle |
| Panel is its own window, breaking `currentWindow` | From the panel context, `chrome.windows.getCurrent` returns the normal browser window, and `chrome.tabs.query({active:true, currentWindow:true})` correctly returns the active tab |

## Root cause

### The panel resolves its tab from exactly two sources

Deminified from `assets/sidepanel-<hash>.js`, running once in a `useEffect` at
mount:

```js
const e = new URLSearchParams(window.location.search), i = e.get("tabId");
let o;
if (i) {
  o = parseInt(i);
} else if ("window" === e.get("mode")) {
  const e = await $(A.TARGET_TAB_ID);   // chrome.storage.local, key "targetTabId"
  e && (o = e);
}
s(o);   // → React state, referenced downstream as `l`
```

Two branches, no fallback. There is no `chrome.tabs.query` path.

### The guard that throws

```js
dt = useCallback(async (e, t, s, a, c, d = false) => {
  if (!we.current) throw new Error("Client not initialized");
  if (!l)          throw new Error("No active tab");
  ...
```

`l` is used downstream as `await chrome.tabs.get(l)`,
`H.getValidTabsWithMetadata(l)`, and `J(Ie.current, {tabId: l})`. The throw
surfaces at click time, but the cause is at load time.

### Why the Web Panel never populates it

In Chrome, the service worker injects the tab ID into the panel URL, per tab:

```js
chrome.sidePanel.setOptions({
  tabId: e,
  path: `sidepanel.html?tabId=${encodeURIComponent(e)}`,
  enabled: true,
});
```

Vivaldi ignores `chrome.sidePanel.setOptions` ([VB-120826]). The README's Web
Panel workaround sidesteps that by loading `sidepanel.html` directly — but that
is a frozen string with no query parameters. In the panel console,
`location.search` is `""`.

So `tabId` is absent (branch 1 skipped), `mode` is absent (branch 2 skipped),
the tab ID stays `undefined`, and every send throws.

### The second branch is a real, usable code path

`TARGET_TAB_ID` is `chrome.storage.local` key `"targetTabId"`. The stock
extension writes it in exactly one place — the scheduled-task launcher in the
service worker, which writes it once when it opens a dedicated task window:

```js
await m.createGroup(o.id);
await d(i.TARGET_TAB_ID, o.id);
const o = chrome.runtime.getURL(`sidepanel.html?mode=window&sessionId=${t}...`);
await chrome.windows.create({ ... });
```

Nothing keeps it current — there is no `tabs.onActivated` listener anywhere in
the service worker bundle. That is the only gap between the existing code path
and a working Vivaldi panel.

## Why the other workarounds don't fix it

- **Web Panel with a bare URL** (the previous README advice) — this *is* the bug.
- **Static `side_panel.default_path` manifest patch**
  ([bigbrojake/claude-extension-vivaldi-fix]) — fixes *rendering* via Vivaldi's
  native side panel, but a static manifest path has no query string by
  definition, so it lands on the same `No active tab` throw.
- **Appending `?tabId=<n>` by hand** — works, but pins the panel to one tab ID,
  and tab IDs are regenerated on browser restart.

## The fix

Two parts, both applied by `patch-vivaldi.sh` (and `patch-vivaldi.ps1`):

**1. Open the panel on the `mode=window` branch:**

```
chrome-extension://fcoeoabgfenejglbffodgkkbkcdhcgfn/sidepanel.html?mode=window&sessionId=vivaldi-panel
```

`sessionId` is not needed for chat, but `EXECUTE_TASK` routing bails on
`mode=window` without one, so it is cheap to satisfy.

**2. Keep `targetTabId` current** with a wrapper service worker.

MV3 allows exactly one service worker, so the patch does not replace the
extension's worker — it adds `tabbind.js`, which `import`s the original
untouched and appends the listeners the stock build lacks:

```js
import './service-worker-loader.js';

chrome.tabs.onActivated.addListener(({ tabId }) => bindIfWebTab(tabId));
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => { ... });
chrome.windows.onFocusChanged.addListener(...);
chrome.runtime.onStartup.addListener(bindActiveTab);
void bindActiveTab();
```

and points `manifest.json` at it.

`chrome.tabs.onActivated` does fire correctly in Vivaldi:

```
activated {tabId: 1990186690, windowId: 1990184788}
activated {tabId: 1990185069, windowId: 1990184788}
```

### Design notes

- **Loader wrapper, not replacement.** `"background": {"type": "module"}` is
  required for the `import` — the stock manifest already sets it.
- **`"key"` is preserved**, so the unpacked copy keeps extension ID
  `fcoeoabgfenejglbffodgkkbkcdhcgfn` and the native messaging manifests written
  by `setup.sh` keep matching it. No reconfiguration needed.
- **`update_url` is removed** so the browser does not try to auto-update an
  unpacked extension.
- **`_metadata/` is removed** — those are Web Store signatures that do not apply
  to an unpacked copy.
- **`https?:` guard** avoids binding to `vivaldi://`, `chrome-extension://`, or
  blank tabs.
- **Binds on worker wake, not just on tab switch** — tab IDs are regenerated on
  browser restart, so waiting for the first tab switch would leave a stale ID in
  storage.
- **`chrome.storage.local` only.** The panel and the worker both read and write
  `local`; neither uses `session` or `sync`.

### Freshness caveat

The panel reads `targetTabId` **once, when the panel document loads** — there is
no `storage.onChanged` listener for that key in the panel bundle. So the patch
guarantees that a panel loaded now binds to the tab that is active now; it does
not retarget a panel that is already open. Reload the Web Panel to re-bind it to
the current tab.

This mirrors Chrome, where the side panel is per-tab by construction.

## Manual steps (can't be scripted)

1. `vivaldi://extensions` → **disable** (do not remove) the Web Store copy. Both
   copies claim the same ID, so leaving it enabled causes a duplicate-ID error.
   Leaving it installed-but-disabled is deliberate: it keeps auto-updating and
   serves as the source for re-patching.
2. Developer mode ON → **Load unpacked** → the patched folder.
3. Add the Web Panel with the `?mode=window&sessionId=vivaldi-panel` URL above.

## Verification

From the extension's service worker console (`vivaldi://extensions` → the
unpacked Claude entry → **service worker**):

```js
chrome.storage.local.get('targetTabId').then(console.log)
```

The value should change as you switch tabs. Then reload the Web Panel on a
different site and ask Claude what page you are on — it should name the new
page. Restart Vivaldi and repeat, to confirm the `onStartup` path.

## Version drift

The patched copy is a snapshot. When the disabled store copy auto-updates, the
patched copy is left behind:

```bash
./patch-vivaldi.sh --check   # exit 0 = up to date, 1 = stale
./patch-vivaldi.sh           # rebuild
```

The script derives the worker filename from `manifest.json` rather than
hardcoding a build hash, so re-running is all that is needed.

## Upstream

The real fix belongs in the extension — a third fallback branch in the resolver:

```js
if (i) o = parseInt(i);
else if ("window" === e.get("mode")) { /* storage */ }
else { const [t] = await chrome.tabs.query({active:true, currentWindow:true}); o = t?.id; }
```

`currentWindow` demonstrably resolves correctly from the panel document context
in Vivaldi. Three lines upstream would fix Vivaldi, Arc, and every other fork at
once, and make this patch unnecessary.

## Open questions

- **Other forks.** Any Chromium fork that ignores dynamic `setOptions` hits this
  identically. Arc is the obvious candidate — [Zu9zwan9/claude-in-arc] solves it
  with a `chrome.sidePanel` polyfill that opens a popup window, which is heavier
  than this patch. Whether `mode=window` + storage binding is a simpler
  universal answer is untested; `patch-vivaldi.sh --browser arc` exists so it
  can be tried.
- **Tab grouping.** The scheduled-task launcher calls `createGroup()` before
  writing `TARGET_TAB_ID`, and the resolver follows with `isInGroup()` /
  `isMainTab()`. Chat works without a group, but tab-orchestration features may
  expect one. Untested.
- **`chrome_ext_bridge_enabled`.** The extension *attempted* the
  `wss://bridge.claudeusercontent.com` connection during diagnosis (it failed on
  local DNS), which suggests the flag may not be `false` for Vivaldi as the
  README states elsewhere. Worth re-checking independently.

## Related

- [claude-code#30873](https://github.com/anthropics/claude-code/issues/30873) — shows the `setOptions({tabId, path: 'sidepanel.html?tabId=...'})` call
- [claude-code#34062](https://github.com/anthropics/claude-code/issues/34062) — Vivaldi extension rendering failure
- [claude-code#35871](https://github.com/anthropics/claude-code/issues/35871) — CSP + "Receiving end does not exist" (distinct issue)
- [bigbrojake/claude-extension-vivaldi-fix] — static `default_path` rendering fix
- [Zu9zwan9/claude-in-arc] — `chrome.sidePanel` polyfill approach

[VB-120826]: https://bugs.vivaldi.com/
[bigbrojake/claude-extension-vivaldi-fix]: https://github.com/bigbrojake/claude-extension-vivaldi-fix
[Zu9zwan9/claude-in-arc]: https://github.com/Zu9zwan9/claude-in-arc
