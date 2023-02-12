--[
local minetest,ipairs,ItemStack
=     minetest,ipairs,ItemStack
local unpack,ceil =
	unpack or table.unpack,
	math.ceil
--]

local tex=E.tex
local mn=E.modname

minetest.register_tool(mn..":sharpstick",{
	description = "Sharpened Stick",
	inventory_image = tex "sharpstick",
	tool_capabilities = E.game.toolcaps {
		groups = {
			crumbly = 2,
		},
		uses = 9
	}
})

minetest.register_tool(mn..":sharpstone",{
	description = "Sharpened Pebble",
	inventory_image = tex "sharpstone",
	tool_capabilities = E.game.toolcaps {
		groups = {
			crumbly = 2,
			cracky = 1,
			choppy = 1,
		},
		uses = 36
	}
})

minetest.register_craftitem(mn..":pebble",{
	description = "Pebble",
	inventory_image = tex "pebble",
})

E.game.register_craft {
	input={mn..":sharpstick",mn..":dirt 2"},
	output={mn..":sharpstick",mn..":pebble"},
	toolworn={1}
}

E.game.register_craft {
	input={"group:tool_pick1",mn..":cobble"},
	output={"group:tool_pick1",mn..":gravel",mn..":pebble 4"},
	toolworn={1},
}

for k,v in ipairs{{"sharpstick","stick"},{"sharpstone","pebble"}} do
	local mat=mn..":"..v[2]
	local tool=mn..":"..v[1]
	E.game.register_craft {
		input={mat.." 2"},
		output={tool}
	}
end

for k,v in ipairs{
	{"pick","Pick",{cracky=3},{fleshy=3,int=1}},
	{"axe","Axe",{choppy=3},{fleshy=6,int=2}},
	{"shovel","Shovel",{crumbly=3},{fleshy=3,int=1}},
	{"hammer","Hammer",{thumpy=3},{fleshy=6,int=2}},
	{"sword","Sword",{snappy=3},{fleshy=5,int=0.8}}
} do
	local tname,tdesc,ncaps,dcaps=unpack(v)
	local toolhead,tool =
		mn..":toolhead_stone_"..tname,
		mn..":tool_stone_"..tname
	minetest.register_craftitem(toolhead,{
		description = tdesc.." Head",
		inventory_image = tex ("stone_"..tname.."_head")
	})
	minetest.register_tool(tool,{
		description = tdesc,
		inventory_image = tex("stone_"..tname),
		groups={
			["tool_"..tname.."1"]=1
		},
		tool_capabilities = E.game.toolcaps {
			groups=ncaps,
			uses=72
		}
	})
	E.game.register_craft{
		input={mn..":sharpstone",mn..":pebble"},
		output={mn..":sharpstone",toolhead},
		toolworn={1}
	}
	E.game.register_craft{
		input={toolhead,mn..":stick"},
		output={tool}
	}
end
