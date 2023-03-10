--[
local minetest,vector,pairs,next,PcgRandom
=     minetest,vector,pairs,next,PcgRandom
local max,abs,floor,ceil,random,unpack =
	math.max,
	math.abs,
	math.floor,
	math.ceil,
	math.random,
	unpack or table.unpack
--]

local mn=E.modname
local tex=E.tex
E.game.leafdrops={
	{
		chance = 0.04,
		item = mn..":sapling"
	},
	{
		chance = 0.03,
		item = mn..":stick"
	},
	{
		chance = 0.0025,
		item = mn..":apple"
	}
}

local function leafdrop(pos,digger)
	for k,v in pairs(E.game.leafdrops) do
		for n=1,v.count or 1 do
			if random(1,1000000)/1000000<=v.chance then
				minetest.handle_node_drops(pos,{v.item},digger)
			end
		end
	end
end

local tfillds={
	{0,1,0},
	{0,-1,0},
	{-1,0,0},
	{1,0,0},
	{0,0,-1},
	{0,0,1},
}

for k,v in pairs(tfillds) do
	tfillds[k]=vector.new(unpack(v))
end

local function gtfillds(dir)
	local ttf={}
	local backw=vector.subtract(vector.new(0,0,0),dir)
	for k,v in pairs(tfillds) do
		if not vector.equals(v,backw) then
			ttf[#ttf+1]=v
		end
	end
	return ttf
end

local logdef
do
local r1 = "^[transformR90"
local r2 = "^[transformR180"
local r3 = "^[transformR270"
logdef={
		paramtype2 = "facedir",
		groups = {
			choppy = 2,
			flammable = 4,
		},
		tiles = {
			tex"bark"..r2,tex"bark",
			tex"bark"..r1,tex"bark"..r3,
			tex"tree_top",tex"tree_top"
		},
}
end

local lsound=E.game.gsounds("leaves")
minetest.register_node(mn..":log",E.underride({
	description = "Log",
	after_place_node=function(pos,placer,stack,pointed)
		if not pointed.under and pointed.above then return end
		local dir=vector.subtract(pointed.above,pointed.under)
		if vector.equals(dir,vector.new(0,0,0)) then return end
		local node=minetest.get_node(pos)
		node.param2=minetest.dir_to_facedir(vector.apply(dir,abs),true)
		minetest.swap_node(pos,node)
	end
},logdef))

local function floodfill_tree(pos,limit)
	local node=minetest.get_node(pos)
	local alldirs = tfillds
	local seen = {[E.game.hash_pos(pos)]=true}
	local tt
	local ltt=false
	do
		local tr,le =
			minetest.get_item_group(node.name,"tree_trunk"),
			minetest.get_item_group(node.name,"leaves")
		tt=tr>0 and "tree" or nil
		if le>0 then tt="leaves" end
	end
	if not tt then return end
	local to = {[pos]={tt,limit=limit or 40,src=tt}}
	if tt=="leaves" then
		ltt=true
	end
	local leaves,trunks={},{}
	local ignores=false
	while next(to) do
		local newto={}
		for pos,t in pairs(to) do
			local t,limit,src=t[1],t.limit,t.src
			local dirs=alldirs
			local dir
			local opos=pos
			if t=="leaves" then leaves[pos]=true end
			if t=="tree" then
				local node=minetest.get_node(pos)
				dir = minetest.facedir_to_dir(node.param2)
				dirs = gtfillds(dir)
				trunks[pos]=true
			end
			if t=="ignore" then
				ignores[pos]=true
			end
			if limit==0 then
				dirs={}
			end
			for k,v in pairs(dirs) do
				local pos=vector.add(pos,v)
				local ii=E.game.hash_pos(pos)
				if not seen[ii] then
					seen[ii]=true
					local node = minetest.get_node(pos)
					local ndir
					local tr,le =
						minetest.get_item_group(node.name,"tree_trunk"),
						minetest.get_item_group(node.name,"leaves")
					local tt=tr>0 and "tree" or nil
					if le>0 then tt="leaves" end
					if tt=="tree" then
						ndir=minetest.facedir_to_dir(node.param2)
					end
					local dirmatch=dir and ndir and vector.equals(dir,ndir)
					local straight=dir and vector.equals(pos,vector.add(opos,dir))
					local branchout=ndir and vector.equals(opos,vector.subtract(pos,ndir))
					if tt=="tree" and dir and (
						(dirmatch and not straight)
						or (not dirmatch and not branchout)
					) then
						tt=false
					end
					if not ltt and tt=="tree" and src~="tree" then
						tt=false
					end
					if node.name=="ignore" then
						tt="ignore"
						ignores=true
						return leaves,trunks,ignores
					end
					if tt then
						newto[pos]={tt,limit=limit-1,src=t}
					end
				end
			end
		end
		to=newto
	end
	return leaves,trunks,ignores
end

local function checkleaf(pos)
	local node=minetest.get_node(pos)
	local d=7
	if node.name==mn..":leaves" and node.param2~=0 then
		d=node.param2
	end
	local leaves,trunks,ignores=floodfill_tree(pos,d)
	if ignores then return true end
	for tpos,_ in pairs(trunks) do
		local dist=0
		vector.apply(vector.subtract(pos,tpos),function(a)
			dist=max(dist,abs(a))
		end)
		if dist<=3 then return true end
	end
	return false,leaves
end

local diggin=false

minetest.register_node(mn..":tree",E.underride({
		description = "Tree",
		groups = {
			tree_trunk = 1,
		},
		drop=mn..":log",
		after_dig_node=function(pos,node,meta,digger)
			if diggin then return end
			diggin=true
			local newnode=minetest.get_node(pos)
			minetest.set_node(pos,node)
			local leaves,trunks=floodfill_tree(pos)
			minetest.set_node(pos,newnode)
			for pos,_ in pairs(trunks) do
				local node=minetest.get_node(pos)
				minetest.node_dig(pos,node,digger)
			end
			for pos,_ in pairs(leaves) do
				local node=minetest.get_node(pos)
				if not checkleaf(pos) then
					minetest.node_dig(pos,node,digger)
				end
			end
			diggin=false
		end,
		on_randomstep=function(pos,node)
			local p2=vector.subtract(pos,minetest.facedir_to_dir(node.param2,true))
			local n2=minetest.get_node_or_nil(p2)
			if not n2 then return end
			n2=n2.name
			if n2==mn..":tree" then return end
			if n2==mn..":root" then return end
			minetest.node_dig(pos,node)
			local def=minetest.registered_items[node.name]
			def.after_dig_node(pos,node)
		end,
		on_punch = function(pos,node)
			local leaves,trunks,ign = floodfill_tree(pos)
			if ign then return end
			for pos,_ in pairs(leaves) do
				local meta=minetest.get_meta(pos)
				local harrassment_timeout=meta:get_int("tshake_cooldown")
				if harrassment_timeout<=minetest.get_gametime() then
					meta:set_int("tshake_cooldown",minetest.get_gametime()+600)
					if random(5)==1 then
						minetest.sound_play(lsound.dig,{pos=pos,gain=0.3})
						leafdrop(pos)
					end
				end
			end
		end
},logdef))

minetest.register_node(mn..":root",{
		description = "Tree Root",
		groups = {
			choppy = 4,
			flammable=5,
		},
		on_burn=function(pos)
			local above=vector.add(pos,vector.new(0,1,0))
			local node=minetest.get_node(above)
			if node.name==mn..":tree" then return end
			return true
		end,
		drop=mn..":stick 8",
		tiles = {
			tex"tree_top",tex"dirt",
			tex"dirt".."^("..tex"bark".."^[mask:"..tex("roots_mask")..")"
		}
})

minetest.register_node(mn..":leaves",{
		description = "Leaves",
		drawtype = "allfaces_optional",
		paramtype = "light",
		walkable = false,
		climbable = true,
		paramtype2 = "none",
		drop = "",
		after_dig_node = function(pos,onode,ometa,digger)
			leafdrop(pos,digger)
		end,
		on_randomstep=function(pos,node)
			if not checkleaf(pos) then
				minetest.remove_node(pos)
				leafdrop(pos)
			end
		end,
		groups = {
			leaves = 1,
			snappy = 1,
			flammable=1,
		},
		tiles = {tex"leaves".."^[mask:"..tex("leaves_mask")},
		sounds = lsound
})

minetest.register_craftitem(mn..":stick",{
		description = "Stick",
		inventory_image = tex "stick",
})

local function realplace(pos,t,dir)
	local node={}
	if t=="root" then
		node.name = mn..":root"
	elseif t=="tree" then
		if dir then
			node.param2 = minetest.dir_to_facedir(dir,true)
		end
		node.name = mn..":tree"
	elseif t=="leaves" then
		if dir then
			node.param2 = dir
		end
		node.name = mn..":leaves"
	end
	minetest.set_node(pos,node)
end

local function realcheck(pos)
	local node = minetest.get_node(pos)
	local def = minetest.registered_nodes[node.name]
	if not def then return nil end
	if minetest.get_item_group(node.name,"leaves")>0 then
		return true
	end
	if not (def and def.buildable_to) then
		return nil
	end
	return true
end

local function realrand(...)
	return random(...)
end

local function randround(a,r)
	local up,down=floor(a),ceil(a)
	local cc=a-down
	if r(1024)>=cc*1024 then
		return down
	else
		return up
	end
end

local function canopy(pos,r,place,check,rand)
	for x=-r,r do for y=-r,r do for z=-r,r do
		local xx,yy,zz=abs(x),abs(y),abs(z)
		local dist=xx+yy+zz
		local rdist=((xx*xx+yy*yy+zz*zz)^0.5)
		rdist=randround(rdist-0.5,rand)
		local bad=rdist>r
		if not bad then
			local pos=vector.add(pos,vector.new(x,y,z))
			local good=check(pos)
			if good then place(pos,"leaves",dist) end
		end
	end end end
end

local function branch(pos,dir,place,check,rand)
	for n=1,4 do
		pos = vector.add(pos,dir)
		place(pos,"tree",dir)
	end
	canopy(pos,2,place,check,rand)
end

local dirs={
	{-1,0},
	{1,0},
	{0,-1},
	{0,1}
}
for k,v in pairs(dirs) do
	dirs[k] = vector.new(v[1],0,v[2])
end

local function gentree(pos,place,check,rand)
	place = place or realplace
	local dir = vector.new(0,1,0)
	place(pos,"root",dir)
	for n=1,rand(4,5) do
		pos=vector.add(pos,dir)
		if not check(pos) then return end
		place(pos,"tree",dir)
	end
	local ddir
	local branchc = rand(1,2)
	local len = rand(10,11)
	local branches={}
	for n=1,branchc do
		local n
		repeat n=rand(1,len-8) until not branches[n]
		branches[n]=true
	end
	for n=1,len do
		pos=vector.add(pos,dir)
		if not check(pos) then return end
		place(pos,"tree",dir)
		if branches[n] then
			local ndir
			repeat ndir=rand(4) until ndir~=ddir
			ddir=ndir
			branch(pos,dirs[ndir],place,check,rand)
		end
	end
	canopy(pos,3,place,check,rand)
end

local function schem(rand)
	local schem={
		size={x=10*2+1,y=30,z=10*2+1},
		data={},
	}
	local function map(pos)
		return 
			(pos.z-1)*(schem.size.x*schem.size.y)+
			(pos.y-1)*(schem.size.x)+
			pos.x
	end
	local air = {name="ignore"}
	local ppos={}
	for z=1,schem.size.z do
		ppos.z=z
		for y=1,schem.size.y do
			ppos.y=y
			for x=1,schem.size.x do
				ppos.x=x
				local i = map(ppos)
				schem.data[i] = air
			end
		end
	end
	local function place(pos,t,dir)
		local node={}
		if t=="root" then
			node.name = mn..":root"
			node.force_place = true
		elseif t=="tree" then
			if dir then
				node.param2 = minetest.dir_to_facedir(dir,true)
			end
			node.name = mn..":tree"
			node.force_place = true
		elseif t=="leaves" then
			if dir then
				node.param2 = dir
			end
			node.name = mn..":leaves"
			node.force_place = false
		end
		schem.data[map(pos)]=node
	end
	local function check(pos)
		local node = schem.data[map(pos)] or {name = "air"}
		local def = minetest.registered_nodes[node.name]
		if not def then return nil end
		if minetest.get_item_group(node.name,"leaves")>0 then
			return true
		end
		if not (def and def.buildable_to) then
			return nil
		end
		return true
	end
	gentree(vector.new(11,1,11),place,check,rand)
	return schem
end
local seeds = {}
E.game.schem_tree = {}
local seed = 42069
local function rander(seed)
	local pcg = PcgRandom(seed)
	return function(mi,ma)
		if not ma then mi,ma=1,mi end
		return pcg:next(mi,ma)
	end
end
do
	local rand = rander(seed)
	for n=1,32 do
		seeds[n] = rand(1,2^31-1)
		E.game.schem_tree[n] = schem(rander(seeds[n]))
		local deco = {
			deco_type = "schematic",
			place_on = mn..":dirt_with_grass",
			schematic = E.game.schem_tree[n],
			flags = {place_center_x = true, place_center_z = true},
			rotation = "0",
		}
		minetest.register_decoration(E.underride({
			biomes = {"plains"},
			fill_ratio = 0.00001
		},deco))
		minetest.register_decoration(E.underride({
			biomes = {"forest"},
			fill_ratio = 0.001
		},deco))
	end
end

minetest.register_chatcommand("spawntree",{
	privs={privs=true},
	func=function(name)
		local ref=minetest.get_player_by_name(name)
		if not ref then return end
		local pos=vector.round(ref:get_pos())
		minetest.place_schematic(pos,E.game.schem_tree[random(#E.game.schem_tree)],
			nil,nil,false,{place_center_x=true,place_center_z=true})
	end
})

minetest.register_chatcommand("growtree",{
	privs={privs=true},
	func=function(name)
		local ref=minetest.get_player_by_name(name)
		if not ref then return end
		local pos=vector.round(ref:get_pos())
		gentree(pos,realplace,realcheck,rander(seeds[random(1,#seeds)]))
	end
})

minetest.register_craftitem(mn..":apple",{
	description = "Tree Fruit",
	inventory_image = tex "apple",
	on_use = minetest.item_eat(2),
	stack_max = 1
})

minetest.register_node(mn..":sapling",{
	description = "Sapling",
	drawtype = "plantlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	selection_box={
		type = "fixed",
		fixed = {
			-0.3,-0.5,-0.3,
			0.3,0.4,0.3
		}
	},
	on_randomstep=function(pos,node)
		local below=vector.add(pos,vector.new(0,-1,0))
		local bnode=minetest.get_node(below)
		local light=minetest.get_node_light(pos)
		if minetest.get_item_group(bnode.name,"soil")>0 and light>10 then
			local meta=minetest.get_meta(pos)
			local scor=meta:get_int("sapling_growth")
			scor=scor+1
			meta:set_int("sapling_growth",scor)
			if scor>=5 then
				minetest.remove_node(pos)
				gentree(below,realplace,realcheck,rander(seeds[random(1,#seeds)]))
			end
		end
	end,
	groups = {
		snappy = 1,
		attached_node = 1,
		flammable=1,
	},
	after_place_node = function(pos,pl,stack,pointed)
		local under = vector.add(pos,vector.new(0,-1,0))
		local unode = minetest.get_node(under)
		local soil = minetest.get_item_group(unode.name,"soil")
		if soil<1 then minetest.remove_node(pos) return true end
	end,
	inventory_image = tex"sapling",
	tiles = {tex"sapling"}
})

local one=vector.new(1,1,1)
minetest.register_node(mn..":peat",{
	description = "Peat",
	tiles={tex"peat"},
	groups={crumbly=1,flammable=2,falling_node=1},
	on_randomstep=function(pos,node)
		local mi,ma=vector.subtract(pos,one),vector.add(pos,one)
		local dirts=minetest.find_nodes_in_area(mi,ma,{mn..":dirt"})
		if #dirts==0 then return end
		local n=mn..":dirt"
		if E.game.grassable(pos) and random(20)==1 then
			n=mn..":dirt_with_grass"
		end
		minetest.set_node(pos,{name=n})
	end,
})

E.game.register_craft {
	input={"group:tool_shovel1",mn..":sapling 8"},
	output={"group:tool_shovel1",mn..":peat"},
	toolworn={1}
}
