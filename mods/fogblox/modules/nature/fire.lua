--[
local minetest,ipairs,vector
=     minetest,ipairs,vector
local unpack,random =
	unpack or table.unpack,
	math.random
--]
local mn,tex=E.modname,E.tex

local firetile=
	{
		name = tex "fire",
		animation = {
			type = "vertical_frames",
			aspect_w = 16, aspect_h = 16,
			length = 1
		}
	}

local dirs={
	{-1,0,0},
	{0,-1,0},
	{0,0,-1},
	{1,0,0},
	{0,1,0},
	{0,0,1}
}
for k,v in ipairs(dirs) do
	dirs[k]=vector.new(unpack(v))
end
local function checkplace(pos)
	local nodes
	local ntable={}
	local bad
	local node=minetest.get_node(pos)
	if node.name~="air" and node.name~=mn..":fire" then
		return nil,ntable
	end
	for k,v in ipairs(dirs) do
		local pos=vector.add(pos,v)
		local node=minetest.get_node(pos)
		if minetest.get_item_group(node.name,"fire_snuff")>0 then
			bad=true
			nodes=nil
		end
		if not bad and minetest.get_item_group(node.name,"flammable")>0 then
			nodes=nodes or {}
			nodes[#nodes+1]=pos
			ntable[pos]=true
		end
	end
	return nodes,ntable
end
function E.game.fire_randomstep(pos)
	local nodes,ntable=checkplace(pos)
	local node=minetest.get_node(pos)
	local isfire=node.name==mn..":fire"
	if nodes then
		local fpos=nodes[random(#nodes)]
		local node=minetest.get_node(fpos)
		local flam=minetest.get_item_group(node.name,"flammable")
		local def=minetest.registered_nodes[node.name]
		if random((flam-1)+2)==1 and (not def.on_burn or def.on_burn(fpos,node)) then
			minetest.remove_node(fpos)
			if #nodes-1==0 and isfire then
				minetest.remove_node(pos)
				if checkplace(fpos) then
					minetest.set_node(fpos,{name=mn..":fire"})
					for k,v in ipairs(dirs) do
						local gpos=vector.add(fpos,v)
						local node=minetest.get_node(pos)
						if node.name==mn..":fire" and not checkplace(gpos) then
							minetest.remove_node(pos)
						end
					end
				end
			end
		end
	elseif isfire then
		minetest.remove_node(pos)
	end
	local gg={}
	for x=pos.x-1,pos.x+1 do for y=pos.y-1,pos.y+1 do for z=pos.z-1,pos.z+1 do
		local pp=vector.new(x,y,z)
		if not vector.equals(pp,pos) and checkplace(pp) then
			gg[#gg+1]=pp
		end
	end end end
	if #gg>0 then
		local pp=gg[random(#gg)]
		minetest.set_node(pp,{name=mn..":fire"})
	end
end
minetest.register_node(mn..":fire",{
	drawtype="firelike",
	buildable_to=true,
	floodable=true,
	walkable=false,
	diggable=false,
	pointable=false,
	damage_per_second = 4,
	on_randomstep=E.game.fire_randomstep,
	drop="",
	paramtype="light",
	light_source=12,
	tiles={firetile},
})

--[[minetest.register_abm {
	label = "fire spread",
	nodenames = {"group:igniter"},
	interval = 2,
	chance = 2,
	action = function(pos)
		local nodes,ntable=checkplace(pos)
		local node=minetest.get_node(pos)
		local isfire=node.name==mn..":fire"
		if nodes then
			local fpos=nodes[random(#nodes)]
			local node=minetest.get_node(fpos)
			local flam=minetest.get_item_group(node.name,"flammable")
			local def=minetest.registered_nodes[node.name]
			if random((flam-1)*4+6)==1 and (not def.on_burn or def.on_burn(fpos,node)) then
				minetest.remove_node(fpos)
				if #nodes-1==0 and isfire then
					minetest.remove_node(pos)
					if checkplace(fpos) then
						minetest.set_node(fpos,{name=mn..":fire"})
					end
				end
			end
		elseif isfire then
			minetest.remove_node(pos)
		end
		local gg={}
		for x=pos.x-1,pos.x+1 do for y=pos.y-1,pos.y+1 do for z=pos.z-1,pos.z+1 do
			local pp=vector.new(x,y,z)
			if not vector.equals(pp,pos) and checkplace(pp) then
				gg[#gg+1]=pp
			end
		end end end
		if #gg>0 and random(2)==1 then
			local pp=gg[random(#gg)]
			minetest.set_node(pp,{name=mn..":fire"})
		end
	end
}]]
