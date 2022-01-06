from weakref import WeakKeyDictionary

registry = None
lookup = None
obj_data = None
def get_obj_data(obj, key):
    return obj_data[obj][key]

class Shared():
    def __init__(self, data):
        obj_data[self] = data

def new(i=None):
    t = {}
    if i is None:
        i = id(t)
    s = Shared(t)
    registry[i] = s
    lookup[s] = i
    if i > 0:
        listener.send( "HadesListenerShared: New: " + i )
    return s

def handle_new(message):
    return new(-int(message))

def handle_reset(message):
    global registry
    global lookup
    global obj_data
    registry = {}
    lookup = WeakKeyDictionary()
    obj_data = WeakKeyDictionary()
    new(0)

def load():
    listener.add_hook( handle_reset, "HadesListenerShared: Reset", __name__)
    listener.add_hook( handle_new, "HadesListenerShared: New: ", __name__)
    
