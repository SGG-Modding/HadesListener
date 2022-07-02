ModUtil.Mod.Register( "StyxScribeShared" )

local delim = '¦'

local registry
local lookup
local objectData
local encode
local decode
local marshall

local classes = { }
local marshallTypes = { }
local marshallTypesOrder = { }
local NONE = { }
local ready = false

local function nop( ... ) return ... end

local function typeCall( m, f )
	local f = f or function( cls, ... )
		return cls:_new( ... )
	end
	local mm = getmetatable( m ) or { }
	mm.__call = f
	return setmetatable( m, mm )
end

local function marshallType( ... )
	local types = { ... }
	local m = table.remove( types )
	table.insert( marshallTypesOrder, m )
	for _, t in ipairs( types ) do
		mt = marshallTypes[ m ] or { }
		table.insert( mt, t )
		marshallTypes[ m ] = mt
	end
	return m
end

-- mirror the structure of the python classes as metatables (mostly)
local function class( name, ... )
	local metas = table.pack( ... )
	local n = metas.n
	local m = metas[ n ]
	for i = n - 1, 1, -1 do
		metas[ i + 1 ] = metas[ i ]
	end
	metas[ 1 ] = m
	local meta = { }
	for i = n, 1, -1 do
		for k, v in pairs( metas[ i ] ) do
			meta[ k ] = v
		end
	end
	if name ~= nil then
		meta._name = name
		classes[ name ] = meta
	end
	meta._parents = { table.unpack( metas, 2, n ) }
	return meta
end

local function new( m, ... )
	return m:_new( ... )
end

local _table = {
	_new = function( )
		return { }
	end
}

local _function = {
	_new = function( )
		return nop
	end
}

local Proxy = {
	_proxy = true,
	__gc = function( s )
		local data = objectData[ s ]
		if data ~= nil then
			data[ "alive" ] = false
		end
		local i = lookup[ s ]
		if i ~= nil then
			lookup[ s ] = nil
			if i ~= 0 then
				registry[ i ] = nil
				StyxScribe.Send( "StyxScribeShared: Del: " .. tostring( i ) )
			end
		end
		
	end,
	_new = function( m, ... )
		local s = setmetatable( { }, m )
		return (m._init or nop)( s, ... )
	end,
	_init = function( s, v, i )
		local meta = getmetatable( s )
		i = i or tonumber( ModUtil.ToString.Address( s ), 16 )
		objectData[ s ] = { }
		objectData[ s ][ "proxy" ] = meta:_newproxy( )
		objectData[ s ][ "alive" ] = true
		registry[ i ] = s
		lookup[ s ] = i
		objectData[ s ][ "root" ] = i == 0
		objectData[ s ][ "local" ] = i > 0
		if objectData[ s ][ "local" ] then
			StyxScribe.Send( "StyxScribeShared: New: " .. meta._name .. delim .. i )
		end
		if v then
			meta._marshall( s, v )
		end
		return s
	end,
	__tostring = function( s )
		local name = objectData[ s ][ "name" ]
		name = name and name .. ': ' or ""
		return name .. getmetatable( s )._name .. ': ' .. ModUtil.ToString.Address( s ) 
	end
}

local ProxySet = class( nil, Proxy, {
	_shset = function( s, k, v )
		local i = tostring( lookup[ s ] )
		k = encode( k )
		v = encode( v )
		StyxScribe.Send( "StyxScribeShared: Set: " .. i .. delim .. k .. delim .. v )
	end,
	_marshall = function( s, obj )
		for k, v in pairs( obj ) do
			s[ k ] = v
		end
	end,
	_newproxy = function( m )
		return { }
	end
} )

local ProxyCall = class( nil, Proxy, {
	_marshall = function( s, f )
		objectData[ s ][ "proxy" ] = f
	end,
	_newproxy = function( m )
		return nop
	end,
	_call = function( s, args )
		return s( table.unpack( args ) )
	end
} )

local Table = marshallType( "table", class( "Table", ProxySet, {
	__newindex = function( s, k, v, sync )
		k, v = marshall( k ), marshall( v )
		objectData[ s ][ "proxy" ][ k ] = v
		local meta = getmetatable( s )
		if sync == nil or sync then
			meta._shset( s, k, v )
		end
	end,
	__index = function( s, k )
		return objectData[ s ][ "proxy" ][ k ]
	end,
	__len = function( s )
		return #objectData[ s ][ "proxy" ]
	end,
	__next = function( s, ... )
		return next( objectData[ s ][ "proxy" ], ... )
	end,
	__inext = function( s, ... )
		return inext( objectData[ s ][ "proxy" ], ... )
	end,
	__pairs = function( s, ... )
		return pairs( objectData[ s ][ "proxy" ], ... )
	end,
	__ipairs = function( s, ... )
		return ipairs( objectData[ s ][ "proxy" ], ... )
	end
} ) )

