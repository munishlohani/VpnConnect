from textual.screen import Screen
from textual.widgets import Static, Button
from textual.containers import Vertical
from connect_vpn.config import load_config, StatusIndicator


class Home(Screen):



    def compose(self):


        cfg = load_config() or {}
        profiles = cfg.get("vpn", {}).get("profiles", {})

        yield Vertical(
         Button("X", id="exit", classes="exit-button"),
         Static("VPNConnect", id="title")

        )

        yield StatusIndicator(f"Status: {self.app.vpn_status}", id="status")
        if not profiles:
            yield Static("VPN: No profiles configured", id="no-profiles")

        yield Static("Options", id="section-title")



        if "connected" not in self.app.vpn_status:
            yield Button("Connect VPN", id="connect")
        else:
            yield Button("Disconnect", id="disconnect")
        yield Button("Setup / Profiles", id="setup")
        yield Button("Refresh", id="refresh")

        yield Static("\nProfiles")

        if not profiles:
            yield Static("No profiles found")
        else:
            for name, data in profiles.items():
                yield Static(f"{name} → {data['server']} ({data['username']})")

    def on_button_pressed(self,event):
        if event.button.id=="setup":
            from connect_vpn.setup import Setup
            self.app.switch_screen(Setup())

        if event.button.id=="refresh":
            from connect_vpn.home import Home
            self.app.switch_screen(Home())

        if event.button.id == "connect":
            from connect_vpn.vpn.connect import VPNScreen
            self.app.switch_screen(VPNScreen())

        if event.button.id == "disconnect":
            
            self.app.disconnect_vpn()
            from connect_vpn.home import Home
            self.app.switch_screen(Home())

        if event.button.id == "exit":
            self.app.exit()

    def get_status(self):
        return self.query_one("#status", StatusIndicator)
