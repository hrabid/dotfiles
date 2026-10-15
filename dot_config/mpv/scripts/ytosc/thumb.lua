-- thumbfast bridge (https://github.com/po5/thumbfast): seekbar hover previews.
local utils = require 'mp.utils'
local C = require 'config'

local TB = { info = nil, shown = false, last = nil }

local function take(t)
    if type(t) == "table" then TB.info = t end
end

mp.register_script_message("thumbfast-info", function(j) take(utils.parse_json(j)) end)
mp.observe_property("user-data/thumbfast", "native", function(_, v) take(v) end)

function TB.available()
    local i = TB.info
    return C.thumbnails ~= "no" and C.thumbnails ~= "false" and i ~= nil and not i.disabled and i.available ~= false
        and (i.width or 0) > 0 and (i.height or 0) > 0
end

function TB.size() return TB.info.width, TB.info.height end

function TB.clear()
    if TB.shown then
        mp.commandv("script-message-to", "thumbfast", "clear")
        TB.shown, TB.last = false, nil
    end
end

-- called every frame with the current layout; only talks to thumbfast on change
function TB.sync(lay)
    local th = lay and lay.thumb
    if not th then TB.clear(); return end
    local key = string.format("%.1f:%d:%d", th.t, math.floor(th.x), math.floor(th.y))
    if key ~= TB.last then
        mp.commandv("script-message-to", "thumbfast", "thumb", string.format("%.3f", th.t),
            tostring(math.floor(th.x)), tostring(math.floor(th.y)))
        TB.last, TB.shown = key, true
    end
end

return TB
