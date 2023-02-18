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
	objects={
		[i]={ObjectRef,...},
		...
	}
}

blki = lib.blockpos_to_id(blockpos)
blockpos = lib.id_to_blockpos(blki,reused_vec)

lib.register_localstep {
	label = "label",
	interval = 1,
	step_type = "smooth", -- "burst" - calls on_step every `interval` seconds on all active blocks
	                      -- "smooth" - calls on_step every step on a part of active blocks
	                      -- (so that all blocks are processed every `interval` seconds)
	on_prestep = function({
		blocks={[blki]=block,...}, -- all the blocks
		dirty_blocks={[blki]=block,...}, -- blocks that were changed previously
		dead_blocks={[blki]=true,...}, -- completely unloaded blocks
		block_index={                  -- (more blocks might get deactivated due to prestep however)
			["game:dirt"]={[blki]=block,...},
			["group:cracky"]={...},
			...
		},
		activate_deps={...}
	})
		activate_deps[blki].emerge[blki2]=true
			-- requires blki2 to be loaded (but not necessarily active) to activate blki
		activate_deps[blki].activate[blki2]=true
			-- requires blki2 to be active
		activate_deps[blki].force=false
			-- will forceload/emerge the blocks
		...
	end,
	on_step = function({
		dt=1/20,
		blocks={...},
		active_blocks={[blki]=block,...}, -- blocks you should operate on
		block_index={...}
	}),
}

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
local function idtopos(i,pos)
	local z,y,x=floor(i/t32)-t15,floor(i%t32/t16)-t15,i%t16-t15
	return newvec(x,y,z,pos)
end
local function postoid(pos)
	local x,y,z=floor(pos.x+0.5+t15),floor(pos.y+0.5+t15),floor(pos.z+0.5+t15)
	local i=z*t32+y*t16+x
	return i
end
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

lib.blockpos_to_id=postoid
lib.id_to_blockpos=idtopos

function lib.id_to_pos(bp,i,pos)
	i=i-1
	local x,y,z
	x,y,z=i%16,floor(i%(256)/16),floor(i/(256))
	x,y,z=x+bp.x*16,y+bp.y*16,z+bp.z*16
	pos=newvec(x,y,z,pos)
	return pos
end

function lib.pos_to_id(bp,pos)
	local x,y,z=pos.x-bp.x*16,pos.y-bp.y*16,pos.z-bp.z*16
	return z*256+y*16+x+1
end
local inb_idtopos,inb_postoid=lib.id_to_pos,lib.pos_to_id

lib.registered_localsteps={}

local nextref=minetest.get_us_time()
local function refresh()
	local actives={}
	local sactives={}
	local ractives={}
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
				ractives[id]=vec
			end
		end end end
	end
	for k,v in pairs(advfload.query()) do
		local sid=str2id(k)
		for x=v.pos1.x,v.pos2.x do
		for y=v.pos1.y,v.pos2.y do
		for z=v.pos1.z,v.pos2.z do
			vec=newvec(x,y,z,vec)
			local id=postoid(vec)
			if isactive(vec) and not actives[id] then
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

