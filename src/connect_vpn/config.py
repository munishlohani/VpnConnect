import os
import yaml
import base64
from typing import Optional
from textual.widgets import Static

from cryptography.fernet import Fernet


ROOT_DIR = "~/.connectvpn"

CONFIG_PATH = os.path.join(ROOT_DIR,"config.yaml")
KEY_PATH = os.path.join(ROOT_DIR,".vault_key")


def _get_key() -> bytes:
    """Return existing key or generate a new one stored at KEY_PATH."""

    os.makedirs(ROOT_DIR, exist_ok=True)
    
    if os.path.exists(KEY_PATH):
        with open(KEY_PATH, "rb") as f:
            return f.read()

    key = Fernet.generate_key()
    with open(KEY_PATH, "wb") as f:
        f.write(key)
    return key


def encrypt_password(password: str) -> str:
    key = _get_key()
    f = Fernet(key)
    token = f.encrypt(password.encode())
    return token.decode()


def decrypt_password(token: Optional[str]) -> Optional[str]:
    if not token:
        return None
    key = _get_key()
    f = Fernet(key)
    try:
        return f.decrypt(token.encode()).decode()
    except Exception:
        return None


def load_config():
    if not os.path.exists(CONFIG_PATH):
        return {"vpn": {"profiles": {}}}

    with open(CONFIG_PATH, "r") as f:
        return yaml.safe_load(f) or {"vpn": {"profiles": {}}}


def save_config(cfg):
    with open(CONFIG_PATH, "w") as f:
        yaml.safe_dump(cfg, f)



class StatusIndicator(Static):


    def __init__(self, status="unbinded", **kwargs):
        super().__init__(status, **kwargs)
        
    def set_disconnected(self):
        self.update("[DISCONNECTED]")

    def set_connecting(self):
        self.update("[CONNECTING...]")

    def set_connected(self):
        self.update("[CONNECTED]")
