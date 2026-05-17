from textual.app import App
from splash import Splash
from home import Home
from config import load_config
from setup import Setup
import subprocess
import sys
import signal


class TerminalOS(App):
    CSS_PATH = "styles.css"
    vpn_status = "unbinded" 
    vpn_process = None   

    def on_mount(self):
        self.push_screen(Splash())
        self.set_timer(2, self.route)


    def route(self):
        cnf = load_config() or {}
        profiles = cnf.get("vpn", {}).get("profiles", {})
        self.push_screen(Setup() if not profiles else Home())


    def show_home(self):
        self.switch_screen(Home())

    def switch_setup(self):
        self.switch_screen(Setup())

    def on_shutdown(self):
        self.disconnect_vpn()

    def disconnect_vpn(self):
        if getattr(self, "vpn_process", None) is not None:
            try:
                proc = self.vpn_process
                if proc.poll() is None:
                    proc.terminate()
                    proc.wait(timeout=5)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass
            finally:
                self.vpn_process = None

        cmd = [
            "/opt/cisco/secureclient/bin/vpn",
            "disconnect"
        ]
        try:
            subprocess.run(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
                check=False,
            )
        except Exception:
            pass

        self.vpn_status = "unbinded"




def cleanup(*args):

    try:
        subprocess.run([
            "/opt/cisco/secureclient/bin/vpn",
            "disconnect"
        ])

    except:
        pass

    sys.exit(0)


signal.signal(signal.SIGINT, cleanup)

signal.signal(signal.SIGTERM, cleanup)



if __name__ == "__main__":
    TerminalOS().run()