ModUtil.Mod.Register( "HadesListenerShared" )

local registry
local lookup
local objectData
local encode
local decode
local new

local meta = {
	__call = function( )
		return new( )
	end,
	__newindex = function( s, k, v )
		local I = tostring( lookup[ s ] )
		local K = encode( k )
		local V = encode( v )
		objectData[ s ][ k ] = v
		print( "HadesListenerShared: Set: " .. I .. '¦' .. K .. '¦' .. V )
	end,
	__index = function( s, k )
		return objectData[ s ][ k ]
	end,
	__len = function( s )
		return #objectData[ s ]
	end,
	__next = function( s, ... )
		return next( objectData[ s ], ... )
	end,
	__inext = function( s, ... )
		return inext( objectData[ s ], ... )
	end,
	__pairs = function( s, ... )
		return pairs( objectData[ s ], ... )
	end,
	__ipairs = function( s, ... )
		return ipairs( objectData[ s ], ... )
	end
}

function new( id )
	local s = setmetatable( { }, meta )
	id = id or tonumber( ModUtil.ToString.Address( s ), 16 )
	objectData[ s ] = { }
	registry[ id ] = s
	lookup[ s ] = id
	if id > 0 then
		print( "HadesListenerShared: New: " .. id )
	end
	return s
end

local function handleNew( message )
	return new( -tonumber( message ) )
end

--https://stackoverflow.com/a/33312901
local function split( text, delim )
    -- returns an array of fields based on text and delimiter (one character only)
    local result = { }
    local magic = "().%+-*?[]^$"

    if delim == nil then
        delim = "%s"
    elseif string.find( delim, magic, 1, true ) then
        -- escape magic
        delim = "%" .. delim
    end

    local pattern = "[^" .. delim .. "]+"
    for w in string.gmatch( text, pattern ) do
        table.insert( result, w )
    end
    return result
end

function decode( s )
	local t, v = s:sub(1,1), s:sub(2)
	if t == "&" then return v end
	if t == "#" then return tonumber( v ) end
	if t == "@" then return registry[ -tonumber( v ) ] end
	if t == "!" then return v == "!" end
	if t == "*" then return nil end
	error( s .. " cannot be decoded.", 2 )
end

function encode( v )
	local t, m = type( v ), getmetatable( v )
	if t == "string" then return "&" .. v end
	if t == "number" then return "#" .. tostring( v ) end
	if m == meta then return "@" .. tostring( lookup[ v ] ) end
	if t == "boolean" then return v and "!!" or "!" end
	if v == nil then return "*" end
	error( tostring( v ) .. " cannot be encoded.", 2 )
end

local function handleSet( message )
	local id, key, value = table.unpack( split( message, '¦') )
	id = -tonumber( id )
	key = decode( key )
	value = decode( value )
	objectData[ registry[ id ] ][ key ] = value
end

local function handleReset( )
	registry = { }
	lookup = setmetatable( { }, { __mode = "k" } )
	objectData = setmetatable( { }, { __mode = "k" } )
	HadesListener.Shared = new( 0 )
	print( "HadesListenerShared: Reset" )
end

HadesListenerShared.Internal = ModUtil.UpValues( function( )
	return registry, lookup, objectData, getObjectData, handleNew, handleSet, handleReset, decode, encode
end )

handleReset( )
HadesListener.AddHook( handleNew, "HadesListenerShared: New: ", HadesListenerShared )
HadesListener.AddHook( handleSet, "HadesListenerShared: Set: ", HadesListenerShared )