ModUtil.Mod.Register("StyxScribe")

local hooks = { }
local earlyHooks = { }
local storage = { }
local pollPeriod = 0.25
local pollDelay = 0.01
local prefixLua = "Lua:"
local prefixDebugPrint = "DebugPrint: "
local prefixDebugMessage = "DebugMessage: "
local prefixDebugAssert = "DebugAssert: "
local prefixStyxScribe = "StyxScribe: "
local proxyFile = "proxy_stdin.txt"
local showDebugPrint = false
local showDebugMessage = false
local showDebugAssert = false
local errorsHalt = false
local printHooks = false

ModUtil.Path.Wrap( "print", function( base, ... )
	local msg = table.rawconcat( table.pack( ... ), '\t' ):gsub('\n', '\n' .. prefixLua .. '\t')
	return base( prefixLua, msg )
end, StyxScribe )

local pcall, xpcall, loadfile, select, rawipairs, rawpairs, yield, resume, traceback =
	pcall, xpcall, loadfile, select, rawipairs or ipairs, rawpairs or pairs, coroutine.yield, coroutine.resume, debug.traceback

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

local function addHook( hooks, callback, prefix, source )
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
	if printHooks then
		send( prefixStyxScribe .. "Adding hook on \"" .. prefix .. 
			"\" with " .. tostring( callback ) .. ( source and ( " from " .. source ) or "" ) )
	end
end

function StyxScribe.AddHook( ... )
	return addHook( hooks, ... )
end

function StyxScribe.AddEarlyHook( ... )
	return addHook( earlyHooks, ... )
end

local function isPromise( promise )
    return type( promise ) == "thread"
end

local function callPromise( call, ... )
	local status, info, co
	if isPromise( call ) then
		co = call
		status, info = resume( call, ... )
	else
		status, info = xpcall( call, traceback, ... )
		if status and isPromise( info ) then
			co = info
			status, info = resume( promise )
		end
	end
	if not status then
		send( co and traceback( co, info ) or info )
		if errorsHalt then
			error( "error in callback " .. tostring( call ) )
		end
	end
end

local function store( ... )
	local i = #storage
	for _, message in vararg( ... ) do
		if debugMode then send( prefixStyxScribe .. "Received: " .. message ) end
		i = i + 1
		storage[ i ] = message
	end
end

local function notifyMessage( message, hooks )
	for prefix, callbacks in rawpairs( hooks ) do
		local tail = startswith( message, prefix )
		if tail then
			for _, callback in rawipairs( callbacks ) do
				callPromise( callback, tail )
			end
		end
	end
end

local function notify( )
	local n = #storage
	for i = 1, n, 1 do
		notifyMessage( storage[ i ], earlyHooks )
	end
	for i = 1, n, 1 do
		notifyMessage( storage[ i ], hooks )
		storage[ i ] = nil
	end
end

local debugMode = false

local waitArgs = setmetatable( { screenTime = true }, {
	__index = function( _, k )
		if k == "wait" then return pollPeriod end
		if k == "threadInfo" then return lastGoodThreadInfo end
		return nil
	end
} )

local function handle( valid, file, ... )
	if valid then store( ... ) end
	return valid, file
end

function poll( )
	local file
	while true do
		file = file or proxyFile
		if debugMode then send( prefixStyxScribe .. "Polling...", file, _screenTime ) end
		local valid, nextfile = handle( pcall( dofile, file ) )
		if valid then
			file = nextfile
			notify( )
		end
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

if DebugMessage then
	ModUtil.Path.Wrap( "DebugMessage", function( base, args, ... )
		if showDebugMessage then 
			send( prefixDebugMessage .. args.Text )
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
	return debugMode, pollDelay, pollPeriod, notify, proxyFile, showDebugPrint, showDebugAssert, showDebugMessage,
		prefixLua, prefixDebugPrint, prefixDebugAssert, prefixDebugMessage, prefixStyxScribe, errorsHalt, printHooks,
		startswith, vararg, hooks, poke, poll, handle, waitArgs, callPromise, isPromise, storage, store, notifymessage, addHook
end )