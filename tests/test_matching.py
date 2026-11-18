"""Run with: python3 -m unittest discover -s tests"""
import importlib.machinery, importlib.util, os, unittest

_path = os.path.join(os.path.dirname(__file__), "..", "bin", "workspace-audio")
_loader = importlib.machinery.SourceFileLoader("workspace_audio", _path)
_spec = importlib.util.spec_from_loader("workspace_audio", _loader)
wa = importlib.util.module_from_spec(_spec)
_loader.exec_module(wa)

CHROME = {"pid": 100, "class": "google-chrome", "iclass": "google-chrome", "ws": 1}
GAME = {"pid": 200, "class": "mygame", "iclass": "mygame", "ws": 2}
SPOTIFY = {"pid": 300, "class": "spotify", "iclass": "spotify", "ws": 3}
CLIENTS = [CHROME, GAME, SPOTIFY]


class WindowsFor(unittest.TestCase):
    def test_child_process_walks_up_to_window(self):
        props = {"application.process.id": "150", "application.process.binary": "chrome"}
        ppids = {150: 120, 120: 100, 100: 1}
        hits = wa.windows_for(props, CLIENTS, ppids, comm=lambda p: "chrome")
        self.assertEqual(hits, [CHROME])

    def test_sandboxed_pid_falls_back_to_binary_name(self):
        # firejail reports PID 5 from its own namespace; host PID 5 is unrelated
        props = {"application.process.id": "5", "application.process.binary": "mygame",
                 "application.name": "My Game"}
        ppids = {5: 2, 2: 0}
        hits = wa.windows_for(props, CLIENTS, ppids, comm=lambda p: "kworker")
        self.assertEqual(hits, [GAME])

    def test_unrelated_host_pid_is_not_trusted(self):
        # namespaced PID collides with a host process under Chrome: must not match Chrome
        props = {"application.process.id": "150", "application.process.binary": "mygame"}
        ppids = {150: 100}
        hits = wa.windows_for(props, CLIENTS, ppids, comm=lambda p: "chrome")
        self.assertEqual(hits, [GAME])

    def test_app_name_matches_class(self):
        props = {"application.name": "Spotify"}
        self.assertEqual(wa.windows_for(props, CLIENTS, {}, comm=lambda p: ""), [SPOTIFY])

    def test_unknown_stream_has_no_window(self):
        props = {"application.name": "Something Else", "application.process.binary": "zz"}
        self.assertEqual(wa.windows_for(props, CLIENTS, {}, comm=lambda p: ""), [])


class Summarize(unittest.TestCase):
    def test_streams_of_one_app_are_merged(self):
        rows = [
            {"name": "Chrome", "class": "c", "ws": 1, "global": False, "muted": True, "auto": True},
            {"name": "Chrome", "class": "c", "ws": 1, "global": False, "muted": False, "auto": False},
            {"name": "alpha", "class": "a", "ws": 2, "global": False, "muted": False, "auto": False},
        ]
        out = wa.summarize(rows)
        self.assertEqual([e["name"] for e in out], ["alpha", "Chrome"])
        self.assertFalse(out[1]["muted"])   # one stream still audible
        self.assertTrue(out[1]["auto"])


if __name__ == "__main__":
    unittest.main()
