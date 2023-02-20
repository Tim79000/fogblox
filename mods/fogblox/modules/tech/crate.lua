--[
local minetest,ItemStack,pairs,ipairs,next
=     minetest,ItemStack,pairs,ipairs,next
local game,concat,random =
	E.game,table.concat,math.random
--]

local mn = E.modname
local tex = E.tex

minetest.register_node(mn..":crate",{
		description = "Crate",
		tiles={tex "crate"},
		groups={choppy=1},
		on_construct=function(pos,node)
			local meta=minetest.get_meta(pos)
			local inv=meta:get_inventory()
			inv:set_size("main",9*3)
			local location=M("nodemeta:%i,%i,%i"):format(pos.x,pos.y,pos.z)()
			local form=E.formspec {
				{"formspec_version",4},
				{"size",{0.25+9*1.25,0.25+8*1.25}},
				{"list",location,"main",{0.25,0.25},{9,3},nil},
				{"list","current_player","main",{0.25,0.25+4*1.25},{9,4},nil},
				{"listring",location,"main"},
				{"listring","current_player","main"},
			}
			meta:set_string("formspec",form)
		end,
		after_place_node=function(pos,node,stack)
			local meta=stack:get_meta()
			local list=minetest.deserialize(meta:get_string("stored_inventory"))
			if not list then return end
			for k,v in pairs(list) do
				list[k]=ItemStack(v)
			end
			local nmeta=minetest.get_meta(pos)
			local inv=nmeta:get_inventory()
			inv:set_list("main",list)
		end,
		allow_metadata_inventory_put=function(pos,listname,index,stack,putter)
			local imeta=stack:get_meta()
			if imeta:get_string("stored_inventory")~="" then
				return 0
			end
			return stack:get_count()
		end,
		preserve_metadata=function(pos,node,oldmeta,drops)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			local list = inv:get_list("main")
			local it=drops[1]
			if it:get_name()~=mn..":crate" then
				return
			end
			local imeta=it:get_meta()
			local counts={}
			local stackl={}
			for k,v in ipairs(list) do
				local count=v:get_count()
				if count>0 then
					local id=ItemStack(v)
					id:set_count(1)
					id=id:to_string()
					if not counts[id] then
						stackl[#stackl+1]=id
						counts[id]=0
					end
					counts[id]=counts[id]+count
				end
				list[k]=v:to_string()
			end
			if next(counts) then
				imeta:set_string("unstackablifier",random()..random())
				imeta:set_string("stored_inventory",minetest.serialize(list))
				local desc=it:get_description()
				local strs={}
				for n,id in ipairs(stackl) do
					local stack=ItemStack(id)
					local count=counts[id]
					local wear=stack:get_wear()
					local str=M(stack:get_description()):gsub("\n.+$","...")()
					if wear>0 then
						str=M("(%.1f%%) "):format(wear/65535*100)()..str
					end
					if count>1 then
						str=M("(%i) "):format(count)()..str
					end
					strs[#strs+1]=str
				end
				desc=desc.." {\n"..concat(strs,",\n").."\n}"
				imeta:set_string("description",desc)
			end
		end
})

game.register_craft {
	input={"group:tool_hammer1",mn..":plank 4",mn..":stick 8",mn..":pebble 2"},
	output={"group:tool_hammer1",mn..":crate"},
	toolworn={1}
}
