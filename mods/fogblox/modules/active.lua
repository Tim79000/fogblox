--[
local minetest,vector,next,assert,pairs,ipairs,tonumber,advfload,VoxelManip,getmetatable
=     minetest,vector,next,assert,pairs,ipairs,tonumber,advfload,VoxelManip,getmetatable
local unpack,remove,insert,floor,min,max,inf,format,sub =
	unpack or table.unpack,
	table.remove,
	table.insert,
	math.floor,
	math.min,
	math.max,
	math.huge,
	string.format,
	string.sub
--]

--[==[--

block = {
	pos = blockpos,
	-- i = (z*(w*h)+y*(w)+x+1) from mapblock origin
	map = {
		["game:dirt"] = {[i]=true,...},
		["group:cracky"] = {...},
		...
	},
	name = {
		[i] = "game:dirt",
		...
	}
	param2 = {
		[i] = 42,
		...
	},
	param1 = {
		[i] = 13,
		...
	}
}
-- blki = lib.blockpos_to_id(...)
lib.register_localstep {
	label = "label",
	interval = 1, -- 0 to run every step for all blocks
	on_dirty = function({
		dirty_blocks={[blki]=block,...},
		blocks={...},
		block_index={
			["game:dirt"]={[blki]=true},
			["group:cracky"]={[blki]=true},
			...
		}
	}),
	on_prestep = function({
		blocks={[blki]=block,...},
		dead_blocks={[blki]=true,...}, -- were active previously, not anymore
		block_index={...}
	})
		return {
			[blki] = {
				emerge={
					blockpos,blockpos2,... -- offset from the block
				},
				activate={
					blockpos,blockpos2,...
				},
				soft = false -- if true: won't forceload anything,
				                will fail to activate if depends are not met
			},
			...
		}
	end,
	on_step = function({
		blocks={...},
		active_blocks={...},
		block_index={...}
	}),
}

--]==]--

local lib={}

local t15=2^15
local t16,t32=2^16,2^32
local function newvec(x,y,z,vec)
	vec=vec or vector.new(0,0,0)
	vec.x,vec.y,vec.z=x,y,z
	return vec
end
local function idtopos(i,pos)
	return newvec(floor(i/t32)-t15,floor(i%t32/t16)-t15,i%t16-t15,pos)
end
local function postoid(pos)
	local x,y,z=floor(pos.x+t15),floor(pos.y+t15),floor(pos.z+t15)
	local i=z*t32+y*t16+x
	return i
end
local function id2str(pos)
	return format("__actl%x",postoid(pos))
end
local function str2id(str)
	local hea,num=sub(str,1,6),sub(str,7)
	if hea~="__actl" then return end
	return tonumber(num,16)
end

local iscv={}
local function isactive(i,pos)
	iscv.x,iscv.y,iscv.z=pos.x*16,pos.y*16,pos.z*16
	return minetest.compare_block_status(iscv,"active")
end

local times={}

local r=max(
	tonumber(minetest.settings:get("active_object_send_range_blocks") or 8),
	tonumber(minetest.settings:get("active_block_range") or 4)
)

local floads={}
local clean={}

lib.blockpos_to_id=postoid
lib.id_to_blockpos=idtopos

function lib.id_to_pos(i,pos)
	pos = pos or vector.new(0,0,0)
	i=i-1
	pos.x,pos.y,pos.z = i%16,floor(i%(256)/16),floor(i/(256))
	return pos
end

function lib.pos_to_id(pos)
	return pos.z*256+pos.y*16+pos.x+1
end

lib.registered_localsteps={}

local nextref=minetest.get_us_time()
local function refresh()
	local actives={}
	local sactives={}
	local ractives={}
	local vec={}
	for _,ref in pairs(minetest.get_connected_players()) do
		local pos=ref:get_pos()
		pos=vector.add(pos,vector.new(0.5,0.5,0.5))
		pos=vector.divide(pos,16)
		pos=vector.floor(pos)
		for x=pos.x-r,pos.x+r do
		for y=pos.y-r,pos.y+r do
		for z=pos.z-r,pos.z+r do
			vec.x,vec.y,vec.z=x,y,z
			local id=postoid(vec)
			if isactive(id,vec) and not actives[id] then
				local vec=vector.new(vec)
				actives[id]=vec
				ractives[id]=vec
			end
		end end end
	end
	for k,v in pairs(advfload.query()) do
		local he,ii=sub(k,1,8),sub(k,9)
		for x=v.pos1.x,v.pos2.x do
		for y=v.pos1.y,v.pos2.y do
		for z=v.pos1.z,v.pos2.z do
			vec=newvec(x,y,z,vec)
			local id=postoid(vec)
			local sid=str2id(k)
			if isactive(id,vec) and not actives[id] then
				local vec=vector.new(vec)
				actives[id]=vec
				if sid then
					assert(id==sid)
					ractives[id]=vec
				else
					sactives[id]=vec
				end
			end
		end end end
	end
	return actives,ractives,sactives
