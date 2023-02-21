--[
local minetest,vector,pairs
=     minetest,vector,pairs
local game,random =
	E.game,
	math.random
--]

local grasses={}
local grassname=E.modname..":dirt_with_grass"
local dirtname=E.modname..":dirt"
local soilgr="group:soil"

local function grassgrow(pos,node)
	if random(2)~=1 then return end
	local grass=game.grassable(pos)
	if grass==nil then minetest.set_node(pos,{name=dirtname}) end
	local mi,ma=
		vector.add(pos,vector.new(-1,-1,-1)),
		vector.add(pos,vector.new(1,1,1))
	local dirts=minetest.find_nodes_in_area(mi,ma,{"group:soil"})
	local gdirts={}
	for k,v in pairs(dirts) do
		if game.grassable(v) and not vector.equals(v,pos) then
			gdirts[#gdirts+1]=v
		end
	end
	if #gdirts==0 then return end
	minetest.set_node(gdirts[random(#gdirts)],{name=grassname})
end

minetest.override_item(grassname,{
	on_randomstep=grassgrow
})

function game.grassable(pos)
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
	if node.name==grassname then return false end
	return true
end
