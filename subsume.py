from hades_listener import HadesListener

with open("out.txt","w") as file:
    prefix = ""
    def read(x): 
        x = x[len(prefix):]
        print(x)
        file.write(x+'\n')
    subsume = HadesListener()
    subsume.load_plugins()
    subsume.add_hook(prefix,read)
    subsume.launch(False)
