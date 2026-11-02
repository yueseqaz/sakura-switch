# Manual Test Checklist

Behaviors that cannot be covered by unit tests (Accessibility, Screen
Recording, global keyboard interaction). Run through this list before a
release. Build: `bash scripts/build-app.sh <version>` then open the app.

> Unsigned-app reminder: after recompiling, macOS may require re-granting
> **System Settings → Privacy & Security → Accessibility**.

## 1. Launch & menu bar

- [ ] App launches with no Dock icon (LSUIElement) and shows the sakura
      status item.
- [ ] Menu: *Open Switcher / Settings… / About / Quit* — all localized
      (switch 语言 in Settings → 通用 between 跟随系统 / 简体中文 / English and
      reopen the menu).
- [ ] *Settings…* opens the 8-tab window; switching tabs keeps the window
      centered and sized.

## 2. Permissions

- [ ] With Accessibility **not** granted: pressing the global hotkey shows
      the frosted hint panel; *打开系统设置* opens the Accessibility pane;
      *稍后再说* dismisses; Esc/Return dismiss.
- [ ] After granting Accessibility, the switcher works **without
      restarting the app** (permission is re-checked on every invocation).
- [ ] **macOS 26/27 (Tahoe)**: if the toggle is ON but the menu bar still
      shows the ⚠️ item, remove the entry with −, reboot, re-add and
      re-enable; optionally `sudo tccutil reset Accessibility`. The menu bar
      item must disappear once the grant is truly active.
- [ ] Settings → 权限 shows live status for both permissions; 重新检测
      updates in place; the unsigned-app note is visible.

## 3. Global hotkey (default ⌥Tab)

- [ ] Panel appears centered slightly below middle, on the screen with the
      mouse.
- [ ] Selection starts at the second MRU entry (cmd-tab style).
- [ ] Tapping ⌥Tab again cycles forward; ⇧⌥Tab cycles backward.
- [ ] Releasing ⌥ confirms the highlighted window (unminimizes, activates,
      raises, focuses).
- [ ] Esc cancels; clicking outside the panel dismisses.
- [ ] The panel works over fullscreen apps (Space transition is performed
      by the system; failures logged, never crashing).

## 4. In-app hotkey (default ⌥`)

- [ ] Only windows of the frontmost app are listed.
- [ ] Same cycling/confirm/cancel semantics as the global panel.

## 5. View modes (Settings → 外观)

- [ ] 缩略图: live window thumbnails; without Screen Recording permission
      the app icon shows as an inset placeholder; granting permission and
      re-invoking shows captures.
- [ ] 应用图标: icon grid, truncating titles, selection ring.
- [ ] 标题列表: compact rows, hover selects, click switches.
- [ ] Switching modes applies immediately on the next invocation; panel
      size adapts per mode; thumbnail size 小/中/大 changes cell metrics.

## 6. Search

- [ ] Typing filters by app name, window title and bundle ID; matches are
      highlighted in accent color.
- [ ] Subsequence matching: `vs` finds Visual Studio Code.
- [ ] Empty query restores the MRU list.
- [ ] Digit keys 1–9 jump while the query is empty; with text in the field
      digits type normally.
- [ ] Chinese input: the field accepts IME composition; arrow/Enter keys
      drive the candidate window instead of the list until committed.
- [ ] Search memory: select a window for a query; re-invoking and typing
      the same query ranks it first (Settings → 搜索 → 清除搜索记忆 resets).
- [ ] Disabling 模糊搜索 falls back to substring matching.

## 7. Quick actions (with the panel open)

- [ ] `⌘W` closes the selected window (panel refreshes and closes).
- [ ] `⌘M` minimizes; `⌘F` toggles fullscreen; `⌘H` hides the app.
- [ ] `⌘Q` quits the app (confirmation via the app's own dialog if any).
- [ ] `⌘R` reveals the document in Finder for file windows (e.g. a text
      editor's window); no-op with a friendly log otherwise.
- [ ] `⌘,` opens Settings.

## 8. Badges & filters

- [ ] Minimized windows show ⊖; fullscreen show ⤢; other-Space windows show
      ◻ — all still switchable.
- [ ] Settings → 窗口行为 toggles hide/show minimized, fullscreen and
      other-Space windows immediately.
- [ ] 仅列出当前屏幕上的窗口 restricts the list to the mouse screen.
- [ ] Settings → 排除列表: add an invalid bundle ID shows an inline error;
      adding a valid ID hides that app's windows immediately; − removes.

## 9. Multi-display

- [ ] With two displays, the panel follows the mouse across screens.
- [ ] Hotkey panel on a display with only external windows lists those
      windows (with screen filtering on).

## 10. Appearance

- [ ] Light / Dark / System theme applies to the panel and Settings
      immediately; text stays WCAG-AA readable in both modes.
- [ ] 面板背景 material variants (深色毛玻璃 / 浅色毛玻璃 / 中性毛玻璃)
      visibly change the panel.
- [ ] Hover, selection, disabled (e.g. 清除搜索记忆 with an empty memory)
      and error states are all distinguishable without relying on hover.

## 11. Stability

- [ ] Open the panel rapidly 10× — no leak of event taps or monitors
      (keyboard returns to other apps after each dismiss).
- [ ] Quit from the menu bar while the panel is open — clean exit.
- [ ] With ~30 windows open the panel appears within ~100 ms from cache
      and refreshes in the background.
