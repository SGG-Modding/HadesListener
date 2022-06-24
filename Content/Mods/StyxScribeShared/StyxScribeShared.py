from weakref import WeakKeyDictionary
from numbers import Number
from collections import OrderedDict
from inspect import getmembers
from functools import wraps
from threading import local as thread_local
from types import MethodType

proxy_types = dict()
marshall_types = OrderedDict()
DELIM = '¦'
NIL = None

registry = None
lookup = None
Root = None

#https://stackoverflow.com/a/49013535
_meta_ignore = {"__repr__","__format__","__str__","__reduce__","__reduce_ex__","__sizeof__"}
_meta_inherited = {}
def _meta_wrap(name, method):
    local_flag = thread_local()
    @wraps(method)
    def wrapper(*args, **kw):
        local_method = method
        if not getattr(local_flag, "running", False) and args and not isinstance(args[0], type):
            local_flag.running = True
            # trigger __getattribute__:
            self = args[0]
            cls = self.__class__
            retrieved = cls.__getattribute__(self, name)
            if not retrieved is wrapper:
                local_method =  retrieved
            if isinstance(local_method, MethodType):
                args = args[1:]
        result = local_method(*args, **kw)
        local_flag.running = False
        return result
    wrapper._wrapped = True
    return wrapper
class MetaOverrider(type):
    def __init__(cls, name, bases, namespace, **kwd):
        super().__init__(name, bases, namespace, **kwd)
        
        global _meta_inherited
        d = None
        for c in cls.__mro__:
            if "Proxy" not in map(lambda _c: _c.__name__, c.__mro__):
                _cls = c
                d = inherited(_cls, cls)
                break
        _meta_inherited[cls] = d

        for name in dir(cls):
            if not (name.startswith("__") and name.endswith("__")):
                continue
            if name in ("__getattribute__", "__class__", "__init__"):
                continue
            if name in object.__dict__ and name not in _meta_ignore:
                continue
            if d is not None and name not in d:
                continue
            magic_method = getattr(cls, name)
            if not callable(magic_method) or getattr(magic_method, "_wrapped", False):
                continue
            setattr(cls, name, _meta_wrap(name, magic_method))

def nop():
    pass

def inherited(a,b):
    #https://stackoverflow.com/a/48281090
    a = dict(getmembers(a))
    b = dict(getmembers(b))
    return {k:v for k,v in b.items() if k in a and v == a[k]}

class _function():
    def __init__(self,call=None):
        if call is None:
            call = nop
        self.call = call
    def __call__(self,*args,**kwargs):
        return self.call(*args,**kwargs)
    def __repr__(self):
        return repr(self.call)

def not_implemented(self, *args, **kwargs):
    raise NotImplementedError(f"{type(self)} does not implement this operation")

def proxytype(cls):
    proxy_types[cls.__name__] = cls
    return cls

def marshalltype(*types):
    def f(cls):
        for t in types:
            mt = marshall_types.get(cls,set())
            mt.add(t)
            marshall_types[cls] = mt
        return cls
    return f

class Proxy(metaclass=MetaOverrider):
    def __init__(self, v=None, i=None):
        #initialise a new object to proxy, select from inheritance
        for cls in type(self).__mro__:
            if Proxy not in cls.__mro__:
                proxy = cls()
                break
        if i is None:
            i = id(self)
        self.proxy = proxy
        self.alive = True
        registry[i] = self
        lookup[self] = i
        self.root = i == 0
        self.local = i > 0
        if self.local:
            scribe.send(f"StyxScribeShared: New: {self.__class__.__name__}{DELIM}{i}")
        if v is not None:
            self._marshall(v)
    def __hash__(self):
        return hash(id(self))
    def __repr__(self):
        return repr(self.proxy)
    def __del__(self):
        i = lookup.get(self,None)
        if i is not None:
            self.alive = False
            try:
                del lookup[self]
            except KeyError:
                pass
            if i != 0:
                try:
                    del registry[i]
                except KeyError:
                    pass
                if self.local:
                    scribe.send(f"StyxScribeShared: Del: {i}")
    def __getattribute__(self, name):
        if name in _meta_inherited[type(self)]:
            proxy = object.__getattribute__(self, "proxy")
            try:
                attr = getattr(proxy, name)
                if callable(attr) and attr.__self__ == proxy:
                    return lambda s,*a,**k: attr(*a,**k)
                return attr
            except AttributeError:
                pass
        return object.__getattribute__(self, name)       