end

local bpc=vector.new(0,0,0)
local function discard(pos,...)
	if not pos then return end
	bpc.x,bpc.y,bpc.z=floor(pos.x/16),floor(pos.y/16),floor(pos.z/16)
	clean[postoid(bpc)]=nil
	return discard(...)
end
local function dsfy(fn)
	return function(pos,...)
		discard(pos)
		return fn(pos,...)
	end
end
local function dsfy_l(fn)
	return function(pos_l,...)
		discard(unpack(pos_l))
		return fn(pos_l,...)
	end
end
minetest.set_node=dsfy(minetest.set_node)
minetest.add_node=dsfy(minetest.add_node)
minetest.swap_node=dsfy(minetest.swap_node)
minetest.remove_node=dsfy(minetest.remove_node)
minetest.bulk_set_node=dsfy_l(minetest.remove_node)
minetest.register_on_liquid_transformed(function(pos_l)
	discard(unpack(pos_l))
end)
local vmanip
minetest.after(0,function()
	clean={}
	vmanip=VoxelManip(vector.new(0,0,0),vector.new(0,0,0))
	local mt=getmetatable(vmanip)
	local wtm=mt.write_to_map
	mt.write_to_map=function(self,...)
		local e1,e2=self:get_emerged_area()
		local pp={}
		for x=e1.x,e2.x,16 do
			for y=e1.y,e2.y,16 do
				for z=e1.z,e2.z,16 do
					pp.x,pp.y,pp.z=x,y,z
					discard(pp)
				end
			end
		end
		return wtm(self,...)
	end
end)

local process_block
do
	local p1,p2,data,data1,data2 = nil,nil,{},{},{}
	local cids={}
	local function fromcid(cid)
		if cids[cid] then return cids[cid] end
		cids[cid]=minetest.get_name_from_content_id(cid)
		return cids[cid]
	end
	local grs={}
	local function groups(name)
		if grs[name] then return grs[name] end
		local def=minetest.registered_items[name]
		local gg={}
		for k,v in pairs((def and def.groups) or {}) do
			if v>0 then
				gg["group:"..k]=true
			end
		end
		grs[name]=gg
		return gg
	end
	local function pti(x,y,z,e1,e2)
		x,y,z=x-e1.x,y-e1.y,z-e1.z
		local w,h,d=e2.x-e1.x+1,e2.y-e1.y+1,e2.z-e1.z+1
		return z*(w*h)+y*(w)+x+1
	end
	local vec
	function process_block(bp)
		p1=newvec(bp.x*16,bp.y*16,bp.z*16,p1)
		p2=newvec(bp.x*16+15,bp.y*16+15,bp.z*16+15,p2)
		--[[local e1,e2=vmanip:read_from_map(p1,p2)
		vmanip:get_data(data)
		vmanip:get_light_data(data1)
		vmanip:get_param2_data(data2)]]
		local block={map={},name={},param2={},param1={}}
		for z=p1.z,p2.z do
		for y=p1.y,p2.y do
		for x=p1.x,p2.x do
			--local i=pti(x,y,z,e1,e2)
			vec=newvec(x,y,z,vec)
			local node=minetest.get_node(vec)
			local name=node.name
			local pi=lib.pos_to_id(vec)
			block.name[pi]=name
			block.param2[pi]=node.param2
			block.param1[pi]=node.param1
			block.map[name]=pi
			for k,v in pairs(groups(name)) do
				block.map[k]=pi
			end
		end end end
		return block
	end

end

local pactives={}
local actives

minetest.register_globalstep(function(dt)
	local sta=minetest.get_us_time()
	local refing=not actives or nextref<=sta
	local p=_G.print
	local ractives,sactives
	if refing then
		actives,ractives,sactives=refresh()
		nextref=sta+0.5*1000000
	end

	local blocks={}
	local dirty={}
	local acn=0

	for k,v in pairs(actives) do
		local a,b,c,d={},{},{},{}
		if refing or isactive(k,v) then
			pactives[k]=nil
			acn=acn+1
			if not clean[k] then
				blocks[k]=process_block(v)
				clean[k]=true
			end
		else
			actives[k]=nil
		end
	end

	local ends=minetest.get_us_time()
	local time=(ends-sta)/1000000
	insert(times,time)
	if #times>1 then remove(times,1) end
	local ff=0
	for k,v in ipairs(times) do
		ff=ff+v
	end
	ff=ff/#times
	minetest.chat_send_all(M("%.6fs %i blocks active; from %i to %i"):format(ff,acn,-r,r)())
end)


