from hades_listener import HadesListener


def test_hook(output):
    print(f"HadesListener found: {output}")


def test_hook_two(output):
    print(f"HadesListener found a different pattern: {output}")


hades_listener = HadesListener()
hades_listener.add_hook("$: ", test_hook)
hades_listener.add_hook("#: ", test_hook_two)
hades_listener.launch()
