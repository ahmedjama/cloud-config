# OpenCode dev VM (Multipass)

Cloud-init for an Ubuntu 24.04 VM built for agentic AI development. The VM is
meant to stay running while you connect over SSH and work inside it with
OpenCode, Python, Node/Bun, Docker, and a Starship prompt.

## What you get

| Area | Installed / configured |
| --- | --- |
| Core | git, git-lfs, build-essential, curl, wget, jq, yq, rsync, shellcheck |
| Search & UX | ripgrep, fd, fzf, bat, tree, zoxide, direnv, tmux, htop, btop, ncdu |
| Python | Python 3, `uv`, `pipx`, venv support, sqlite |
| JS/TS | Node.js LTS (NodeSource), npm, pnpm, Bun |
| AI | OpenCode, GitHub CLI (`gh`) |
| Containers | Docker Engine (with compose/buildx) + ubuntu in the `docker` group |
| Shell | Starship prompt, bash completions, aliases, 100k shared history |
| System | 2 GB swap, higher inotify/container limits, non-interactive apt |

## Launch

```bash
multipass launch 24.04 \
  --name opencode \
  --cpus 4 \
  --memory 8G \
  --disk 40G \
  --cloud-init cloud-init.yaml
```

First boot can take several minutes because `package_upgrade: true` is enabled.
Wait for cloud-init and check its log:

```bash
multipass exec opencode -- cloud-init status --wait
multipass exec opencode -- sudo tail -n 60 /var/log/cloud-init-output.log
```

## SSH from the host

`multipass shell opencode` always works, but for normal SSH add your host public
key to the VM:

```bash
# from the host
multipass exec opencode -- sudo -u ubuntu bash -c '
  mkdir -p /home/ubuntu/.ssh
  chmod 700 /home/ubuntu/.ssh
  cat >> /home/ubuntu/.ssh/authorized_keys
  chmod 600 /home/ubuntu/.ssh/authorized_keys
' < ~/.ssh/id_ed25519.pub

IP=$(multipass info opencode | awk '/IPv4/{print $2; exit}')
ssh ubuntu@$IP
```

If you do not have a key yet:

```bash
ssh-keygen -t ed25519 -C "$USER@$(hostname)"
```

Optional `~/.ssh/config` entry:

```sshconfig
Host opencode
  HostName <vm-ip>
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519
  ServerAliveInterval 30
  ServerAliveCountMax 4
```

Then connect with `ssh opencode`. To reach a dev server running inside the VM:

```bash
ssh -L 3000:localhost:3000 opencode
```

SSH password authentication is disabled by cloud-init; auth is key-only.

## First login

```bash
# Cloud-init intentionally does not set a Git identity.
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

gh auth login          # GitHub CLI
opencode auth login    # provider / API credentials
```

Tool locations:

- `opencode` -> `~/.opencode/bin/opencode`
- `uv`, `pnpm`, `pipx` tools -> `~/.local/bin`
- `bun` -> `~/.bun/bin`

All of these are added to `PATH` for login and interactive shells. Docker group
membership takes effect on your next login (or run `newgrp docker`).

## Shell and prompt

Starship is configured at `~/.config/starship.toml`. The prompt shows the
current directory, git branch/status, Docker and Kubernetes context, language
versions, command duration, and non-zero exit status. It uses regular Unicode
instead of Nerd Font private-use glyphs, so it works in a stock terminal.

Shell quality-of-life:

- `fzf`: `Ctrl-R` history search, `Ctrl-T` file picker, `Alt-C` directory jump
- `zoxide`: `z <dir>`
- `direnv` hook for per-project environments
- aliases for `ll`, `gs`, `gd`, `gl`, `bat`, `fd`, ...
- 100k-line history shared across concurrent shells
- bash completions for git, gh, docker, starship, and uv

Change the prompt by editing `~/.config/starship.toml`, then run `exec bash -l`.

## Workspace and mounts

The VM creates `/home/ubuntu/workspace`. Mount host code there:

```bash
multipass mount ~/code opencode:/home/ubuntu/workspace
```

Or launch and then mount:

```bash
multipass launch 24.04 \
  --name opencode \
  --cpus 4 --memory 8G --disk 40G \
  --cloud-init cloud-init.yaml

multipass mount ~/code opencode:/home/ubuntu/workspace
```

## Re-running provisioning

The setup logic is kept at `/usr/local/sbin/opencode-setup.sh` and is mostly
idempotent:

```bash
multipass exec opencode -- sudo /usr/local/sbin/opencode-setup.sh
```

Cloud-init itself only runs on first boot. To rebuild from scratch:

```bash
multipass delete opencode && multipass purge
```

## Notes

- Python is PEP 668 managed. Use `uv` or `pipx` for tools instead of
  `pip install` into the system interpreter.
- Docker installs via Docker's convenience script, with Ubuntu's `docker.io`
  as a fallback.
- To skip Docker in a future variant, remove the Docker block from the setup
  script and the Docker references in the Starship config.
