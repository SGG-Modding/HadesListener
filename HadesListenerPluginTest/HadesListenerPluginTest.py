prefix = "TEST"
def callback( msg ):
    listener.send( prefix + " Test: " + msg )
