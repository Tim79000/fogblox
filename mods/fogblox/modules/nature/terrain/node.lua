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