local Array = marshallType( "table", typeCall( class( "Array", ProxySet, {
	__newindex = function( s, k, v, sync )
		k, v = marshall( k ), marshall( v )
		local proxy = objectData[ s ][ "proxy" ]
		local n = #proxy
		if type( k ) ~= "number" or math.floor( k ) ~= k then
			error( "Array index must be an integer" , 2 )
		end
		if k > n + 1 or k < 1 then
			error( "Array index " .. tostring( k ) .." out of bounds" , 2 )
		end
		proxy[ k ] = v
		local meta = getmetatable( s )
		if sync == nil or sync then
			meta._shset( s, k - 1, v )
		end
	end,
	__index = function( s, k )
		return objectData[ s ][ "proxy" ][ k ]
	end,
	__len = function( s )
		return #objectData[ s ][ "proxy" ]
	end,
	__next = function( s, ... )
		return inext( objectData[ s ][ "proxy" ], ... )
	end,
	__inext = function( s, ... )
		return inext( objectData[ s ][ "proxy" ], ... )
	end,
	__pairs = function( s, ... )
		return ipairs( objectData[ s ][ "proxy" ], ... )
	end,
	__ipairs = function( s, ... )
		return ipairs( objectData[ s ][ "proxy" ], ... )
	end
} ) ) )

local Args = marshallType( "table", typeCall( class( "Args", ProxySet, {
	__newindex = function( s, k, v, sync )
		k, v = marshall( k ), marshall( v )
		local proxy = objectData[ s ][ "proxy" ]
		local n = proxy.n or #proxy
		if k == 'n' then
			if v < n then
				for i = v + 1, n, 1 do
					proxy[ i ] = nil
				end
			end
		else
			if type( k ) ~= "number" or math.floor( k ) ~= k then
				error( "Args index must be an integer" , 2 )
			end
			if k < 1 then
				error( "Args index " .. tostring( k ) .." out of bounds" , 2 )
			end
			if k >= n then
				proxy.n = k
			end
		end
		proxy[ k ] = v
		local meta = getmetatable( s )
		if sync == nil or sync then
			meta._shset( s, k ~= 'n' and k - 1 or k, v )
		end
	end,
	__index = function( s, k )
		return objectData[ s ][ "proxy" ][ k ]
	end,
	__len = function( s )
		return objectData[ s ][ "proxy" ][ 'n' ]
	end,
	__next = function( s, ... )
		return next( objectData[ s ][ "proxy" ], ... )
	end,
	__inext = function( s, ... )
		local k, v = next( objectData[ s ][ "proxy" ], ... )
		if k == 'n' then
			k, v = next( objectData[ s ][ "proxy" ], k )
		end
		return k, v
	end,
	__pairs = function( s, ... )
		return pairs( objectData[ s ][ "proxy" ], ... )
	end,
	__ipairs = function( s, ... )
		return qrawipairs( objectData[ s ][ "proxy" ], ... )
	end
} ), function( cls, ... ) return cls:_new( ... ) end ) )

local KWArgs = marshallType( "table", typeCall( class( "KWArgs", Table, {
	__newindex = function( s, k, v, sync )
		k, v = marshall( k ), marshall( v )
		objectData[ s ][ "proxy" ][ k ] = v
		local meta = getmetatable( s )
		if sync == nil or sync then
			if type( k ) == "number" then
				k = k - 1
			end
			meta._shset( s, k, v )
		end
	end
} ) ) )

local Action = marshallType( "function", typeCall( class( "Action", ProxyCall, {
	__call = function( s, ... )
		if objectData[ s ][ "local" ] then
			objectData[ s ][ "proxy" ]( ... )
		else
            local i = tostring( lookup[ s ] )
            local a = new( Args, table.pack( ... ) )
            local ai = tostring( lookup[ a ] )
            StyxScribe.Send( "StyxScribeShared: Act: " .. i .. delim .. ai )
		end
	end
} ) ) )

