from textual.screen import Screen
from textual.widgets import Input, Button, Static
from config import load_config, save_config, encrypt_password


class AddProfile(Screen):

    def compose(self):
        yield Button("X", id="exit", classes="exit-button")
        yield Input(placeholder="Profile name", id="name")
        yield Input(placeholder="Server", id="server")
        yield Input(placeholder="Username", id="username")
        yield Input(placeholder="Group", id="group", type="number")
        yield Input(placeholder="Password", id="password",password=True)
        yield Input(placeholder="Passcode Method", id="passcode")

        yield Button("Save", id="save")
        yield Static("", id="error")

    def on_button_pressed(self, event):
        if event.button.id == "exit":
            self.app.exit()
            return

        if event.button.id != "save":
            return

        cfg = load_config()

        name = self.query_one("#name").value
        server = self.query_one("#server").value
        username = self.query_one("#username").value
        group = self.query_one("#group").value or 1
        password = self.query_one("#password").value
        passcode=self.query_one("#passcode").value or 1


        if not name or not server or not username:
            self.query_one("#error").update("⚠ Fill all required fields")
            return

        entry = {
            "server": server,
            "username": username,
            "group": group,
            "passcode":passcode
        }

        if password:
            entry["password"] = encrypt_password(password)

        cfg["vpn"]["profiles"][name] = entry

        save_config(cfg)

        from home import Home

        self.app.push_screen(Home())