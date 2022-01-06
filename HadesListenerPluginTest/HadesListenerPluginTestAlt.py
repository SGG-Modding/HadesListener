load = lambda : listener.add_hook( lambda msg: listener.send( "TEST TestAlt: " + msg ), "TEST", __name__ )
