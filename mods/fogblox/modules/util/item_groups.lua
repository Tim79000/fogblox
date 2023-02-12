--[
local type,pairs,ipairs,minetest
=     type,pairs,ipairs,minetest
local sort =
	table.sort
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
E.game.item_group_descs={}

function E.check_groups(item,groups)
	if type(groups)=="string" then groups=E.parse_groups(groups) end
	for gr,_ in pairs(groups) do
		if minetest.get_item_group(item,gr)<1 then
			return false
		end
	end
	return true
end

function E.get_group_items(groups)
	if type(groups)=="string" then groups=E.parse_groups(groups) end
	local gs={}
	for k,v in pairs(groups) do gs[#gs+1]=k end
	sort(gs,function(a,b)
		return a[1]<b[1]
	end)
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
