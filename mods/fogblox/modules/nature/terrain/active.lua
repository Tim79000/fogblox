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

local function newvec(x,y,z,vec)
	vec=vec or vector.new(0,0,0)
	vec.x,vec.y,vec.z=x,y,z
	return vec
end
local function addvecvec(a,b,out)
	return newvec(a.x+b.x, a.y+b.y, a.z+b.z, out)
end
local function mulvecnum(a,b,out)
	return newvec(a.x*b, a.y*b, a.z*b, out)
end

game.register_localstep {
	label="grass spread",
	interval=1,
	step_type="smooth",
	on_prestep=function(data)
		local pipos,pos,mi,ma
		local plus1,minus1=newvec(-1,-1,-1),newvec(1,1,1)
		local num=0
		for i,block in pairs(data.dirty_blocks) do
			num=num+1
			if data.block_index[grassname] and data.block_index[grassname][i] then
				local grs,good={},false
				for pi,_ in pairs(block.map[grassname]) do
					pos=game.id_to_blockpos(i,pos)
					pos=game.id_to_pos(pos,pi,pos)
					_G.assert(minetest.get_node(pos).name==grassname)
					mi=addvecvec(pos,minus1,mi)
					ma=addvecvec(pos,plus1,ma)
					local gg=game.grassable(pos)==nil
					if not gg then
						local dirts=minetest.find_nodes_in_area(mi,ma,{"group:soil"})
						for k,v in pairs(dirts) do
							gg=gg or game.grassable(v)
							if gg then break end
						end
					end
					if gg then
						grs[pi],good=vector.new(pos),true
					end
				end
				if good then
					grasses[i]=grs
				else
					grasses[i]=nil
				end
			end
		end
		if num>0 then
			minetest.chat_send_all(num.." dirty")
		end
		for k,v in pairs(data.dead_blocks) do
			grasses[k]=nil
		end
	end,
	on_step=function(data)
		local ppc=0
		local gcc=0
		local ncc=0
		for blki,block in pairs(data.active_blocks) do
			ppc=ppc+1
			--[[
			if grasses[blki] then
				gcc=gcc+1
				for pi,pos in pairs(grasses[blki]) do
					ncc=ncc+1
					local node=minetest.get_node(pos)
					--minetest.set_node(pos,{name="fogblox:plank"})
					grassgrow(pos,node)
				end
			end
			--[=[
			--]]
			if data.block_index[grassname] and data.block_index[grassname][blki] and _G.assert(block.map[grassname]) then
				for pi,_ in pairs(block.map[grassname]) do
					if random(2)==2 then
						local pos
						pos=game.id_to_blockpos(blki,pos)
						pos=game.id_to_pos(pos,pi,pos)
						minetest.set_node(pos,{name="fogblox:plank"})
					end
				end
			end
			--]=]
		end
		minetest.chat_send_all(gcc.."/"..ppc.."; "..ncc.."n")
	end
}

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
