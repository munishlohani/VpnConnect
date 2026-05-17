from textual.screen import Screen
from textual.widgets import Static
from textual.containers import Container, Center, Vertical
import pyfiglet


class Splash(Screen):

    def compose(self):
        art = pyfiglet.figlet_format("VPNConnect")


        yield Container(
            Static(art,classes="ascii"),
            Static("....Welcome to VPNConnect....",shrink=True, classes="ascii"),
            classes="splash"
        )
