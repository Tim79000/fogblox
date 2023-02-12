--[
local pairs,type,error,ItemStack,minetest
=     pairs,type,error,ItemStack,minetest
local ceil,inf =
	math.ceil,
	math.huge
--]

local function underride(t,b,b2,...)
	if b2 then underride(t,b2,...) end
	for k,v in pairs(b) do
		if t[k]==nil then
			t[k]=v
		elseif type(v)=="table"
		   and type(t[k])=="table" then
			underride(t[k],v)
		end
	end
	return t
end
E.underride, E.game.underride
= underride, underride

local vol = {
	footstep=0.2,
	dig=0.5,
	dug=1,
	place=0.8,
	place_failed=0.2,
	fall=0.1,
}
function E.game.sounds(name,gains,pitch)
	local t={}
	gains=gains or {}
	for k,v in pairs(vol) do
		t[k]={
			name=name,
			gain=gains[k] or v,
			pitch=pitch
		}
	end
	return t
end

function E.game.gsounds(n,...)
	return E.game.sounds(E.modname.."_"..n,...)
end

function E.tex(name)
	return E.modname.."_"..M(name):gsub("%W","_")()..".png"
end

local btimes={
	snappy=0.3,
	crumbly=0.5,
	choppy=1,
	cracky=1,
	thumpy=1,
}
function E.game.toolcaps(data)
	local caps={}
	for k,v in pairs(data.groups) do
		local times={}
		for n=1,v do
			times[n]=((n/v)^0.5*(data.speed or btimes[k] or error(k)))
		end
		caps[k]={uses=data.uses,times=times,maxlevel=0}
	end
	return {
		__uses=data.uses or inf,
		groupcaps=caps
	}
end

function E.worn_stack(stack,group)
	stack=ItemStack(stack)
	local tool=stack:get_name()
	local uses=minetest.registered_items[tool]
		.tool_capabilities
		.groupcaps
		[group].uses or math.huge
	local wear=ceil(65535/uses)
	stack:add_wear(wear)
	return stack
end

function E.rename_stack(stack,new)
	local m,c,w=stack:get_meta():to_table(),stack:get_count(),stack:get_wear()
	stack:set_name(new)
	stack:get_meta():from_table(m)
	stack:set_count(c)
	stack:set_wear(w)
end
