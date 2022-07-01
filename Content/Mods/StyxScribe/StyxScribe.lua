ModUtil.Mod.Register("StyxScribe")

local hooks = { }
local pollPeriod = 0.25
local pollDelay = 0.01
local prefixLua = "Lua:"
local prefixDebugPrint = "DebugPrint: "
local prefixDebugAssert = "DebugAssert: "
local prefixStyxScribe = "StyxScribe: "
local proxyFile = "proxy_stdin.txt"
local showDebugPrint = false
local showDebugAssert = false

ModUtil.Path.Wrap( "print", function( base, ... )
	return base( prefixLua, ... )
end, StyxScribe )

local pcall, loadfile, select, rawipairs, rawpairs, yield =
	pcall, loadfile, select, rawipairs or ipairs, rawpairs or pairs, coroutine.yield

local send = print
StyxScribe.Send = send

send( prefixStyxScribe .. "Lua Refreshed!" )

local function startswith( s, p )
	local i = 1
	for c in p:gmatch( "." ) do
		if c ~= s:sub( i, i ) then return end
		i = i + 1
	end
	return s:sub( i )
end

--http://lua-users.org/wiki/VarargTheSecondClassCitizen
local vararg
do
	local i, t, l = 0, {}
	local function iter(...)
		i = i + 1
		if i > l then return end
		return i, t[i]
	end

	function vararg(...)
		i = 0
		l = select("#", ...)
		for n = 1, l do
			t[n] = select(n, ...)
		end
		for n = l+1, #t do
			t[n] = nil
		end
		return iter
	end
end

function StyxScribe.AddHook( callback, prefix, source )
	if source ~= nil then
		if type( source ) ~= "string" then
			source = ModUtil.Identifiers.Data[ source ]
		end
		if type( prefix ) ~= "string" then
			prefix = source .. ": "
		end
	end
	local base = hooks[ prefix ] or { }
	table.insert( base, callback )
	hooks[ prefix ] = base
	send( prefixStyxScribe .. "Adding hook on \"" .. prefix .. 
		"\" with " .. tostring( callback ) .. ( source and ( " from " .. source ) or "" ) )
end

local function notify( ... )
	for _, message in vararg( ... ) do
		if debugMode then send( prefixStyxScribe .. "Received: " .. message ) end
		for prefix, callbacks in rawpairs( hooks ) do
			local tail = startswith( message, prefix )
			if tail then
				for _, callback in rawipairs( callbacks ) do
					callback( tail )
				end
			end
		end
	end
end

local debugMode = false

local waitArgs = setmetatable({ screenTime = true }, {
	__index = function( _, k )
		if k == "wait" then return pollPeriod end
		if k == "threadInfo" then return lastGoodThreadInfo end
		return nil
	end
})

local function handle( valid, file, ... )
	if valid then notify( ... ) end
	return valid, file
end

local function poll( )
	local file
	while true do
		file = file or proxyFile
		if debugMode then send( prefixStyxScribe .. "Polling...", file, _screenTime ) end
		local valid, nextfile = handle( pcall( dofile, file ) )
		if valid then file = nextfile end
		yield( waitArgs )
	end
end
thread( poll )

local function poke( )
	waitScreenTime( pollDelay )
	return send( prefixStyxScribe .. "Polling..." )
end
thread( poke )

if DebugAssert then
	ModUtil.Path.Wrap( "DebugAssert", function( base, args, ... )
		if showDebugAssert and not args.Condition then
			send( prefixDebugAssert .. args.Text )
		end
		return base( args, ... )
	end, StyxScribe )
end

if DebugPrint then
	ModUtil.Path.Wrap( "DebugPrint", function( base, args, ... )
		if showDebugPrint then 
			send( prefixDebugPrint .. args.Text )
		end
		return base( args, ... )
	end, StyxScribe )
end

StyxScribe.Internal = ModUtil.UpValues( function( )
	return debugMode, pollDelay, pollPeriod, notify, proxyFile, showDebugPrint, showDebugAssert,
		prefixLua, prefixDebugPrint, prefixDebugAssert, prefixStyxScribe,
		startswith, vararg, hooks, poke, poll, handle, waitArgs
end )