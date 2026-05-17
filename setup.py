from textual.screen import Screen
from textual.widgets import Static, Button
from textual.containers import Container
from config import load_config


class Setup(Screen):

    def compose(self):
        yield Static("VPN Setup", id="title")
        yield Button("Add Profile", id="add")
        yield Button("Back", id="back")
        yield Container(id="profiles")

    def on_mount(self):
        self.refresh_profiles()

        cfg = load_config() or {}
        profiles = cfg.get("vpn", {}).get("profiles", {})

        if not profiles:
            self.call_later(self.auto_open_add)

    def on_resume(self):
        self.refresh_profiles()

    def refresh_profiles(self):
        container = self.query_one("#profiles")
        container.remove_children()

        cfg = load_config() or {}
        profiles = cfg.get("vpn", {}).get("profiles", {})

        if not profiles:
            container.mount(Static("No profiles found"))
            return

        for name, data in profiles.items():
            container.mount(
                Static(f"{name} ==> {data['server']} ({data['username']})")
            )
    def auto_open_add(self):
        from vpn.setup import AddProfile
        self.app.switch_screen(AddProfile())

    def on_button_pressed(self, event):
        if event.button.id == "add":
            from vpn.setup import AddProfile
            self.app.push_screen(AddProfile())

        elif event.button.id == "back":
            from home import Home
            self.app.switch_screen(Home())