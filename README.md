# VPNConnect

A terminal-based VPN connector for Cisco AnyConnect-compatible VPN clients. This project uses `uv` for dependency management and execution and provides a Textual UI for creating profiles, connecting, and disconnecting.

## Features

- Interactive TUI built with [Textual](https://textual.textualize.io/)
- Encrypted password storage using `cryptography`
- VPN profile management in `config.yaml`
- Clean disconnect handling and exit button support
- UV-managed environment and script entrypoint

## QuickStart

>[!IMPORTANT]
The current version does not support Windows.

**Mac & Linux**
```bash
curl -sSL https://raw.githubusercontent.com/munishlohani/VpnConnect/main/scripts/install.sh | bash
```

The installation handles everything: uv, python, git

### After Installation

```bash
connect-vpn #start the TUI
```
