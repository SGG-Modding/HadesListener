#repurposed from https://stackoverflow.com/questions/2408560/non-blocking-console-input/57387909#57387909

_globals = globals().copy()
_locals = {}
run = str

import threading
import sys
from traceback import format_exception_only

def exception_string():
    return "".join(format_exception_only(*(sys.exc_info()[:2])))

class KeyboardThread(threading.Thread):

    def __init__(self, input_cbk = None, name='keyboard-input-thread'):
        self.input_cbk = input_cbk
        super(KeyboardThread, self).__init__(name=name)
        self.start()

    def run(self):
        while True:
            self.input_cbk(input()) #waits to get input + Return

def my_callback(inp):
    #evaluate the keyboard input
    if inp:
        if inp[:1] == ">":
            try:
                eval(compile(inp[1:].lstrip(), '<string>', 'single'), _globals, _locals)
            except Exception:
                print(exception_string(),end='')
        else:
            run(inp)

#start the Keyboard thread
kthread = KeyboardThread(my_callback)

first = True
prefix = "HadesListenerREPL: "
def callback( msg, send ):
    global run
    global first
    if first:
        run = send
        _globals["run"] = send
        first = False
