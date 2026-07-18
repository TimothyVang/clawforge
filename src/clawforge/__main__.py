"""CLI entrypoint: `python -m clawforge [--once] [--interval N] [--dry-run]`."""
from __future__ import annotations

import argparse
import os


def main() -> None:
    p = argparse.ArgumentParser(prog="clawforge", description="Autonomous PM Claw Agent")
    p.add_argument("--once", action="store_true", help="run a single cycle and exit")
    p.add_argument("--interval", type=int, help="seconds between cycles")
    p.add_argument("--dry-run", action="store_true", help="reason but do not apply actions")
    args = p.parse_args()

    # Apply CLI overrides via env BEFORE building Config (which reads env).
    if args.interval is not None:
        os.environ["CLAWFORGE_INTERVAL"] = str(args.interval)
    if args.dry_run:
        os.environ["CLAWFORGE_DRY_RUN"] = "1"

    from .config import Config
    from . import loop

    loop.run(Config(), once=args.once)


if __name__ == "__main__":
    main()
