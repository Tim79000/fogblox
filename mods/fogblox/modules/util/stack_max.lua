--[
local minetest
=     minetest
--]

local function fma(def)
	if def.stack_max==99 then def.stack_max=100 end
end

fma(minetest.nodedef_default)
fma(minetest.craftitemdef_default)
fma(minetest.tooldef_default)
fma(minetest.noneitemdef_default)