class ProxySet(Proxy):
    def _shset(self, key, val):
        if self.alive:
            i = lookup[self]
            k = encode(key)
            v = encode(val)
            scribe.send(f"StyxScribeShared: Set: {i}{DELIM}{k}{DELIM}{v}")

class ProxyCall(Proxy):
    def _marshall(self, obj):
        if callable(obj):
            self.proxy = obj
        else:
            raise TypeError(f"{type(self)} cannot marshall type {type(obj)}")

@proxytype
@marshalltype(dict, set)
class Table(ProxySet, dict):
    def _marshall(self, obj):
        if isinstance(obj, set):
            for k in obj:
                self[k] = True
        elif isinstance(obj, dict):
            for k,v in obj.items():
                self[k] = v
        raise TypeError(f"{type(self)} cannot marshall type {type(obj)}")
    def __setitem__(self, key, val, sync=True):
        if val is NIL:
            return self.__delitem__(key, sync)
        val = marshall(val)
        key = marshall(key)
        self.proxy[key] = val
        
        if sync:
            self._shset(key, val)
    def __delitem__(self, key):
        del self.proxy[key]
        key = marshall(key)
        if sync:
            self._shset(key, val)
    def __getitem__(self, key):
        try:
            return self.proxy[key]
        except KeyError:
            return NIL
    setdefault = not_implemented
    update = not_implemented
    pop = not_implemented
    popitem = not_implemented
    clear = not_implemented

@proxytype
@marshalltype(list, tuple)
class Array(ProxySet, list):
    def _marshall(self, obj):
        enum = None
        try:
            enum = enumerate(obj)
        except TypeError:
            raise TypeError(f"{type(self)} cannot marshall type {type(obj)}")
        for k,v in enum:
            self[k] = v
    def __setitem__(self, key, val, sync=True):
        if val is NIL:
            return self.__delitem__(key, sync)

        key = marshall(key)
        if key > len(self.proxy):
            return
        val = marshall(val)
        if key == len(self.proxy):
            self.proxy.append(val)
        else:
            self.proxy[key] = val
        if sync:
            self._shset(key + 1, val)
    def __delitem__(self, key, sync=True):
        d = key - len(self.proxy) + 1
        if d < 0:
            for i in range(d):
                del self.proxy[-1]
        del self.proxy[key]
        key = int(marshall(key))
        if sync:
            self._shset(key, NIL)
    def __getitem__(self, key):
        try:
            return self.proxy[key]
        except KeyError:
            return NIL
    append = not_implemented
    extend = not_implemented
    insert = not_implemented
    remove = not_implemented
    sort = not_implemented
    reverse = not_implemented
    pop = not_implemented
    clear = not_implemented

@proxytype
@marshalltype(list, tuple)
class Args(ProxySet, list):
    def _marshall(self, obj):
        enum = None
        try:
            enum = enumerate(obj)
        except TypeError:
            raise TypeError(f"{cls} cannot marshall type {type(obj)}")
        for k,v in enum:
            self[k] = v
    def __setitem__(self, key, val, sync=True):
        if val is NIL:
            return self.__delitem__(key, sync)

        n = len(self.proxy)
        if key == 'n':
            val = marshall(val)
            if val >= n:
                self.proxy.extend([NIL]*(val - n))
            if val < n:
                self.proxy[::] = self.proxy[:val]
        else:
            key = marshall(key)
            val = marshall(val)
            if key > n:
                self.proxy.extend([NIL]*(key - n)+[val])
            if key == len(self.proxy):
                self.proxy.append(val)
            else:   
                self.proxy[key] = val
        if sync:
            self._shset(key if key == 'n' else key + 1, val)
    def __delitem__(self, key, sync=True):
        key = marshall(key)
        if key >= len(self.proxy):
            return
        self.proxy[key] = NIL
        if sync:
            self._shset(key, NIL)
    def __getitem__(self, key):
        if key == 'n':
            return len(self.proxy)
        try:
            return self.proxy[key]
        except KeyError:
            return NIL
    append = not_implemented
    extend = not_implemented
    insert = not_implemented
    remove = not_implemented
    sort = not_implemented
    reverse = not_implemented
    pop = not_implemented
    clear = not_implemented

