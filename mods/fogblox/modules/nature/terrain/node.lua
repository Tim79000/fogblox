--[
local pairs,minetest,vector
=     pairs,minetest,vector
local random =
	math.random
--]

local mn=E.modname
local tex=E.tex

local base={
	drawtype="normal",
}

local function reg(def)
	local desc = def.description
	def.name = def.name or M(desc):lower():gsub("%W","_")()
	if def.liquidtype and def.liquidtype~="none" then
		local sour,flow=
			def.name.."_source",
			def.name.."_flowing"
		def.liquid_alternative_source,
		def.liquid_alternative_flowing
		= mn..":"..sour,mn..":"..flow
		def.name = ({source=sour,flowing=flow})[def.liquidtype]
		def.is_ground_content=false
	else
		def.is_ground_content=true
	end
	def.fullname = mn..":"..def.name
	def.is_ground_content = true
	def.tiles = def.tiles or {tex(def.name)}
	def.mapgen = def.mapgen or {def.name}
	minetest.register_node(def.fullname,def)
	for k,v in pairs(def.mapgen) do
		minetest.register_alias("mapgen_"..v,def.fullname)
	end
end

local function regliquid(def)
	E.underride(def,{
			paramtype = "light",
			walkable = false
	})
	local defs = E.underride({
		drawtype = "liquid",
		liquidtype = "source"
	},def)
	local deff = E.underride({
		liquidtype = "flowing",
		drawtype = "flowingliquid",
		paramtype2 = "flowingliquid",
		buildable_to = true,
		mapgen={},
	},def)
	reg(defs)
	reg(deff)
end

local watertile =
	{
		name = tex "water_source",
		animation = {
			type = "vertical_frames",
			aspect_w = 16, aspect_h = 16,
			length = 3
		}
	}

regliquid {
	description = "Water",
	groups = {
		water = 1,
		fire_snuff = 1,
	},
	pointable = false,
	diggable = false,
	buildable_to = true,

	liquid_viscosity = 1,
	liquid_range = 10,
	post_effect_color = {
		r = 0,
		g = 0,
		b = 255,
		a = 100
	},
	use_texture_alpha = "blend",
	tiles = {
		watertile
	},
	special_tiles = {
		watertile,watertile
	},
	sounds = E.game.gsounds("water")
}

reg {
	description = "Stone",
	drop=mn..":cobble",
	groups = {
		stone = 1,
		cracky = 1,
	},
	sounds = E.game.gsounds("rock")
}

reg {
	description = "Cobble",
	groups = {
		cracky = 1
	},
	sounds = E.game.gsounds("rock")
}

reg {
	description = "Dirt",
	groups = {
		soil = 1,
		dirt = 1,
		crumbly = 1,
	},
	sounds = E.game.gsounds("dirt")
}

reg {
	description = "Grass",
	name = "dirt_with_grass",
	groups = {
		soil = 1,
		dirt = 1,
		grass = 1,
		crumbly = 2,
	},
	drop = mn..":dirt",
	tiles = {
		tex("grass"),
		tex("dirt"),
		tex("dirt").."^("..tex("grass").."^[mask:"..tex("grass_side_mask")..")"
	},
	sounds = E.game.gsounds("grass")
}

function E.game.grassable(pos)
	local above=vector.add(pos,vector.new(0,1,0))
	local light=minetest.get_node_light(above,0.5)
	if not light then return false end
	if light<10 then
		return nil
	end
	local node=minetest.get_node(pos)
	if not E.check_groups(node.name,{soil=true}) then
		return false
	end
	return true
end

--[[minetest.register_abm {
	label = "grass spread",
	nodenames = {mn..":dirt_with_grass"},
	chance = 16,
	interval = 4,
	action = function(pos,node)
		local grass=E.game.grassable(pos)
		if grass==nil then minetest.set_node(pos,{name=mn..":dirt"}) end
		local mi,ma=
			vector.add(pos,vector.new(-1,-1,-1)),
			vector.add(pos,vector.new(1,1,1))
		local dirts=minetest.find_nodes_in_area(mi,ma,{"group:soil"})
		local gdirts={}
		for k,v in pairs(dirts) do
			if E.game.grassable(v) then
				gdirts[#gdirts+1]=v
			end
		end
		if #gdirts==0 then return end
		minetest.set_node(gdirts[random(#gdirts)],{name=mn..":dirt_with_grass"})
	end
}]]

reg {
	description = "Sand",
	groups = {
		drysoil = 1,
		crumbly = 1,
		falling_node = 1,
	},
	sounds = E.game.gsounds("sand")
}

reg {
	description = "Gravel",
	groups = {
		crumbly = 2,
		falling_node = 1,
	},
	sand = E.game.gsounds("gravel")
}

reg {
	description = "Sandstone",
	groups = {
		cracky = 1
	},
	sounds = E.game.gsounds("rock")
}
