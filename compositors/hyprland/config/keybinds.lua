local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }))

hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))

-- Windows-style: Alt+F4 = close window
hl.bind("ALT + F4", hl.dsp.window.close())

hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- Alt+Tab window switching (Windows-style)
hl.bind("ALT + TAB", hl.dsp.exec_cmd("hyprctl dispatch cyclenext"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("hyprctl dispatch cyclenext prev"))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("atlantic brightness lower"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("atlantic brightness raise"), { locked = true })

hl.bind("Print", hl.dsp.exec_cmd("atlantic screenshot"), { locked = true })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("atlantic screenshot --edit"), { locked = true })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("atlantic screenshot --full"), { locked = true })
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("atlantic screenshot --full --edit"), { locked = true })

hl.bind("XF86PowerOff", hl.dsp.exec_cmd("atlantic lock"), { locked = true })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("atlantic lock"), { repeating = true, locked = true })

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("atlantic volume mic-toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("atlantic volume mute-toggle"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("atlantic volume lower"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("atlantic volume raise"), { repeating = true, locked = true })

hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("atlantic dashboard"))
hl.bind(mainMod .. " + SHIFT + RETURN", hl.dsp.exec_cmd(terminal))

hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("atlantic reload"))

-- Windows-style: SUPER key alone = app launcher (on release)
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("atlantic msg toggle launcher"), { release = true })

-- Windows-style: SUPER+V = clipboard (like Win+V)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("atlantic msg toggle clipboard"))

hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("atlantic msg toggle music"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("atlantic msg toggle system"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("atlantic msg toggle wallpaper"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("atlantic msg toggle calendar"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("atlantic msg toggle network"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("atlantic msg toggle volume"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("atlantic msg toggle guide"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("atlantic msg toggle autohide"))

for i = 1, 10 do
  local ws = tostring(i)
  local key = tostring(i % 10)
  hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("atlantic msg workspace " .. ws))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("atlantic msg workspace " .. ws .. " move"))
end
