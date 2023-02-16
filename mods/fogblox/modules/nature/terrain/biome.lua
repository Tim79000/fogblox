--[
local minetest,ipairs
=     minetest,ipairs
--]

minetest.register_biome {
	name = "desert",
	node_top = "mapgen_sand",
	depth_top = 3,
	node_filler = "mapgen_sandstone",
	depth_filler = 6,

	y_min = 3,
	heat_point = 80,
	humidity_point = 5,
}

minetest.register_biome {
	name = "plains",
	node_top = "mapgen_dirt_with_grass",
	depth_top = 1,
	node_filler = "mapgen_dirt",
	depth_filler = 4,
	
	y_min = 3,
	heat_point = 40,
	humidity_point = 30,
}

minetest.register_biome {
	name = "forest",
	node_top = "mapgen_dirt_with_grass",
	depth_top = 1,
	node_filler = "mapgen_dirt",
	depth_filler = 6,
	biome_blend = 2,

	y_min = 3,
	heat_point = 50,
	humidity_point = 115,
}

minetest.register_biome {
	name = "waters",
	node_top = "mapgen_sand",
	depth_top = 3,
	y_max = 2
}

for _,name in ipairs{"mapgen_sand","mapgen_gravel","mapgen_dirt"} do
	minetest.register_ore {
		ore_type="blob",
		ore=name,
		y_max=0,
		wherein={"mapgen_stone","mapgen_sand"},
		clust_num_ores=16*16*16*0.5,
		clust_scarcity=16*16*16,
		clust_size=9
	}
end
