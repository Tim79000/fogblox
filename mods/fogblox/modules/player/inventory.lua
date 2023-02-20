--[
local minetest,ipairs,pairs,ItemStack,tonumber
=     minetest,ipairs,pairs,ItemStack,tonumber
local sort,concat,insert,min,max,floor = 
	table.sort,
	table.concat,
	table.insert,
	math.min,
	math.max,
	math.floor
--]

local discovery={}
local drecipes={}
E.game.discovery=discovery

local formstate={}
local grcache={}
local function get_display_item(groups)
	if grcache[groups] then return grcache[groups] end
	local items=E.get_group_items(groups)
	local its={}
	for it,_ in pairs(items) do
		its[#its+1]=it
	end
	sort(its,function(a,b)
		local ad,bd =
			minetest.registered_items[a],
			minetest.registered_items[b]
		local agdp,bgdp=(ad.group_display_prio or 0),(bd.group_display_prio or 0)
		if agdp==bgdp then
			return a<b
		end
		return agdp>bgdp
	end)
	grcache[groups]=its[1]
	return its[1] or groups
end

local function display_item(form,x,y,item)
	local stack=ItemStack(item)
	local item=stack:to_string()
	local iname=stack:get_name()
	local groups=E.parse_groups(iname)
	local displ={}
	local grdispl=E.game.get_group_display(iname)
	local grnodis
	if groups and grdispl then
		E.rename_stack(stack,grdispl)
		item=stack:to_string()
		grnodis=true
	elseif groups then
		E.rename_stack(stack,get_display_item(iname))
		local meta=stack:get_meta()
		if meta:get_string("description")=="" then
			local gr={}
			for k,v in pairs(groups) do
				gr[#gr+1]=k
			end
			sort(gr)
			meta:set_string("description",M("Any %s"):format(concat(gr,"+"))())
		end
		item=stack:to_string()
	end
	form[#form+1]={"item_image",{x+0.1,y+0.1},{0.8,0.8},item}
	if groups and not grnodis then
		form[#form+1]={"image",{x+0.2,y+0.2},{0.6,0.6},E.tex"craft_group"}
	end
	form[#form+1]={"tooltip",{x,y},{1,1},stack:get_description()}
end

local function display_recipe(form,y,recipe)
	local x=0
	local badc,vbadc=
		"#808000","#800000"
	local button={"button",{0,y},{11,1},"craft"..recipe.id,""}
	local bad={"box",{0,y},{11,1},badc}
	local verybad={"box",{0,y},{11,1},vbadc}
	if not recipe.craftable then
		local el=bad
		if recipe.craftable==nil then
			el=verybad
		end
		form[#form+1]=el
	else
		form[#form+1]=button
	end
	for i,item in ipairs(recipe.input) do
		display_item(form,x,y,item)
		x=x+1
	end
	form[#form+1]={"image",{x+0.2,y+0.2},{0.6,0.6},E.tex("craft_arrow")}
	x=x+1
	for i,item in ipairs(recipe.output) do
		display_item(form,x,y,item)
		x=x+1
	end
end
E.display_recipe=display_recipe

local function parse_recipe(v,list,ref)
	local recipe={
		orig=v,
		input=v.input,
		output=v.output,
		id=v.id,
		prio=v.priority or 0,
		craftable=v:check(list,ref),
	}
	if not recipe.craftable then
		local brk=false
		for _,ritem in ipairs(recipe.input) do
			local rname=ritem:get_name()
			local groups=E.parse_groups(rname)
			for _,iitem in ipairs(list) do
				local iname=iitem:get_name()
				if iname~="" and (groups
					and {E.check_groups(iname,groups)}
					or {rname==iname}
				)[1] then
					brk=true break
				end
			end
			if brk then break end
		end
		if not brk then recipe.craftable=nil end
	end
	return recipe
end

function E.game.get_inventory_formspec(ref)
	local name=ref:get_player_name()
	local state=formstate[name]
  local form={
			{"formspec_version",6},
			{"size",{12,12}},
			{"list","current_player","main",{0.5,0.4+6+0.25},{9,4}},
	}
	local recipes={}
	local inv=ref:get_inventory()
	local ll=inv:get_list("main")
	local list={}
	for n=1,inv:get_width("main") do
		list[n]=ll[n]
	end
	form.items=list
	for v,_ in pairs(drecipes[name]) do
		if not state.sticky or state.sticky.recipe~=v then
			recipes[#recipes+1]=parse_recipe(v,list,ref)
		end
	end
	local cftable={[false]=1,[true]=2}
	sort(recipes,function(a,b)
		local acft,bcft=
			cftable[a.craftable] or 0,
			cftable[b.craftable] or 0
		if acft==bcft then
			if a.prio==b.prio then
				return a.id<b.id
			end
			return a.prio>b.prio
		end
		return acft>bcft
	end)
	local smax=max(1,#recipes*2-6*2)
	if state.sticky then
		insert(recipes,state.sticky.n,parse_recipe(state.sticky.recipe,list,ref))
		smax=max(state.sticky.scroll,smax)
	end
	state.scroll=min(smax,state.scroll or 0)
	local thumbsize=(6*2)/max(6*2+1,#recipes*2)
	form[#form+1]={"scrollbaroptions",
		"smallstep=1",
		"largestep=2",
		"arrows=show",
		"thumbsize="..floor(smax*thumbsize+0.5),
		"max="..smax,
	}
	form[#form+1]={"scrollbar",{0.3+11,0.4},{0.4,6},"vertical","scrollcraft",state.scroll or 0}
	form[#form+1]={"scroll_container",{0.3,0.4},{11,6},"scrollcraft","vertical",0.5}
	local drawn={}
	state.recipes=recipes
	for n,recipe in ipairs(recipes) do
		drawn[recipe.orig]=n
		local y=n-1
		display_recipe(form,y,recipe)
	end
	if state.sticky and not drawn[state.sticky.recipe] then
		local n=state.sticky.n
		local recipe=state.sticky.recipe
		local recip=recipes[state.sticky.n]
		drawn[recipe]=n
		local y=n-1
		display_recipe(form,y,recip)
	end
	state.drawn=drawn
	form[#form+1]={"scroll_container_end"}
	form.items=nil
	form=E.formspec(form)
	return form
end

local function build_invform(ref)
	ref:set_inventory_formspec(E.game.get_inventory_formspec(ref))
end

minetest.register_on_joinplayer(function(ref)
	local inv = ref:get_inventory()
	ref:hud_set_hotbar_itemcount(9)
	inv:set_width("main",9)
	inv:set_size("main",9*4)
	inv:set_size("craft",0)
	inv:set_size("craftresult",0)
	inv:set_size("craftpreview",0)
	local name=ref:get_player_name()
	local meta=ref:get_meta()
	discovery[name]=minetest.deserialize(meta:get_string(E.modname.."_discovery")) or {}
	drecipes[name]=E.game.get_discovered_crafts(discovery[name])
	formstate[name]={}
	build_invform(ref)
end)

minetest.register_on_leaveplayer(function(ref)
	local name=ref:get_player_name()
	discovery[name]=nil
	drecipes[name]=nil
	formstate[name]=nil
end)

function E.game.on_inventory_receive_fields(ref,fields)
	local name=ref:get_player_name()
	local state=formstate[name]
	local scroll
	local dirty
	if fields.scrollcraft then
		local ev=minetest.explode_scrollbar_event(fields.scrollcraft)
		if ev.type=="CHG" then
			state.scroll=ev.value
			if state.sticky then
				state.sticky=nil
				dirty=true
			end
		end
	end
	for k,v in pairs(fields) do
		if M(k):sub(1,5)()=="craft" then
			local id=tonumber(M(k):sub(6)())
			local recipe=id and E.game.crafts[id]
			local inv=ref:get_inventory()
			local list=inv:get_list("main")
			local ll={}
			local llc={}
			local w=inv:get_width("main")
			for n=1,w do
				ll[n]=list[n]
				llc[n]=ll[n]
			end
			if recipe and recipe:check(llc,ref) then
				if state.drawn and state.drawn[recipe] then
					state.sticky={
						n=state.drawn[recipe],
						recipe=recipe,
						scroll=state.scroll or 0
					}
				end
				local out=recipe:craft(ll,ref)
				_G.print(_G.dump{"crafting!",out})
				for n=1,#ll do
					list[n]=ll[n]
				end
				inv:set_list("main",list)
				inv:set_width("main",w)
				if out then
					for k,v in ipairs(out) do
						minetest.handle_node_drops(ref:get_pos(),{v},ref)
					end
				end
			end
		end
	end
	if dirty or fields.quit then
		state.sticky=nil
		build_invform(ref)
	end
end

minetest.register_on_player_receive_fields(function(ref,formname,fields)
	if formname=="" then
		return E.game.on_inventory_receive_fields(ref,fields)
	end
end)

function E.game.discover(name,item)
	local ref=minetest.get_player_by_name(name)
	if not ref then return end
	local meta=ref:get_meta()
	local item=ItemStack(item):get_name()
	if not discovery[name][item] then
		discovery[name][item]=true
		meta:set_string(E.modname.."_discovery",minetest.serialize(discovery[name]))
		drecipes[name]=E.game.get_discovered_crafts(discovery[name])
		build_invform(ref)
	end
end

function E.game.forger(name,item) --skull emoji
	local ref=minetest.get_player_by_name(name)
	if not ref then return end
	local meta=ref:get_meta()
	local item=ItemStack(item):get_name()
	if discovery[name][item] then
		discovery[name][item]=nil
		meta:set_string(E.modname.."_discovery",minetest.serialize(discovery[name]))
		drecipes[name]=E.game.get_discovered_crafts(discovery[name])
		build_invform(ref)
	end
end

local ithist={}
minetest.register_globalstep(function(dt)
	local histed={}
	for _,ref in ipairs(minetest.get_connected_players()) do
		local name=ref:get_player_name()
		if discovery[name] then
			histed[name]=true
			local inv=ref:get_inventory()
			local oldlist=ithist[name]
			local list=inv:get_list("main")
			ithist[name]=list
			local meta=ref:get_meta()
			for k,v in ipairs(list) do
				if v:get_count()>0 then
					E.game.discover(name,v)
				end
			end
			local dirty=false
			if oldlist then
				for k,v in ipairs(list) do
					if oldlist[k]:to_string()~=v:to_string() then
						dirty=true
					end
				end
				if dirty or #oldlist~=#list then
					build_invform(ref)
				end
			end
		end
	end
	for k,v in pairs(ithist) do
		if not histed[k] then
			ithist[k]=nil
		end
	end
end)

minetest.register_chatcommand("tabula",{
	param="rasa",
	func=function(name,param)
		if param~="rasa" then return end
		local ref=minetest.get_player_by_name(name)
		if not ref then return end
		discovery[name]={}
		drecipes[name]=E.game.get_discovered_crafts(discovery[name])
		local meta=ref:get_meta()
		meta:set_string(E.modname.."_discovery","")
		build_invform(ref)
	end
})
