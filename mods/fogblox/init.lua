--[
local loadstring,DIR_DELIM,minetest,_G,error,dump,assert,setfenv,pairs,string,type,setmetatable,io
=     loadstring,DIR_DELIM,minetest,_G,error,dump,assert,setfenv,pairs,string,type,setmetatable,io
local unpack
=     unpack or table.unpack
local insert,concat
=     table.insert,
      table.concat
--]

local E={_G=_G}
local deadenv = setmetatable({},{__index=function(_,i)
	error(E.mstr("invalid global environemnt access: [%s]"):format(dump(i))(),2)
end,__newindex=function(_,i,v)
	error(E.mstr("invalid global environemnt access: [%s]=%s"):format(dump(i),dump(v))(),2)
end})
function E.noG()
	if setfenv then
		setfenv(2,deadenv)
	end
	return deadenv
end
local _ENV = E.noG()
E.deadenv = deadenv
E.modname = minetest.get_current_modname()
E.modpath = minetest.get_modpath(E.modname)

E.game={}
_G[E.modname]=E.game

local function L()
	local rope={}
	local function f(str)
		if str then
			insert(rope,str)
			return f
		end
		return concat(rope,"\n")
	end
	return f
end
E.L=L

local __mstr={}
__mstr.__index=__mstr
local cc="local __mstr,string,type,unpack=...\n"
for k,v in pairs(string) do
	if type(v)=="function" then
		cc=cc..L()(
		"local "..k.." = string."..k )(
		"__mstr."..k.." = function(self,...)" )(
		"  local ret = {"..k.."(self[1],...)}" )(
		"  if type(ret[1])==\"string\" then" )(
		"    self[1]=ret[1]" )(
		"    ret[1]=self" )(
		"  end" )(
		"  return unpack(ret)" )(
		"end")""()
	end
end
assert(loadstring(cc))(__mstr,string,type,unpack)
function __mstr:__call()
	return self[1]
end
function E.mstr(str)
	str=""..str
	return setmetatable({str},__mstr)
end
local M=E.mstr

local function normalize(path)
	local d = DIR_DELIM
	local nd = d=="/" and "\\" or "/"
	return (M(path)
		:gsub(nd,d)
		:gsub(d..d.."+",d)
		:gsub(d.."$","")())
end

local function open(path)
	local pp = path..".lua"
	local file,err = io.open(pp)
	local err2
	if not file then
		pp = path..DIR_DELIM.."init.lua"
		file,err2 = io.open(pp)
		assert(file,M("Failure. %s; %s"):format(err,err2 or "")())
	end
	return file,pp
end

function E.include(name)
	local d=DIR_DELIM
	local path = E.modpath..(M("."..name)
		:gsub("%.",d)
		:gsub("%^","..")())
	path=normalize(path)
	local file,pp = open(path)
	local data = file:read("*a")
	local envin="local _ENV = E.noG();--]"
	local enved
	data = M(data):gsub("^%-%-%[.-\n%-%-%]",function(a)
		enved=true
		return M(a):sub(1,-4)()..envin
	end)()
	data = "local E,include=...;local M=E.mstr;local _G=E._G;"
	..(not enved and M(envin):sub(1,-4)() or "")	
	..data
	local fn = assert(loadstring(data,M(name):gsub("^modules",E.modname)()))
	return fn(E,function(n)
		return E.include(name.."."..n)
	end)
end

local include = function(n)
	return E.include("modules."..n)
end

include("active")
include("util")
include("crafting")
include("player")
include("nature")
include("tech")
