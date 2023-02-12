--[
local minetest
=     minetest
--]
minetest.override_item("",{
		tool_capabilities = E.game.toolcaps{
			groups={
				crumbly=1,
				snappy=1,
			}
		}
})
