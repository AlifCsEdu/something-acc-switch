# ccx-switcher

Modern, fast **Codex `auth.json` profile switcher**. Clean CLI with [Typer](https://typer.tiangolo.com/) + [Rich](https://github.com/Textualize/rich), optional modern TUI with [Textual](https://github.com/Textualize/textual).

- XDG paths by default, env overrides preserved: `CCX_PROFILES`, `CODEX_HOME`, `CCX_TARGETS`, `CCX_DURABLE`
- Atomic writes + JSON validation
- One-shot install via `pipx`
- CLI commands: `list`, `activate`, `toggle`, `verify`, `summary`, `doctor`, `import-env`, `export`, `import-tar`, `tui`

## Quick install (from this repo via pipx)

```bash
pipx install git+https://github.com/AlifCsEdu/something-acc-switch
# then
ccx tui
```

### Optional: install with TUI extras

```bash
pipx install 'git+https://github.com/AlifCsEdu/something-acc-switch#egg=ccx-switcher[tui]'
```

## CLI examples

```bash
ccx list
ccx activate work-account
ccx toggle
ccx verify
ccx summary work-account
ccx export
ccx import-env   # reads CCX_AUTH_* from env
```

## TUI

```
ccx tui
```

## Paths

- Profiles: `~/.local/share/ccx/profiles` (or `$XDG_DATA_HOME/ccx/profiles`)
- Config:   `~/.config/ccx/config.json` (or `$XDG_CONFIG_HOME/ccx/config.json`)
- Targets:  `~/.codex/auth.json` + `$CODEX_HOME/auth.json` + `$CCX_TARGETS`

## Dev

```bash
python -m venv .venv && . .venv/bin/activate
pip install -e '.[tui]'
ccx doctor
```

## License

MIT
