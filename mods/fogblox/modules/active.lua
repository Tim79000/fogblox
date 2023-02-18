--[
local minetest,vector,next,assert,pairs,ipairs,tonumber,advfload,VoxelManip,getmetatable,setmetatable
=     minetest,vector,next,assert,pairs,ipairs,tonumber,advfload,VoxelManip,getmetatable,setmetatable
local unpack,remove,insert,floor,min,max,inf,random,format,sub =
	unpack or table.unpack,
	table.remove,
	table.insert,
	math.floor,
	math.min,
	math.max,
	math.huge,
	math.random,
	string.format,
	string.sub
--]

--[==[--

lib.register_localstep(function(dt,active_blocks))

--]==]--

local lib={}

local lss={}
lib.registered_localsteps=lss
function lib.register_localstep(def)
	lss[#lss+1]=def
end

local t15=2^15
local t16,t32=2^16,2^32
local function newvec(x,y,z,vec)
	vec=vec or vector.new(0,0,0)
	vec.x,vec.y,vec.z=x,y,z
	return vec
end
local function roundvec(vec)
	return newvec(floor(vec.x+0.5),floor(vec.y+0.5),floor(vec.z+0.5),vec)
end

local function idtopos(i,pos)
	local z,y,x=floor(i/t32)-t15,floor(i%t32/t16)-t15,i%t16-t15
	return newvec(x,y,z,pos)
end
local function postoid(pos)
	local x,y,z=floor(pos.x+0.5+t15),floor(pos.y+0.5+t15),floor(pos.z+0.5+t15)
	local i=z*t32+y*t16+x
	return i
end
local function inb_idtopos(bp,i,pos)
	i=i-1
	local x,y,z
	x,y,z=i%16,floor(i%(256)/16),floor(i/(256))
	x,y,z=x+bp.x*16,y+bp.y*16,z+bp.z*16
	pos=newvec(x,y,z,pos)
	return pos
end
local function inb_postoid(bp,pos)
	local x,y,z=pos.x-bp.x*16,pos.y-bp.y*16,pos.z-bp.z*16
	return z*256+y*16+x+1
end
lib.hash_pos=postoid
lib.dehash_pos=idtopos
lib.hash_inbpos=inb_postoid
lib.dehash_inbpos=inb_idtopos

local function id2str(i)
	return format("__actl%x",i)
end
local function str2id(str)
	local hea,num=sub(str,1,6),sub(str,7)
	if hea~="__actl" then return end
	return tonumber(num,16)
end

local iscv={}
local function isactive(pos)
	iscv.x,iscv.y,iscv.z=pos.x*16,pos.y*16,pos.z*16
	return minetest.compare_block_status(iscv,"active")
end
local function isloaded(pos)
	iscv.x,iscv.y,iscv.z=pos.x*16,pos.y*16,pos.z*16
	return minetest.compare_block_status(iscv,"loaded")
end
local function emerge(pos)
	iscv.x,iscv.y,iscv.z=pos.x*16,pos.y*16,pos.z*16
	if not minetest.compare_block_status(iscv,"emerging") then
		minetest.emerge_area(iscv,iscv)
	end
end
local function forceload(pos)
	local i=postoid(pos)
	advfload.start(id2str(i),pos)
end
local function unforceload(pos)
	local i=postoid(pos)
	advfload.stop(id2str(i))
end

local times={}

local r=max(
	tonumber(minetest.settings:get("active_object_send_range_blocks") or 8),
	tonumber(minetest.settings:get("active_block_range") or 4)
)

local clean={}

lib.registered_localsteps={}

local nextref=minetest.get_us_time()
local function refresh()
	local actives={}
	local vec={}
	for _,ref in pairs(minetest.get_connected_players()) do
		local pos=ref:get_pos()
		pos=vector.divide(pos,16)
		pos=vector.floor(pos)
		for x=pos.x-r,pos.x+r do
		for y=pos.y-r,pos.y+r do
		for z=pos.z-r,pos.z+r do
			vec.x,vec.y,vec.z=x,y,z
			local id=postoid(vec)
			if isactive(vec) and not actives[id] then
				local vec=vector.new(vec)
				actives[id]=vec
			end
		end end end
	end
	for k,v in pairs(advfload.query()) do
		for x=v.pos1.x,v.pos2.x do
		for y=v.pos1.y,v.pos2.y do
		for z=v.pos1.z,v.pos2.z do
			vec=newvec(x,y,z,vec)
			local id=postoid(vec)
			if isactive(vec) and not actives[id] then
				local vec=vector.new(vec)
				actives[id]=vec
			end
		end end end
	end
	return actives
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
minetest.bulk_set_node=dsfy_l(minetest.bulk_set_node)
minetest.register_on_liquid_transformed(function(pos_l)
	for k,v in ipairs(pos_l) do
		discard(v)
	end
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
	local p1,p2,vp1,vp2
	local data,data1,data2 = {},{},{}
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
				gg[#gg+1]="group:"..k
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
	function process_block(bps,bp1,bp2,blocks)
		vp1=newvec(bp1.x*16,bp1.y*16,bp1.z*16,vp1)
		vp2=newvec(bp2.x*16+15,bp2.y*16+15,bp2.z*16+15,vp2)
		local vmanip=VoxelManip(vp1,vp2)
		local e1,e2=vmanip:get_emerged_area()
		vmanip:get_data(data)
		vmanip:get_light_data(data1)
		vmanip:get_param2_data(data2)
		for k,v in pairs(bps) do
			local bp=v
			p1=newvec(bp.x*16,bp.y*16,bp.z*16,p1)
			p2=newvec(bp.x*16+15,bp.y*16+15,bp.z*16+15,p2)
			local block={pos=bp,map={},name={},param2={},param1={}}
			local pi=1
			for z=p1.z,p2.z do
			for y=p1.y,p2.y do
			local i=pti(p1.x,y,z,e1,e2)
			for x=p1.x,p2.x do
				local i=i+(x-p1.x)
				local cid=data[i]
				local name=cids[cid] or minetest.get_name_from_content_id(cid)
				local param2,param1=data2[i],data1[i]
				cids[cid]=name
				block.name[pi]=name
				block.param2[pi]=param2
				block.param1[pi]=param1
				local mp=block.map[name] or {}
				block.map[name]=mp
				mp[pi]=true
				local gg=groups(name)
				for n=1,#gg do
					local k=gg[n]
					local mp=block.map[k] or {}
					block.map[k]=mp
					mp[pi]=true
				end
				pi=pi+1
			end end end
			assert(not blocks[k] or not clean[k])
			blocks[k]=block
		end
	end
end

local actives
local floads,emerges={},{}
local blocks={}

local cc=0
local steprate=20
local bints={}
local sints={}

minetest.register_globalstep(function(dt)
	cc=cc+dt*steprate
	if cc>3 then
		cc=3
	end
	local sta=minetest.get_us_time()
	local refing=not actives or nextref<=sta
	if refing then
		actives=refresh()
		nextref=sta+0.5*1000000
	end

	while cc>=1 do
		local dt=1/steprate
		cc=cc-1
		local acts={}
		for i,bp in pairs(actives) do
			if isactive(bp) then
				acts[i]={
					pos=bp,
					objects={}
				}
			end
		end
		for _,ref in pairs(minetest.object_refs) do
			local pos=ref:get_pos()
			if pos then
				pos=roundvec(pos,pos)
				local bp=newvec(floor(pos.x/16),floor(pos.y/16),floor(pos.z/16))
				local blki=postoid(bp)
				local pi=inb_postoid(bp,pos)
				local objs=acts[blki]
				objs=objs and objs.objects
				if objs then
					local pobjs=objs[pi] or {}
					objs[pi]=pobjs
					pobjs[ref]=true
				end
			end
		end
		for i,fn in pairs(lss) do
			fn(dt,actives)
		end
	end
end)

local lazrands={}
local function lazrand(blki)
	local lr=lazrands[blki]
	if not lr then
		lr={expiry=4,data={},i=1}
		lazrands[blki]=lr
		local x=lr.data
		for n=1,4096 do
			local l=#x+1
			local i=random(l)
			if i~=l then
				x[i],x[l]=n,x[i]
			else
				x[i]=n
			end
		end
	end
	if lr.expiry==0 then
		lazrands[blki]=nil
		return lazrand(blki)
	end
	local r=lr.data[lr.i]
	lr.i=lr.i+1
	if lr.i>4096 then
		lr.i=1
		lr.expiry=lr.expiry-1
	end
	return r
end

lib.register_localstep(function(dt,blocks)
	for i,bp in pairs(blocks) do
		for n=1,4 do
			local pi=lazrand(i)
			local pos=inb_idtopos(bp,pi)
			local node=minetest.get_node(pos)
			local def=minetest.registered_nodes[node.name]
			if def.on_randomstep then
				def.on_randomstep(pos,node)
			end
		end
	end
end)

if E then
	for k,v in pairs(lib) do
		E.game[k]=v
	end
end
