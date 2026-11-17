"""Command line entry point."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import UTC, datetime
from pathlib import Path

from .policy import Policy, PolicyError
from .reconcile import Reconciler, render, render_diffs

EXIT_OK = 0
EXIT_ERROR = 1
EXIT_REJECTED = 2


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="profile-sync",
        description="Reconcile Hermes profiles against the nix-declared policy.",
    )
    parser.add_argument(
        "--hermes-home",
        default=os.environ.get("HERMES_HOME") or "/data/.hermes",
        help="HERMES_HOME inside the container (default: $HERMES_HOME).",
    )
    parser.add_argument(
        "--policy",
        default=None,
        help="Policy manifest (default: <hermes-home>/state/profile-sync/policy.json).",
    )
    parser.add_argument(
        "--profile",
        action="append",
        default=None,
        metavar="NAME",
        help="Restrict the run to one profile; repeatable.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print a unified diff and write nothing.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Replace a divergent real file with the link, keeping a backup.",
    )
    parser.add_argument(
        "--json", action="store_true", help="Print the run report as JSON."
    )
    parser.add_argument(
        "--quiet", action="store_true", help="Print nothing unless the run fails."
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Also report OK, KEPT and REDUNDANT outcomes.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    home = Path(args.hermes_home)
    policy_path = (
        Path(args.policy)
        if args.policy
        else home / "state" / "profile-sync" / "policy.json"
    )

    try:
        policy = Policy.load(policy_path)
        reconciler = Reconciler(
            home,
            policy,
            dry_run=args.dry_run,
            force=args.force,
            verbose=args.verbose,
        )
        report = reconciler.run(args.profile)
    except PolicyError as exc:
        print(f"profile-sync: {exc}", file=sys.stderr)
        return EXIT_ERROR

    if not args.dry_run:
        reconciler.write_state()

    if args.json:
        print(json.dumps(report.as_dict(datetime.now(UTC)), indent=2, sort_keys=True))
    else:
        output = render(report, verbose=args.verbose, quiet=args.quiet)
        if output:
            print(output, end="")
        if args.dry_run:
            diffs = render_diffs(report)
            if diffs:
                print(diffs, end="")

    if report.failed:
        return EXIT_ERROR
    if report.rejected:
        return EXIT_REJECTED
    return EXIT_OK
