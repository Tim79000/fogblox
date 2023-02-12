--[
local assert,ipairs,pairs,tostring,type,ItemStack,minetest
=     assert,ipairs,pairs,tostring,type,ItemStack,minetest
local unpack,ceil,inf =
	unpack or table.unpack,
	math.ceil,
	math.huge
--]

local usages={}
local gusages={}
local itgroups={}
local id=1
E.craft_usages=usages

local loaded=false
local deferred_gusages={}
local function defer_gusage(groups,recipe)
	if not loaded then
		deferred_gusages[#deferred_gusages+1]={defer_gusage,groups,recipe}
		return
	end
	for k,v in pairs(minetest.registered_items) do
		if E.check_groups(k,groups) then
			usages[k]=usages[k] or {}
			usages[k][recipe]=true
		end
	end
end
minetest.register_on_mods_loaded(function()
	loaded=true
	for _,v in ipairs(deferred_gusages) do
		v[1](unpack(v,2))
	end
	deferred_gusages=nil
end)

function E.game.recipe_check_default(recipe,inv,crafter)
	for oi,reciptem in ipairs(recipe.input) do
		local rname=reciptem:get_name()
		local groups=E.parse_groups(rname)
		local n=0
		local maxwear=0
		local toi=recipe.toolworn and recipe.toolworn[oi]
		if toi and reciptem:get_count()==1 then
			maxwear=65535-ceil((recipe.output[recipe.toolworn[oi]]):get_wear()*0.8)
		end
		for _,invitem in ipairs(inv) do
			local name=invitem:get_name()
			if name~="" and (groups
				and {E.check_groups(name,groups)}
				or {name==rname}
			)[1] and (not recipe.inputcheck
			or not recipe.inputcheck[oi]
			or recipe.inputcheck[oi](recipe,inv,crafter,invitem))
			and invitem:get_wear()<=maxwear then
				n=n+invitem:get_count()
			end
		end
		if n<reciptem:get_count() then return false end
	end
	return true
end

function E.game.recipe_craft_default(recipe,inv,crafter)
	local its={}
	local taken={}
	local worn={}
	local out={}
	for k,v in ipairs(recipe.output) do
		out[k]=v
	end
	for oi,reciptem in ipairs(recipe.input) do
		local rname=reciptem:get_name()
		local groups=E.parse_groups(rname)
		local c=reciptem:get_count()
		local wear=0
		local toi=recipe.toolworn and recipe.toolworn[oi]
		if toi and c==1 then
			wear=1
			if type(toi)=="table" then
				toi,wear=toi.target,toi.count
			end
			out[toi]=nil
		else
			toi=nil
		end
		for n=#inv,1,-1 do
			if c<=0 then break end
			local invitem=inv[n]
			local name=invitem:get_name()
			local uses
			if wear>0 then
				local caps=invitem:get_tool_capabilities()
				uses=inf
				local gcaps=caps.groupcaps or {}
				local uuses=0
				local count=0
				for k,v in pairs(gcaps) do
					if v.uses then
						uuses=uuses+v.uses
						count=count+1
					end
				end
				if count>0 then
					uses=uuses/count
				end
			end
			if (groups 
				and {E.check_groups(name,groups)} 
				or {name==rname}
			)[1] and (not recipe.inputcheck
			or not recipe.inputcheck[oi]
			or recipe.inputcheck[oi](recipe,inv,crafter,invitem)) then
				local itak=invitem:take_item(c)
				taken[#taken+1]=itak
				c=c-itak:get_count()
				if wear>0 then
					invitem:add_item(itak)
					local toolcaps=invitem:get_tool_capabilities()
					if uses<65535 then
						for n=1,wear do
							invitem:add_wear_by_uses(uses)
						end
					end
					taken[#taken]=nil
					worn[#worn+1]={n,invitem}
				end
			end
		end
	end
	local outs={}
	for k=1,#recipe.output do
		local v=out[k]
		if v then
			outs[#outs+1]=v
		end
	end
	return outs,taken,worn
end

local function defcheck(...)
	return E.game.recipe_check_default(...)
end

local function defcraft(...)
	return E.game.recipe_craft_default(...)
end

local function resolve_alias(name)
	assert(minetest.registered_items[name],"invalid craft element: "..tostring(name))
	return name
end

E.game.crafts={}
function E.game.register_craft(recipe)
	for k,v in ipairs(recipe.input) do
		local stack = ItemStack(v)
		local groups = E.parse_groups(stack:get_name())
		local name = (not groups) and resolve_alias(stack:get_name()) or nil
		recipe.input[k] = stack
		if groups then
			defer_gusage(groups,recipe)
		end
		if name and name~="" then
			usages[name]=usages[name] or {}
			usages[name][recipe]=true
		end
	end
	for k,v in ipairs(recipe.output) do
		local stack = ItemStack(v)
		local groups = E.parse_groups(stack:get_name())
		local name = (not groups) and resolve_alias(stack:get_name()) or nil
		recipe.output[k] = stack
	end
	recipe.discover_prereqs=recipe.discover_prereqs or {1}
	E.underride(recipe,{
		check=defcheck,
		craft=defcraft,
	})
	recipe.id=id
	E.game.crafts[id] = recipe
	id=id+1
end

function E.game.get_discovered_crafts(items)
	local recips={}
	for item,_ in pairs(items) do
		local item=ItemStack(item)
		local name=item:get_name()
		for v,_ in pairs(usages[name] or {}) do
			local satisf=true
			for _,req in pairs(v.discover_prereqs or {}) do
				local req=v.input[req]:get_name()
				local groups=E.parse_groups(req)
				if groups then
					local good=false
					for k,v in pairs(items) do
						if E.check_groups(k,groups) then
							good=true
							break
						end
					end
					if not good then satisf=false break end
				else
					if not items[req] then
						satisf=false
						break
					end
				end
			end
			if satisf then
				recips[v]=true
			end
		end
	end
	return recips
end

local function defer_unreg(groups,recipe)
	if not loaded then
		deferred_gusages[#deferred_gusages+1]={defer_unreg,groups,recipe}
		return
	end
	for k,v in pairs(usages) do
		v[recipe]=nil
	end
end
function E.game.unregister_craft(id)
	E.game.crafts[id]=nil
	for k,v in pairs(recipe.input) do
		local rname=v:get_name()
		local groups=E.parse_groups(rname)
		if groups then
			defer_unreg(groups,recipe)
		else
			usages[rname][recipe]=nil
		end
	end
end
