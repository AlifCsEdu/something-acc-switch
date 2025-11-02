from __future__ import annotations
import typer
from rich.console import Console
from rich.table import Table
from pathlib import Path
from .core import (
    list_profiles, activate_profile, toggle_previous, export_tar, import_tar, import_from_env, verify, read_auth_summary, PROFILES
)

app = typer.Typer(add_completion=False, no_args_is_help=True)
console = Console()


@app.command()
def list():  # noqa: A001
    """List stored profiles."""
    t = Table(show_header=True, header_style='bold')
    t.add_column('Name')
    for n in list_profiles():
        t.add_row(n)
    console.print(t)


@app.command()
def activate(name: str):
    """Activate a profile.""
    activate_profile(name)
    console.print(f'✅ activated [bold]{name}[/]')


@app.command()
def toggle():
    """Toggle to previously active profile.""
    toggle_previous()
    console.print('✅ toggled')


@app.command()
def summary(name: str):
    """Show profile summary.""
    p = PROFILES / f'{name}.json'
    console.print(read_auth_summary(p))


@app.command()
def verify_targets(name: str | None = None):
    """Verify active targets match selected profile.""
    rows = verify(name)
    t = Table(show_header=True, header_style='bold')
    t.add_column('Target'); t.add_column('OK?')
    for tgt, ok in rows:
        t.add_row(tgt.replace(str(Path.home()), '~'), '✅' if ok else '❌')
    console.print(t)


@app.command()
def export(out: Path | None = None):
    """Export all profiles to a tar.gz.""
    outp = export_tar(out)
    console.print(f'📦 {outp}')


@app.command()
def import_tarball(path: Path):
    """Import profiles from a tar.gz.""
    import_tar(path)
    console.print('✅ imported')


@app.command()
def import_env(prefix: str = 'CCX_AUTH_'):
    """Import profiles from environment variables.""
    n = import_from_env(prefix)
    console.print(f'✅ imported {n} profile(s) from env')


@app.command()
def tui():
    """Run curses TUI.""
    from . import tui as _tui
    _tui.run()


if __name__ == '__main__':
    app()
