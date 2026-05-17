# VPNConnect

A terminal-based VPN connector for Cisco AnyConnect-compatible VPN clients. This project uses `uv` for dependency management and execution and provides a Textual UI for creating profiles, connecting, and disconnecting.

## Features

- Interactive TUI built with [Textual](https://textual.textualize.io/)
- Encrypted password storage using `cryptography`
- VPN profile management in `config.yaml`
- Clean disconnect handling and exit button support
- UV-managed environment and script entrypoint

## Prerequisites

- [uv](https://uvpkg.com/) installed
- Cisco AnyConnect CLI installed at `/opt/cisco/secureclient/bin/vpn`

## Install with UV

From the project root:

```bash
uv install
```

This will create a project virtual environment and install dependencies from `pyproject.toml`.

To install the TUI as a local UV tool, run:

```bash
uv tool install .
```

## Run the app

Use the UV script entrypoint:

```bash
uv run connect-vpn
```

If the script entrypoint is not available for any reason, you can also run the app directly through UV’s Python environment:

```bash
uv run python src/connect_vpn/main.py
```


## Configuration

The app stores configuration in a `config.yaml` file located in the project root. Profiles are saved under the `vpn.profiles` key and passwords are encrypted automatically.

Example profile format:

```yaml
vpn:
  profiles:
    work:
      server: vpn.example.com
      username: user@example.com
      password: <encrypted-token>
      group: 1
      passcode: 1
```

## Notes

- The project is configured as a UV package with the `connect-vpn` script entrypoint.
- If you change the VPN binary path, update `VPN_BIN` in `src/connect_vpn/app.py`.
- Keep `.vault_key` secure, since it encrypts stored passwords.
