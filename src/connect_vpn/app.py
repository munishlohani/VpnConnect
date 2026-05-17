from textual.app import App
from connect_vpn.splash import Splash
from connect_vpn.home import Home
from connect_vpn.setup import Setup
from connect_vpn.config import load_config
import subprocess


VPN_BIN = "/opt/cisco/secureclient/bin/vpn"


class TerminalOS(App):
    CSS_PATH = "styles.css"

    vpn_status = "unknown"


    def on_mount(self):
        self.push_screen(Splash())
        self.sync_vpn_status()
        self.set_timer(2, self.route)


    def route(self):
        cfg = load_config() or {}
        profiles = cfg.get("vpn", {}).get("profiles", {})
        self.push_screen(Setup() if not profiles else Home())

    def show_home(self):
        self.switch_screen(Home())

    def switch_setup(self):
        self.switch_screen(Setup())


    def vpn_is_connected(self) -> bool:

        try:
            result = subprocess.run(
                [VPN_BIN, "state"],
                capture_output=True,
                text=True,
                check=False,
            )

            output = (result.stdout or "")
            return "Connected" in output

        except Exception:
            return False

    def get_vpn_state(self) -> str:

        if self.vpn_is_connected():
            return "connected"
        return "unbinded"

    def sync_vpn_status(self):

        self.vpn_status = self.get_vpn_state()
        return self.vpn_status


    def disconnect_vpn(self):

        try:
            subprocess.run(
                [VPN_BIN, "disconnect"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
        except Exception:
            pass

        if self.vpn_is_connected():
            try:
                subprocess.run(["pkill", "-f", "vpn"], check=False)
            except Exception:
                pass

        self.vpn_status = "disconnected"


    def on_shutdown_request(self):

        self.disconnect_vpn()

    def on_unmount(self):

        self.disconnect_vpn()