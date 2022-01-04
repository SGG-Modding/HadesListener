load = lambda listener: listener.add_hook( lambda msg, send: send( " TestAlt: " + msg ), "TEST", __name__ )