local KWAction = typeCall( class( "KWAction", Action, { 
	__call = function( s, kwargs )
		if objectData[ s ][ "local" ] then
			objectData[ s ][ "proxy" ]( kwargs )
		else
            local i = tostring( lookup[ s ] )
            local a = new( KWArgs, kwargs )
            local ai = tostring( lookup[ a ] )
            StyxScribe.Send( "StyxScribeShared: Act: " .. i .. delim .. ai )
		end
	end,
	_call = function( s, args )
		return s( args )
	end
} ) )

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

local function marshaller( obj )
	local t = type( obj )
	local m = getmetatable( obj )
    if m and m._proxy then return end
    for _, m in ipairs( marshallTypesOrder ) do
		for _, _t in pairs( marshallTypes[ m ] ) do
			if t == _t then
				return m
			end
		end
	end
end

function marshall( obj )
    if obj == NONE then return nil end
    local m = marshaller( obj )
    if m then return new( m, obj ) end
    if type( obj ) == "string" then
        return obj:gsub( delim, ':' )
	end
    return obj
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
	if m and m._proxy then return "@" .. tostring( lookup[ v ] ) end
	if t == "boolean" then return v and "!!" or "!" end
	if v == nil or v == NONE then return "*" end
	error( tostring( v ) .. " cannot be encoded.", 2 )
end

local function handleNew( message )
	if not ready then return end
	local name, id = table.unpack( split( message, delim ) )
	return new( classes[ name ], nil, -tonumber( id ) )
end

local function handleDel( message )
	if not ready then return end
	id = -tonumber( message )
	obj = registry[ id ]
	if obj ~= nil then
		objectData[ obj ][ "alive" ] = false
		registry[ id ] = nil
	end
end

local function handleSet( message )
	if not ready then return end
	local id, key, value = table.unpack( split( message, delim ) )
	local obj = registry[ -tonumber( id ) ]
	key = decode( key )
	value = decode( value )
	local meta = getmetatable( obj )
	meta.__newindex( obj, key, value, false )
end

local function handleAct( message )
	if not ready then return end
	local func, args = table.unpack( split( message, delim ) )
    func = registry[ -tonumber( func ) ]
    args = registry[ -tonumber( args ) ]
    getmetatable(func)._call( func, args )
end

local function handleName( message )
	if not ready then return end
	local id, name = table.unpack( split( message, delim ) )
	local obj = registry[ -tonumber( id ) ]
	objectData[ obj ][ "name" ] = decode( name )
end

local function handlePyReset( )
	ready = true
end

local function handleLuaReset( )
	ready = false
	registry = { }
	lookup = setmetatable( { }, { __mode = "k" } )
	objectData = setmetatable( { }, { __mode = "k" } )
	StyxScribeShared.Root = new( Table, nil, 0 )
	StyxScribe.Send( "StyxScribeShared: Reset" )
end

function StyxScribeShared.SetName( proxy, name )
	objectData[ proxy ][ "name" ] = name
	local id = tostring( lookup[ proxy ] )
	StyxScribe.Send( "StyxScribeShared: Name: " .. id .. delim .. encode( name ) )
end

function StyxScribeShared.GetName( proxy )
	return objectData[ obj ][ "name" ]
end

StyxScribeShared.Internal = ModUtil.UpValues( function( )
	return registry, lookup, delim, objectData, split, class, new, nop,
		marshallType, marshallTypes, marshaller, marshall, _table, _function,
		Proxy, ProxySet, ProxyCall, typeCall, decode, encode, ready,
		handleNew, handleSet, handleReset, handleAct, handleDel, handlePyReset, handleName,
		NONE, Table, Array, Args, Action, KWArgs, KWAction
end )

ModUtil.Table.Merge( StyxScribeShared, {
	NONE = NONE, Table = Table, Array = Array, Action = Action, KWArgs = KWArgs, KWAction = KWAction
} )

StyxScribe.AddHook( handlePyReset, "StyxScribeShared: Reset", StyxScribeShared )
StyxScribe.AddHook( handleName, "StyxScribeShared: Name: ", StyxScribeShared )
StyxScribe.AddHook( handleNew, "StyxScribeShared: New: ", StyxScribeShared )
StyxScribe.AddHook( handleSet, "StyxScribeShared: Set: ", StyxScribeShared )
StyxScribe.AddHook( handleDel, "StyxScribeShared: Del: ", StyxScribeShared )
StyxScribe.AddHook( handleAct, "StyxScribeShared: Act: ", StyxScribeShared )
handleLuaReset( )