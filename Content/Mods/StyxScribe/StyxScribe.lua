ModUtil.Mod.Register("StyxScribe")

local hooks = { }
local delay = 0.25
local notify
local print, pcall, loadfile, select, rawipairs, rawpairs, yield = print, pcall, loadfile, select, rawipairs or ipairs, rawpairs or pairs, coroutine.yield

print( "StyxScribe: Lua Refreshed!" )

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
	print( "StyxScribe: Adding hook on \"" .. prefix .. "\" with " .. tostring( callback ) .. ( source and ( " from " .. source ) or "" ) )
end

function StyxScribe.Notify( ... )
	for _, message in vararg( ... ) do
		--print( "StyxScribe: Received: " .. message )
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

notify = StyxScribe.Notify

do
	local waitArgs = setmetatable({ screenTime = true }, {
		__index = function( _, k )
			if k == "wait" then return delay end
			if k == "threadInfo" then return lastGoodThreadInfo end
			return nil
		end
	})
	
	local function handle( valid, file, ... )
		if valid then notify( ... ) end
		return valid, file
	end

	local function poll( )
		local file = "proxy_stdin.txt"
		while true do
			--print( "StyxScribe: Polling...", file, _screenTime )
			local valid, nextfile = handle( pcall( dofile, file ) )
			if valid then file = nextfile end
			yield( waitArgs )
		end
	end
	thread( poll )
	
	local function poke( )
		waitScreenTime( 0.01 )
		return print( "StyxScribe: Polling..." )
	end
	thread( poke )
end

if DebugAssert then
	ModUtil.Path.Wrap( "DebugAssert", function( base, args )
		if not args.Condition then print( "DebugAssert: " .. args.Text ) end
		return base( args )
	end, StyxScribe )
end

if DebugPrint then
	ModUtil.Path.Wrap( "DebugPrint", function( base, args )
		print( "DebugPrint: " .. args.Text )
		return base( args )
	end, StyxScribe )
end