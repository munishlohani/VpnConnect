from textual.screen import Screen
from textual.widgets import Static, Button
from textual.containers import Container
import subprocess
from config import load_config, decrypt_password
from textual.widgets import RichLog
from textual import work
from config import StatusIndicator




try:
    import pexpect
except Exception:
    pexpect = None



class VPNScreen(Screen):

    def compose(self):
        yield Static("Connect To VPN", id="title")

        yield StatusIndicator(self.app.vpn_status, id="status")

        yield Container(id="vpn_container")
        yield RichLog(id="log")
        yield Button("GO Back", id="back")

    def log_line(self, line):
        log = self.query_one("#log")
        log.write(line)

    def on_button_pressed(self, event):
        button_id = event.button.id

        if button_id.startswith("connect_"):
            profile_name = button_id.replace("connect_", "")
            self._run_vpn(profile_name)

        if event.button.id == "back":
            from home import Home
            self.app.push_screen(Home())

        if event.button.id == "disconnect":
            self._disconnect()

    def on_mount(self):
        self.load_profiles()


    def load_profiles(self):
        container = self.query_one("#vpn_container")
        container.remove_children()
        container.refresh(layout=True)

        cfg = load_config() or {}
        profiles = cfg.get("vpn", {}).get("profiles", {})

        if not profiles:
            container.mount(Static("No profiles found"))
            return

        if self.app.vpn_status == 'unbinded':
            for name, data in profiles.items():
                container.mount(
                    Button(
                        f"{name} → {data['server']}",
                        id=f"connect_{name}"
                    )
                )
        else:
            container.mount(
                Button(
                    "Disconnect",
                    id="disconnect",
                )
            )
    @work(thread=True)
    def _run_vpn(self, profile_name):
        status = self.query_one("#status", StatusIndicator)
        log = self.query_one("#log")

        try:
            status.set_connecting()
            self.app.vpn_status = "connecting"

            cfg = load_config() or {}
            profile = cfg.get("vpn", {}).get("profiles", {}).get(profile_name)
            if not profile:
                raise ValueError(f"VPN profile not found: {profile_name}")

            server = profile.get("server")
            username = profile.get("username")
            password = decrypt_password(profile.get("password"))
            group = profile.get("group", "")
            passcode = profile.get("passcode", "")

            if not server or not username:
                raise ValueError("Profile is missing required server or username")

            cmd = [
                "/opt/cisco/secureclient/bin/vpn",
                "-s",
                "connect",
                server,
            ]

            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )

            self.app.vpn_process = process
            input_data = f"{group}\n{username}\n{password or ''}\n{passcode or ''}\n"
            process.stdin.write(input_data)
            process.stdin.flush()
            process.stdin.close()

            success = False
            for line in process.stdout:
                line = line.strip()
                self.call_later(log.write, line)
                if "state: Connected" in line:
                    self.call_later(status.set_connected)
                    self.app.vpn_status = f"connected: {server}"
                    success = True

            process.wait()
            if not success:
                raise RuntimeError("VPN did not report a connected state")
        except Exception as exc:
            self.call_later(log.write, f"Error: {exc}")
            self.call_later(status.set_disconnected)
            self.app.vpn_status = "unbinded"
            try:
                self.app.disconnect_vpn()
            except Exception:
                pass
        finally:
            self.app.vpn_process = None
            self.call_later(self.load_profiles)
    @work(thread=True)
    def _disconnect(self):
        status = self.query_one("#status", StatusIndicator)
        log = self.query_one("#log")

        try:
            if getattr(self.app, "vpn_process", None) is not None:
                proc = self.app.vpn_process
                if proc.poll() is None:
                    try:
                        proc.terminate()
                        proc.wait(timeout=5)
                    except Exception:
                        proc.kill()
                self.app.vpn_process = None

            cmd = [
                "/opt/cisco/secureclient/bin/vpn",
                "disconnect",
            ]

            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
            success = False
            for line in process.stdout:
                line = line.strip()
                self.call_later(log.write, line)
                if "state: Disconnected" in line:
                    self.call_later(status.set_disconnected)
                    self.app.vpn_status = "unbinded"
                    success = True

            process.wait()
            if not success:
                self.call_later(status.set_disconnected)
                self.app.vpn_status = "unbinded"
        except Exception as exc:
            self.call_later(log.write, f"Disconnect error: {exc}")
            self.call_later(status.set_disconnected)
            self.app.vpn_status = "unbinded"
        finally:
            self.app.vpn_process = None
            self.call_later(self.load_profiles)

