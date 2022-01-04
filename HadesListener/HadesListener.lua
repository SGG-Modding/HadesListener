ModUtil.Mod.Register("HadesListener")

local hooks = { }
local delay = 0.05
local print = ModUtil.Print
local debugCall = ModUtil.DebugCall
local notify

print( "HadesListener: Lua Refreshed!" )

local function startswith( s, p )
	local i = 1
	for c in p:gmatch( "." ) do
		if c ~= s:sub( i, i ) then return end
		i = i + 1
	end
	return s:sub( i )
end

local function poll( )
	local valid, msg = false
	local file = "proxy_stdin.txt"
	while true do
		if not valid then
			--print( "HadesListener: Polling...", file )
			valid, msg = debugCall( loadfile, file )
		end
		if valid and msg then
			valid = false
			setfenv( msg, _ENV )
			local out  = table.pack( debugCall( msg ) )
			file = table.unpack( out, 2, 2 )
			if out.n >= 3 then
				HadesListener.Notify( table.unpack( out, 3, out.n ) )
			end
		end
		debugCall( waitScreenTime, delay )
	end
end

function HadesListener.AddHook( hook, prefix )
	if prefix == nil then
		prefix = ""
	end
	if type( prefix ) ~= "string" then
		prefix = ModUtil.Identifiers.Inverse[ prefix ]
	end
	local base = hooks[ prefix ] or { }
	table.insert( base, hook )
	hooks[ prefix ] = base
end

function HadesListener.Notify( ... )
	for _, message in ipairs( { ... } ) do
		--print( "HadesListener: Received: " .. message )
		for prefix, callbacks in pairs( hooks ) do
			local tail = startswith( message, prefix )
			if tail then
				for _, callback in ipairs( callbacks ) do
					debugCall(callback, tail, function( s ) return print( prefix .. s ) end )
				end
			end
		end
	end
end

notify = HadesListener.Notify
thread( poll )

