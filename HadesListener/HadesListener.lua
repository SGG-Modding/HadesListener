ModUtil.Mod.Register("HadesListener")

local hooks = { }

function HadesListener.AddHook( prefix, hook )
	if type( prefix ) ~= "string" then
		prefix = ModUtil.Identifiers.Inverse[ prefix ]
	end
	local base = hooks[ prefix ] or { }
	table.insert( base, hook )
	hooks[ prefix ] = base
end

local function poll( ... )

  local valid, msg = pcall( load )
  if not valid then return print( msg ) end
  local threaded, delay, file = false, true
  local thread, wait = thread, wait
  local loadfile, pcall, setfenv = loadfile, pcall, setfenv
  local loadOnce, debugCall = ModUtil.LoadOnce, ModUtil.DebugCall

  local function wpoll( )
    while threaded do
      pcall( wait, delay )
      if not threaded return end
      epoll( )
    end
  end
  local bpoll
  local function epoll( ) 
    if not valid and file then
      valid, msg = pcall( loadfile, file )
    end
    return bpoll( )
  end
  function bpoll( )
    if valid then
      setfenv( msg, _ENV )
      file, delay = debugCall( msg, ... )
      valid = false
    end
    if not delay then
      threaded = false
      return epoll( )
    end
    if delay == true then
      threaded = false
      return loadOnce( epoll )
    end
    if not threaded then
      threaded = true
      return thread( wpoll )
    end
  end

  return bpoll( )
end
return poll( hooks )
