from weakref import WeakKeyDictionary
from numbers import Number

registry = None
lookup = None

def not_implemented(*args, **kwargs):
    raise NotImplemented("Cannot used shared object this way.")

class Shared(dict):
    def __call__(self):
        return __class__()
    def __hash__(self):
        return hash(id(self))
    def __init__(self, i=None):
        if i is None:
            i = id(self)
        registry[i] = self
        lookup[self] = i
        if i > 0:
            listener.send("HadesListenerShared: New: " + str(i))
    def __setitem__(self, key, val):
        if val is None:
            return self.__delitem__(key)
        if isinstance(val, int):
            val = float(val)
        i = str(lookup[self])
        k = encode(key)
        v = encode(val)
        super(__class__, self).__setitem__(key, val)
        listener.send("HadesListenerShared: Set: " + i + '¦' + k + '¦' + v)
    def __delitem__(self, key):
        i = str(lookup[self])
        k = encode(key)
        v = encode(None)
        super(__class__, self).__delitem__(key)
        listener.send("HadesListenerShared: Set: " + i + '¦' + k + '¦' + v)
    def __getitem__(self, key):
        try:
            return super(__class__, self).__getitem__(key)
        except KeyError:
            return None
    setdefault = not_implemented
    update = not_implemented
    pop = not_implemented
    popitem = not_implemented
    clear = not_implemented
    
def decode(s):
    t = s[:1]
    v = s[1:]
    if t == "&":
        return v
    if t == "#":
        return float(v)
    if t == "@":
        return registry[-int(v)]
    if t == "!":
        return v == "!"
    if t == "*":
        return None
    raise TypeError(s + " cannot be decoded.")


def encode(v):
    if isinstance(v, str):
        return "&" + v
    if isinstance(v, Number):
        return "#" + str(v)
    if isinstance(v, Shared):
        return "@" + str(lookup[v])
    if isinstance(v, bool):
        return "!!" if v else "!"
    if v is None:
        return "*"
    raise TypeError(v + " cannot be encoded.")

def handle_new(message):
    return Shared(-int(message))

def handle_set(message):
    i, k, v = message.split('¦')
    k = decode(k)
    v = decode(v)
    s = super(Shared, registry[-int(i)])
    if v is None:
        s.__delitem__(k)
    else:
        s.__setitem__(k, v)

def handle_reset(message):
    global registry
    global lookup
    global obj_data
    registry = {}
    lookup = WeakKeyDictionary()
    listener.shared = Shared(0)

def load():
    listener.add_hook(handle_reset, "HadesListenerShared: Reset", __name__)
    listener.add_hook(handle_new, "HadesListenerShared: New: ", __name__)
    listener.add_hook(handle_set, "HadesListenerShared: Set: ", __name__)
    listener.ignore_prefixes.append("HadesListenerShared:")
