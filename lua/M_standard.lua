local function toLuaString(v) return v.F_toString().S_value end
local function curry2(f) return function(a) return function(b) return f(a, b) end end end
local function curry3(f) return function(a) return function(b) return function(c) return f(a, b, c) end end end end
local S_module = nil
S_module = {
    F_print = function(v) print(toLuaString(v)) end,
    F_error = function(v) error(toLuaString(v)) end,
}
return S_module