@proxytype
@marshalltype(_function)
class Action(ProxyCall, _function):
    def __call__(self, *args):
        if self.local:
            self.proxy(*args)
        else:
            i = lookup[self]
            a = Args(args)
            ai = lookup[a]
            scribe.send(f"StyxScribeShared: Act: {i}{DELIM}{ai}")

def marshaller(obj):
    if isinstance(obj,Proxy):
        return None
    for c,ts in marshall_types.items():
        for t in ts:
            if isinstance(obj,t):
                return c
            if callable(obj) and t is _function:
                return c
    return None

def marshall(obj):
    m = marshaller(obj)
    if m is not None:
        return m(obj)
    if isinstance(obj,str):
        return obj.replace(DELIM,':')
    if isinstance(obj,float):
        if float.is_integer(obj):
            return int(obj)
    return obj

def encode(v):
    if isinstance(v, bool):
        return "!!" if v else "!"
    if isinstance(v, str):
        return "&" + v
    if isinstance(v, Number):
        return "#" + str(v)
    if isinstance(v, Proxy):
        return "@" + str(lookup[v])
    if v is NIL:
        return "*"
    raise TypeError(f"{v} of type {type(v)} cannot be encoded.")

def decode(s):
    t = s[:1]
    v = s[1:]
    if t == "&":
        return v
    if t == "#":
        if v.isdigit():
            return int(v)
        return float(v)
    if t == "@":
        return registry[-int(v)]
    if t == "!":
        return v[0] == '!'
    if t == "*":
        return NIL
    raise TypeError(s + " cannot be decoded.")

def handle_new(message):
    t, i = message.split(DELIM)
    val = proxy_types[t](None, -int(i))
    return val

def handle_set(message):
    i, k, v = message.split(DELIM)
    try:
        s = registry[-int(i)]
    except KeyError:
        return
    k = decode(k)
    if v[:1] == '&':
        v = v[:-1]
    v = decode(v)
    s.__setitem__(k, v, False)

def handle_del(message):
    i = -int(message)
    obj = registry.get(i,None)
    if obj is not None:
        obj.alive = False
        try:
            del lookup[obj]
        except KeyError:
            pass
        if i != 0:
            try:
                del registry[i]
            except KeyError:
                pass

def handle_act(message):
    func, args = message.split(DELIM)
    func = registry[-int(func)]
    args = registry[-int(args)]
    func(*args)

def handle_reset(message=None):
    global registry
    global lookup
    global obj_data
    global Root
    if registry is not None:
        registry.clear()
    registry = {}
    if lookup is not None:
        lookup.clear()
    lookup = WeakKeyDictionary()
    Root = Table(None, 0)
    scribe.send( "StyxScribeShared: Reset" )

def load():
    scribe.add_hook(handle_reset, "StyxScribeShared: Reset", __name__)
    scribe.add_hook(handle_new, "StyxScribeShared: New: ", __name__)
    scribe.add_hook(handle_set, "StyxScribeShared: Set: ", __name__)
    scribe.add_hook(handle_del, "StyxScribeShared: Del: ", __name__)
    scribe.add_hook(handle_act, "StyxScribeShared: Act: ", __name__)
    scribe.ignore_prefixes.append("StyxScribeShared:")

def run():
    handle_reset()