local actives,ractives,sactives
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
		actives,ractives,sactives=refresh()
		nextref=sta+2*1000000
	end

	while cc>=1 do
		local dt=1/steprate
		cc=cc-1
		local dirty={}

		local blkve
		local acts=actives
		local actives={}
		for k,v in pairs(acts) do
			local a,b,c,d={},{},{},{}
			if refing or isactive(v) then
				actives[k]=v
				if not clean[k] then
					blkve=newvec((v.x-2)/5,(v.y-2)/5,(v.z-2)/5,blkve)
					local i=postoid(blkve)
					local dr=dirty[i] or {mi=newvec(inf,inf,inf),ma=newvec(-inf,-inf,-inf),blocks={}}
					dirty[i]=dr
					local mi,ma=dr.mi,dr.ma
					dr.mi=newvec(min(mi.x,v.x),min(mi.y,v.y),min(mi.z,v.z),mi)
					dr.ma=newvec(max(ma.x,v.x),max(ma.y,v.y),max(ma.z,v.z),ma)
					dr.blocks[k]=v
				end
			end
		end

		local changed={}
		for k,v in pairs(dirty) do
			process_block(v.blocks,v.mi,v.ma,blocks)
			for k,v in pairs(v.blocks) do
				clean[k]=true
				changed[k]=blocks[k]
			end
		end
		local index={}
		local dead={}
		for blkid,block in pairs(blocks) do
			if isloaded(block.pos) then
				for name,_ in pairs(block.map) do
					index[name]=index[name] or {}
					index[name][blkid]=true
				end
				block.objects={}
			else
				dead[blkid]=true
				blocks[blkid]=nil
				clean[blkid]=nil
			end
		end
		for k,v in pairs(minetest.object_refs) do
			local pos=v:get_pos()
			if pos then
				pos=vector.round(pos)
				local bp=vector.divide(pos,16)
				local i=postoid(bp)
				local pi=inb_postoid(vector.floor(bp),pos)
				local obj=blocks[i]
				if obj then
					obj=obj.objects
					local objpi=obj[pi] or {}
					obj[pi]=objpi
					objpi[#objpi+1]=v
				end
			end
		end

		local deps=setmetatable({},{
			__index=function(deps,k)
				if not actives[k] then return nil end
				deps[k]={
					blkid=k,
					emerge={},
					activate={},
					force=true
				}
				return deps[k]
			end})
		local arg={
			blocks=blocks,
			dirty_blocks=changed,
			dead_blocks=dead,
			block_index=index,
			activate_deps=deps,
		}

		for _,ls in ipairs(lss) do
			ls.on_prestep(arg)
		end

		local tofload={}
		local erdeps={}
		local ardeps={}
		for dblki,dep in pairs(deps) do
			local hard=dep.force
			for blki,_ in pairs(dep.emerge) do
				erdeps[blki]=erdeps[blki] or {kill={},hard=false,pos=idtopos(blki)}
				erdeps[blki].hard=erdeps[blki].hard or hard
				erdeps[blki].kill[dblki]=true
			end
			for blki,_ in pairs(dep.activate) do
				ardeps[blki]=ardeps[blki] or {kill={},hard=false,pos=idtopos(blki)}
				ardeps[blki].hard=ardeps[blki].hard or hard
				ardeps[blki].kill[dblki]=true
			end
		end
		for blki,dep in pairs(erdeps) do
			if not isloaded(dep.pos) then
				if dep.hard then emerge(dep.pos) end
				for blki,v in pairs(dep.kill) do
					actives[blki]=nil
				end
			end
		end
		for blki,dep in pairs(ardeps) do
			if not isactive(dep.pos) then
				if dep.hard then floads[blki]=dep.pos forceload(dep.pos) end
				for blki,v in pairs(dep.kill) do
					actives[blki]=nil
				end
			end
		end
		if refing then
			local pp
			local bad={}
			local notbad={}
			local to,seen={},{}
			for k,v in pairs(floads) do
				bad[k]=v
				to[blki]={[blki]=true}
			end
			while next(to) do
				local cblki,pl=next(to)
				to[cblki]=nil
				if not seen[cblki] then
					if ractives[cblki] then
						for k,_ in pairs(pl) do
							notbad[pl]=true
						end
					else
						seen[cblki]=true
						pl[cblki]=true
						if ardeps[cblki] then
							for k,_ in pairs(ardeps[cblki].kill) do
								to[k]=pl
							end
						end
					end
				end
			end
			for k,v in pairs(notbad) do
				for k,v in pairs(v) do
					bad[k]=nil
				end
			end
			for k,v in pairs(bad) do
				floads[k]=nil
				unforceload(v)
			end
		end
		local a={}
		local acblocks={}
		local actc=0
		for k,v in pairs(actives) do
			assert(blocks[k])
			local ma=#a+1
			local ii=random(ma)
			local olv=a[ii]
			a[ii]={k,blocks[k]}
			if ii~=ma then
				a[ma]=olv
			end
			acblocks[k]=blocks[k]
			actc=actc+1
		end
		local arg={
			dt=dt,
			blocks=blocks,
			block_index=index,
		}
		local bint={}
		local sint={}
		for _,ls in pairs(lss) do
			local act
			local st=ls.step_type or "smooth"
			if st=="burst" then
				if bint[ls.interval]~=nil then
					act=bint[ls.interval] and actives or nil
				else
					local int=bints[ls.interval] or {cc=ls.interval}
					bints[ls.interval]=int
					int.cc=int.cc+dt
					local c=false
					if int.cc>=ls.interval then
						int.cc=int.cc-ls.interval
						act=acblocks
						c=true
					end
					bint[ls.interval]=c
				end
			elseif st=="smooth" then
				if sint[ls.interval] then
					act=sint[ls.interval]
				else
					local int=sints[ls.interval] or {cc=0}
					int.cc=int.cc+dt*actc/ls.interval
					local cc=floor(int.cc)
					int.cc=int.cc-cc
					local acts={}
					for n=1,cc do
						local v=a[n]
						acts[v[1]]=v[2]
					end
					sint[ls.interval]=acts
					act=acts
				end
			end
			if act then
				arg.active_blocks=act
				ls.on_step(arg)
			end
		end
	end
end)

if E then
	for k,v in pairs(lib) do
		E.game[k]=v
	end
end
