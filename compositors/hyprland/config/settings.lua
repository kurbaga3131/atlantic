hl.config({
  general = {
    border_size = 0,
    gaps_in = 4,
    gaps_out = 6,
    float_gaps = 6,
    resize_on_border = true,
    extend_border_grab_area = 30,
  },

  decoration = {
    rounding = 12,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    blur = {
      enabled = true,
      size = 8,
      passes = 3,
      new_optimizations = true,
      ignore_opacity = true,
    },
    shadow = {
      enabled = false,
    },
  },

  input = {
    kb_layout = "tr",
    kb_options = "grp:alt_shift_toggle",
    accel_profile = "flat",
    sensitivity = 0.0,
    touchpad = {
      natural_scroll = true,
      disable_while_typing = false,
    },
  },

  misc = {
    focus_on_activate = false,
    font_family = "JetBrains Mono",
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },

  ecosystem = {
    no_update_news = true,
    no_donation_nag = true,
  },
})

hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "myBezier", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "myBezier", style = "popin 80%" })
hl.animation({ leaf = "layers", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "myBezier" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "myBezier", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 5, bezier = "myBezier", style = "fade" })

-- Window rules for Steam updater & dialogs
hl.window_rule({
  match = {
    class = "(?i)steam",
    title = "(?i)updating steam.*",
  },
  float = true,
  center = true,
})

hl.window_rule({
  match = {
    class = "(?i)zenity",
  },
  float = true,
  center = true,
  opacity = "0.90 0.85",
})

hl.window_rule({
  match = {
    class = "steam-installer",
  },
  float = true,
  center = true,
})

-- System applications dark glass transparency rules
hl.window_rule({
  match = {
    class = "(?i)(org\\.gnome\\.nautilus|nautilus)",
  },
  opacity = "0.85 0.78",
})

hl.window_rule({
  match = {
    class = "(?i)thunar",
  },
  opacity = "0.85 0.78",
})

hl.window_rule({
  match = {
    class = "(?i)(pavucontrol|org\\.pulseaudio\\.pavucontrol)",
  },
  float = true,
  center = true,
  opacity = "0.86 0.78",
})

hl.window_rule({
  match = {
    class = "(?i)easyeffects",
  },
  opacity = "0.88 0.80",
})

hl.window_rule({
  match = {
    class = "(?i)(nm-connection-editor|blueman-manager)",
  },
  float = true,
  center = true,
  opacity = "0.86 0.78",
})



