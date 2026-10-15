local U = require 'util'

local A = {}
local list = {}

function A.new(v)
    local a = { v = v, from = v, target = v, t0 = 0, dur = 0, active = false }
    list[#list + 1] = a
    return a
end

function A.set(a, v)
    a.v, a.from, a.target, a.active = v, v, v, false
end

function A.to(a, target, dur, now)
    if a.target == target then return end
    a.from, a.target, a.t0, a.dur, a.active = a.v, target, now, dur or 0.15, true
end

-- advance all tweens; returns true while any is still running
function A.step(now)
    local any = false
    for _, a in ipairs(list) do
        if a.active then
            local p = (now - a.t0) / a.dur
            if p >= 1 then
                a.v, a.active = a.target, false
            else
                a.v = U.lerp(a.from, a.target, U.ease(p))
                any = true
            end
        end
    end
    return any
end

return A
