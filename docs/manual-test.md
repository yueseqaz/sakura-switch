# Manual Test Checklist

Behaviors that cannot be covered by unit tests (Accessibility, Screen
Recording, global keyboard interaction). Run through this list before a
release. Build: `bash scripts/build-app.sh <version>` then open the app.

> Ad-hoc signing reminder: after recompiling, macOS may require removing the old
> permission entry and adding the installed app again under
> **System Settings → Privacy & Security → Accessibility** (or **Device Control & Data Access**).

## 1. Launch & menu bar

- [ ] App launches with no Dock icon (LSUIElement) and shows the sakura
      status item.
- [ ] Menu: *Open Switcher / Settings… / About / Quit* — all localized
      (switch 语言 in Settings → 通用 between 跟随系统 / 简体中文 / English and
      reopen the menu).
- [ ] *Settings…* opens the 8-tab window; switching tabs keeps the window
      centered and sized.

## 2. Permissions

- [ ] `codesign --verify --strict --all-architectures build/SakuraSwitch.app`
      succeeds; `codesign -dv build/SakuraSwitch.app` reports the bundle identifier
      `com.yueseqaz.sakuraswitch` and a bound Info.plist.
- [ ] With Accessibility **not** granted: pressing the global hotkey shows
      the frosted hint panel; *打开系统设置* requests permission for the running app
      and opens System Settings;
      *稍后再说* dismisses; Esc/Return dismiss.
- [ ] After granting Accessibility, the switcher works **without
      restarting the app** (permission is re-checked on every invocation).
- [ ] Settings → 权限 shows live status for both permissions; 重新检测
      updates in place; returning from System Settings refreshes automatically.
- [ ] Revoking Accessibility while the permissions tab is visible changes its
      status to 未授权; the next switcher invocation shows the hint.
- [ ] The Screen Recording button triggers the native permission request on a
      clean install; returning to Settings updates its status (restart if macOS
      requires it). Opening Settings alone does not request Screen Recording.

## 3. Global hotkey (default ⌥Tab)

- [ ] Panel appears centered slightly below middle, on the screen with the
      mouse.
- [ ] Selection starts at the second MRU entry (cmd-tab style).
- [ ] Tapping ⌥Tab again cycles forward; ⇧⌥Tab cycles backward.
- [ ] Keep Option physically held and press/release Tab at least five times:
      one window per press, wrapping at the end, without hiding the panel.
      Option+arrows, Option+Enter and Option+Esc also work while Option stays held.
- [ ] On the first invocation after launch, a quick Option+Tab release still
      activates the second MRU window once enumeration finishes.
- [ ] Settings → Hotkeys → 松开修饰键时: “切换并关闭面板” keeps the current
      behavior; “保留面板打开” leaves the selected window and panel visible after
      Option is released. Enter or clicking a window still confirms and closes it.
- [ ] Open Switcher from the menu: pressing/releasing Option alone does not
      confirm or dismiss it; Tab and Shift+Tab still browse.
- [ ] Releasing ⌥ confirms the highlighted window (unminimizes, activates,
      raises, focuses).
- [ ] Esc cancels; clicking outside the panel dismisses.
- [ ] The panel works over fullscreen apps (Space transition is performed
      by the system; failures logged, never crashing).

## 4. In-app hotkey (default ⌥`)

- [ ] Only windows of the frontmost app are listed.
- [ ] Same cycling/confirm/cancel semantics as the global panel.

## 5. View modes (Settings → 外观)

- [ ] The application strip shows one icon per application with its window count.
      Hover an app for about 180 ms: the grid shows only that app's windows as
      thumbnails, including multiple windows of the same app.
- [ ] Moving from the app icon into its window previews keeps that group open;
      click a preview to activate that exact window. All Windows or Esc returns
      to the full list. Moving quickly across icons does not open stale groups.
- [ ] Select a thumbnail with Tab or Shift+Tab and stop for about half a second:
      a much larger preview appears without moving the grid or stealing keyboard
      focus. Press Tab again or dismiss the switcher: the preview closes.
      The mouse can remain anywhere; moving it does not control the preview.
- [ ] Move quickly between thumbnails, change app groups and scroll: no stale
      enlarged preview remains. A preview at a screen edge stays within that
      screen's visible area; without recording permission it shows a clear hint.
- [ ] Hovering another app keeps the icon strip under the pointer, even when
      the preview grid changes height. Overflowing app icons scroll horizontally;
      overflowing window previews scroll vertically.
- [ ] Without Screen Recording permission the switcher shows a permission action
      and explicit placeholders. Clicking the action requests permission; granting
      it and reopening retries captures for the same windows.
- [ ] Starting with an empty window cache, opening the switcher fills the visible
      grid as soon as background enumeration completes without a second invocation.
- [ ] Run `swift run SakuraSwitch --self-test --self-test-live` with both permissions
      granted. Its output reports real windows and a nonzero `thumbnails` count;
      `--self-test-app com.apple.finder` scopes this check to Finder's windows.
- [ ] 缩略图: live window thumbnails; without Screen Recording permission
      the app icon shows as an inset placeholder; granting permission and
      re-invoking shows captures.
- [ ] Thumbnail cards preserve each source window's aspect ratio: a portrait
      window is taller and a wide window is shorter at the same card width;
      captures are requested using that ratio rather than one fixed height.
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
