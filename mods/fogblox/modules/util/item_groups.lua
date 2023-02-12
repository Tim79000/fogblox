--[
local type,pairs,ipairs,minetest
=     type,pairs,ipairs,minetest
local sort,concat =
	table.sort,
	table.concat
--]

function E.parse_groups(item)
	if type(item)~="string" then return end
	if M(item):sub(1,6)()~="group:" then return end
	local groups={}
	for a in M(item):sub(7):gmatch("([^,]+)") do
		groups[a]=true
	end
	return groups
end

local groups={}
local _groups=groups
E.game.item_groups=groups

function E.check_groups(item,groups)
	if type(groups)=="string" then groups=E.parse_groups(groups) end
	for gr,_ in pairs(groups) do
		if minetest.get_item_group(item,gr)<1 then
			return false
		end
	end
	return true
end

local function groupkey(groups)
	if type(groups)=="string" then groups=E.parse_groups(groups) end
	if not groups then return end
	local gs={}
	for k,v in pairs(groups) do gs[#gs+1]=k end
	sort(gs)
	return E.modname..":gd_"..minetest.sha1(concat(gs,","))
end

function E.game.register_group_display(groups,def,base)
	local bdef=minetest.registered_items[base] or {type="node"}
	minetest.register_item(groupkey(groups),E.underride(def,bdef))
end

function E.game.get_group_display(groups)
	local name=groupkey(groups)
	if not name then return end
	if not minetest.registered_items[name] then return end
	return name
end

function E.get_group_items(groups)
	if type(groups)=="string" then groups=E.parse_groups(groups) end
	local gs={}
	for k,v in pairs(groups) do gs[#gs+1]=k end
	sort(gs)
	local items
	for _,group in ipairs(gs) do
		local its={}
		for item,_ in pairs(_groups[group]) do
			if item~=1 then
				its[item]=true
			end
		end
		if not items then items=its end
		for k,v in pairs(items) do
			if not its[k] then items[k]=nil end
		end
	end
	return items
end

minetest.register_on_mods_loaded(function()
	for name,def in pairs(minetest.registered_items) do
		for group,c in pairs(def.groups or {}) do
			if minetest.get_item_group(name,group)>0 then
				groups[group]=groups[group] or {}
				groups[group][name]=true
			end
		end
	end
	for k,v in pairs(groups) do
		local size=0
		v[1]=nil
		for k,v in pairs(v) do
			size=size+1
		end
		v[1]=size
	end
end)
