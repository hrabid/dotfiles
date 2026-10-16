local options = require 'mp.options'

-- Every option can be overridden in script-opts/ytosc.conf (see README).
local C = {
    -- appearance and behaviour
    scale = 1,
    hide_timeout = 2,
    hide_when_paused = true,      -- true: controls hide when the mouse is idle, even while paused
    reveal_area = "bottom",       -- bottom: controls appear only when the mouse is near the bottom edge
                                  -- window: they appear when the mouse moves anywhere in the window
    reveal_height = 150,          -- height of the bottom reveal zone in pixels (at scale 1)
    always_visible = false,       -- true: controls never auto-hide (and the mouse cursor stays visible)
    progress_line = false,        -- true: a thin progress line stays at the bottom while the controls are hidden
    scrub_mode = "live",          -- live | release
    double_click_seek = 10,
    wheel_seek = 5,
    volume_step = 5,
    font = "sans-serif",
    scrim_alpha = 0.7,
    panel_alpha = 0.92,
    window_controls = "auto",     -- auto | yes | no (min/max/close; auto = only when border=no)
    touch_mode = "no",            -- yes = larger touch targets
    debug = false,                -- draw hit regions

    -- keys
    timeoutlen = 600,             -- ms to wait for the next key of a chord (gg, ZZ, ...)
    keymap = "vim",               -- vim | mpv (mpv = ytosc binds no keys)

    -- opening media
    media_extensions = "mkv,mp4,avi,mov,webm,m4v,flv,wmv,ts,m2ts,mpg,mpeg,ogv,3gp,mp3,flac,ogg,opus,m4a,wav,aac,wma,mka",
    recursive_dir = false,
    autoload_dir = true,          -- opening one file loads its folder as the playlist
    picker = "auto",              -- auto | portal | zenity | kdialog | yad | prompt
    picker_file = "",             -- custom picker command (prints one path per line); empty = auto-detect
    picker_dir = "",

    -- previews
    thumbnails = "auto",          -- seekbar previews through thumbfast: auto | no
    strip_thumbnails = true,      -- thumbnails on the More videos cards (needs ffmpeg)
    strip_sources = "playlist,dir,recent",

    -- view modes
    mini_size = "480x270",
    mini_corner = "bottom-right", -- top-left | top-right | bottom-left | bottom-right
    mini_margin = 20,

    -- files
    colors_file = "~~/script-opts/ytosc-colors.conf",
    keys_file = "~~/script-opts/ytosc-keys.conf",
}

options.read_options(C, "ytosc")
return C
