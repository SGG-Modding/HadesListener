ModUtil.Mod.Register( "StyxScribeAlarm" )

local runTime = _screenTime
local prefix = "StyxScribeAlarm:"

local function alarm()
	StyxScribe.Internal.debugMode = true
	StyxScribe.Send( prefix, "Alarm" )
	print( "StyxScribe is unresponsive! (" .. _screenTime - runTime .. ")" )
end

local buffer = true

local function doBuffer()
	buffer = true
end

local function checkBuffer()
	while true do
		waitScreenTime( 15 )
		if buffer == false then
			alarm( )
		end
		buffer = false
	end
end

StyxScribeAlarm.Internal = ModUtil.UpValues( function( )
	return alarm, buffer, doBuffer, checkBuffer
end )

StyxScribe.AddHook( doBuffer, { prefix, "Ping" }, StyxScribeAlarm )
thread( checkBuffer )