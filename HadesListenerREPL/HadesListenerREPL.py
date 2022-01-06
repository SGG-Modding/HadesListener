#repurposed from https://stackoverflow.com/questions/2408560/non-blocking-console-input/57387909#57387909

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

run = str

def my_callback(inp):
    #evaluate the keyboard input
    if inp:
        if inp[:1] == "=":
            try:
                print(eval(inp[1:], globals()))
            except Exception:
                print(exception_string())
        elif inp[:1] == ".":
            try:
                exec(inp[1:], globals())
            except Exception:
                print(exception_string())
        else:
            if inp[:1] == ";":
                inp = "return " + inp[1:]
            run(inp)

#start the Keyboard thread
kthread = KeyboardThread(my_callback)

prefix = "HadesListenerREPL: Awake"
def callback( msg, send ):
    global run
    run = send
