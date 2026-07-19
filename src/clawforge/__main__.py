"""CLI entrypoint: `python -m clawforge [--once] [--interval N] [--dry-run]`."""
from __future__ import annotations

import argparse
import os

from . import __version__


def main() -> None:
    p = argparse.ArgumentParser(prog="clawforge", description="Autonomous PM Claw Agent")
    p.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
        help="print the clawforge version and exit",
    )
    p.add_argument("--once", action="store_true", help="run a single cycle and exit")
    p.add_argument("--interval", type=int, help="seconds between cycles")
    p.add_argument("--dry-run", action="store_true", help="reason but do not apply actions")
    p.add_argument(
        "--status",
        action="store_true",
        help="print the latest cycle snapshot and exit (runs no cycle)",
    )
    p.add_argument(
        "--json",
        action="store_true",
        help="emit the cycle result as JSON on stdout (human logs go to stderr)",
    )
    args = p.parse_args()

    # --status is a read-only inspector: print the last snapshot and exit before
    # building the model client or running any cycle. --json switches it to the
    # machine-readable JSON snapshot.
    if args.status:
        from .config import Config
        from . import status

        cfg = Config()
        print(status.render_status_json(cfg) if args.json else status.render_status(cfg))
        return

    # Apply CLI overrides via env BEFORE building Config (which reads env).
    if args.interval is not None:
        os.environ["CLAWFORGE_INTERVAL"] = str(args.interval)
    if args.dry_run:
        os.environ["CLAWFORGE_DRY_RUN"] = "1"
    if args.json:
        os.environ["CLAWFORGE_JSON"] = "1"

    from .config import Config
    from . import loop

    loop.run(Config(), once=args.once)


if __name__ == "__main__":
    main()
