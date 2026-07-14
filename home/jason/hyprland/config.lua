-- Jason's approachable Hyprland configuration.
-- Super or Super+Space opens the launcher; Super+/ shows every essential key.

local home = os.getenv("HOME")

-- Caelestia rewrites this palette whenever the wallpaper or scheme changes.
-- The fallback makes the first frame pleasant before the initial palette exists.
local scheme = {
    primary = "b4befe",
    onSurfaceVariant = "a6adc8",
    shadow = "000000",
}
local chunk = loadfile(home .. "/.config/hypr/scheme/current.lua")
if chunk then
    local ok, generated = pcall(chunk)
    if ok and type(generated) == "table" then scheme = generated end
end

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.config({
    general = {
        layout = "dwindle",
        gaps_in = 6,
        gaps_out = 12,
        border_size = 2,
        resize_on_border = true,
        allow_tearing = false,
        col = {
            active_border = "rgba(" .. scheme.primary .. "ee)",
            inactive_border = "rgba(" .. scheme.onSurfaceVariant .. "33)",
        },
    },
    decoration = {
        rounding = 14,
        active_opacity = 0.96,
        inactive_opacity = 0.90,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            new_optimizations = true,
            ignore_opacity = true,
            popups = true,
        },
        shadow = {
            enabled = true,
            range = 18,
            render_power = 3,
            color = "rgba(" .. scheme.shadow .. "66)",
        },
    },
    input = {
        kb_layout = "us",
        repeat_delay = 250,
        repeat_rate = 35,
        follow_mouse = 1,
        touchpad = {
            tap_to_click = false,
            tap_and_drag = false,
            natural_scroll = true,
            disable_while_typing = false,
            clickfinger_behavior = true,
            scroll_factor = 0.3,
        },
    },
    dwindle = {
        preserve_split = true,
        smart_split = false,
        smart_resizing = true,
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        focus_on_activate = true,
    },
    xwayland = {
        force_zero_scaling = true,
    },
})

-- Smooth but quick animations: visible enough to feel special, never sluggish.
hl.curve("easeOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("easeInOut", { type = "bezier", points = { { 0.65, 0 }, { 0.35, 1 } } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "easeOut", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "easeOut", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeInOut", style = "slide" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "easeOut", style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "easeOut", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "easeOut" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

local function command(value)
    return hl.dsp.exec_cmd(value)
end

local function bind(keys, dispatcher, description, flags)
    flags = flags or {}
    flags.description = description
    hl.bind(keys, dispatcher, flags)
end

-- The two launcher bindings make Hyprland immediately navigable.
bind("SUPER + SUPER_L", hl.dsp.global("caelestia:launcher"), "Open launcher", { release = true })
bind("SUPER + Space", hl.dsp.global("caelestia:launcher"), "Open launcher")
bind("SUPER + slash", command("hyprland-shortcuts"), "Show shortcut guide")
bind("CTRL + ALT + Delete", hl.dsp.global("caelestia:session"), "Open session and power menu")
bind("SUPER + L", command("lock-hyprland"), "Lock the laptop")

-- Familiar application shortcuts.
bind("SUPER + Return", command("ghostty"), "Open Ghostty terminal")
bind("SUPER + T", command("ghostty"), "Open Ghostty terminal")
bind("SUPER + B", command("brave"), "Open Brave browser")
bind("SUPER + E", command("nautilus --new-window"), "Open Files")
bind("SUPER + V", command("caelestia clipboard"), "Open clipboard history")
bind("SUPER + Period", command("caelestia emoji -p"), "Open emoji picker")

-- Window management starts with arrow keys instead of requiring Vim habits.
bind("SUPER + Q", hl.dsp.window.close(), "Close focused window")
bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized" }), "Maximize or restore window")
bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Toggle true fullscreen")
bind("SUPER + SHIFT + Space", hl.dsp.window.float(), "Toggle floating window")
bind("SUPER + Tab", hl.dsp.window.cycle_next(), "Cycle through windows")

for _, item in ipairs({
    { key = "left", direction = "left" },
    { key = "right", direction = "right" },
    { key = "up", direction = "up" },
    { key = "down", direction = "down" },
}) do
    bind("SUPER + " .. item.key, hl.dsp.focus({ direction = item.direction }), "Focus " .. item.direction)
    bind("SUPER + SHIFT + " .. item.key, hl.dsp.window.move({ direction = item.direction }), "Move window " .. item.direction)
end

bind("SUPER + ALT + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), "Shrink window horizontally", { repeating = true })
bind("SUPER + ALT + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), "Grow window horizontally", { repeating = true })
bind("SUPER + ALT + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), "Shrink window vertically", { repeating = true })
bind("SUPER + ALT + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), "Grow window vertically", { repeating = true })
bind("SUPER + mouse:272", hl.dsp.window.drag(), "Move window with mouse", { mouse = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), "Resize window with mouse", { mouse = true })

for workspace = 1, 9 do
    local key = tostring(workspace)
    bind("SUPER + " .. key, hl.dsp.focus({ workspace = key }), "Open workspace " .. key)
    bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = key }), "Move window to workspace " .. key)
end

-- Hardware keys and screenshots keep working even while a lock is active.
bind("Print", command("caelestia screenshot"), "Capture a selected area", { locked = true })
bind("XF86AudioMute", command("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), "Mute audio", { locked = true })
bind("XF86AudioMicMute", command("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), "Mute microphone", { locked = true })
bind("XF86AudioRaiseVolume", command("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), "Raise volume", { locked = true, repeating = true })
bind("XF86AudioLowerVolume", command("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), "Lower volume", { locked = true, repeating = true })
bind("XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"), "Raise brightness", { locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"), "Lower brightness", { locked = true, repeating = true })
