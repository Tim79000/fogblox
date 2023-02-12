--[
local ipairs,pairs,type
=     ipairs,pairs,type
local esc,concat,floor,ceil,abs =
	minetest.formspec_escape,
	table.concat,
	math.floor,
	math.ceil,
	math.abs
--]

local function trunc(n)
	return (n>0 and floor or ceil)(n)
end

local function formparam(par)
	if type(par)=="number" then
		local i,f=trunc(par),abs(par-trunc(par))
		par=M("%i"):format(i)()..M("%f"):format(f):sub(2):gsub("%.?0+$","")()
	end
	return par
end

function E.formspec(data)
	local rope = {}
	for _,elem in ipairs(data) do
		if type(elem)=="string" then
			rope[#rope+1]=elem
		else
			local params={}
			for k,par in ipairs(elem) do
				if k>1 then
					if type(par)=="string" or type(par)=="number" then
						params[k-1]=esc(formparam(par))
					else
						local subpars={}
						for k,v in ipairs(par) do
							subpars[k]=esc(formparam(v))
						end
						params[k-1]=concat(subpars,",")
					end
				end
			end
			rope[#rope+1]=M("%s[%s]"):format(esc(elem[1]),concat(params,";"))()
		end
	end
	return concat(rope,"\n")
end
