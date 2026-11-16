# Zoraxy packages for Linux and Windows

Unofficial `.deb` and `.rpm` packages and a Windows setup of [Zoraxy](https://github.com/tobychui/zoraxy),
the general purpose HTTP reverse proxy and forwarding tool.

The packages contain the **official release binaries**, downloaded from the Zoraxy
releases and verified against the SHA-256 digest GitHub publishes for each asset.
Nothing is recompiled or patched. A daily workflow checks for new Zoraxy releases,
then builds, tests and publishes the packages here.

## Install

Download the package for your system from the [releases](https://github.com/fdefilippo/zoraxy-linux-packages/releases), then:

```sh
sudo apt install ./zoraxy_3.3.5-1_amd64.deb     # Debian, Ubuntu
sudo dnf install ./zoraxy-3.3.5-1.x86_64.rpm    # RHEL, Oracle Linux, Rocky, Alma, Fedora
```

Architectures: amd64, arm64, arm (armhf / armv7hl), 386, riscv64.
The packages are not signed. Use `apt`/`dnf` as above: plain `rpm -i` on rpm 6
(e.g. Fedora 43) refuses unsigned packages.

The service is **not started automatically**. On the first visit, the management interface
(`:8000` by default) asks you to create the admin account. Review the options first, e.g.
`ZORAXY_OPTS="-port=127.0.0.1:8000"`, then:

```sh
sudo systemctl enable --now zoraxy
```

Upgrades restart the service if it is running. Removing the package keeps `/var/lib/zoraxy`
and the `zoraxy` user.

## Windows

Run `zoraxy-<version>-<revision>-windows-amd64-setup.exe` (Windows 10 / Server 2016 or later, x64).
The setup:

- installs `zoraxy.exe` in `C:\Program Files\Zoraxy` and the **`zoraxy` Windows service**,
  run by [WinSW](https://github.com/winsw/winsw) 2.12.0 (pinned by SHA-256) as `NT AUTHORITY\LocalService`.
  The service starts automatically and restarts if it crashes.
- keeps the data in `C:\ProgramData\Zoraxy` (service logs in `log\service`)
- opens TCP 80, 443 and UDP 443 (HTTP/3) in Windows Firewall for `zoraxy.exe`
- starts the management interface on **http://127.0.0.1:8000/** only (local access). On the first visit
  it asks you to create the admin account.

Command line options are in `C:\Program Files\Zoraxy\zoraxy-service.xml` (`<arguments>`). That file is
kept on upgrade. After editing it, run `Restart-Service zoraxy`.

Silent install: `setup.exe /S` (add `/NOSTART` to leave the service stopped). Silent removal:
`"C:\Program Files\Zoraxy\uninstall.exe" /S`. Removal keeps `C:\ProgramData\Zoraxy`.
Neither the setup nor WinSW is code-signed, so SmartScreen may ask for confirmation.

## What gets installed (Linux)

| Path | Content |
|---|---|
| `/usr/bin/zoraxy` | official static binary |
| `/usr/lib/systemd/system/zoraxy.service` | systemd unit: runs as user `zoraxy`, with `CAP_NET_BIND_SERVICE` for ports 80/443 |
| `/etc/default/zoraxy` (deb), `/etc/sysconfig/zoraxy` (rpm) | `ZORAXY_OPTS`: command line options, kept on upgrade |
| `/var/lib/zoraxy` | data directory (working directory of the service) |

## Build locally

```sh
make packages                         # latest Zoraxy release, host architecture
make packages VERSION=3.3.5 ARCH=arm64
make all-arch                         # every architecture
make rpm BINARY=/path/to/zoraxy       # package your own binary
make windows                          # Windows setup (needs makensis, e.g. the "nsis" package)
```

Requirements: `curl`, `python3`, `sha256sum`, `dpkg-deb` (for `.deb`), `rpmbuild` (for `.rpm`) and
`makensis` (for the Windows setup).
The packages are written to `dist/`.

## Workflow

`.github/workflows/packages.yml` runs every day and on demand (Actions → Packages → Run workflow,
optionally with a specific version or package revision). It builds every architecture, tests
the `.deb` as a systemd service on Ubuntu, the `.rpm` on Oracle Linux 8, 9 and Fedora and the
Windows setup on Windows Server (install, service, upgrade, removal), then publishes the release
`v<zoraxy version>-<revision>` with a `SHA256SUMS` file.

## License

Zoraxy is licensed under the [AGPL-3.0](LICENSE); the packaging files in this repository are
under the same license. Report problems with the packages here, and problems with Zoraxy itself
[upstream](https://github.com/tobychui/zoraxy/issues).
