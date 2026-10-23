from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from .linear import LinearClient, synchronize
from .repository import Repository, WorkflowError, json_text, require_valid
from .tickets import drafts, export_tickets, linear_config
from .verification import handoff, verify


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Dobar MVP specifications, explicit agent handoffs, and evidence-based verification"
    )
    parser.add_argument(
        "--root", type=Path, default=Path(__file__).resolve().parents[2]
    )
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("validate")
    tickets = commands.add_parser("tickets").add_subparsers(
        dest="ticket_command", required=True
    )
    export = tickets.add_parser("export")
    export.add_argument("--output", type=Path)
    sync = tickets.add_parser("sync")
    sync.add_argument("--spec", required=True)
    sync.add_argument("--team", default=os.environ.get("LINEAR_TEAM_KEY"))
    sync.add_argument("--apply", action="store_true")
    delivery = commands.add_parser("handoff")
    delivery.add_argument("--spec", required=True)
    delivery.add_argument("--role", required=True)
    delivery.add_argument("--output", type=Path)
    check = commands.add_parser("verify")
    check.add_argument("--spec", required=True)
    check.add_argument("--skip", action="append", default=[])
    check.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        repo = Repository(args.root)
        if args.command == "validate":
            report = repo.validate()
            print(json_text(report), end="")
            return 0 if report["status"] == "passed" else 1
        require_valid(repo)
        if args.command == "tickets":
            if args.ticket_command == "export":
                output = args.output or repo.root / ".agent-workflow/tickets"
                report = export_tickets(repo, output)
            else:
                items = drafts(repo, [args.spec])
                api_key = os.environ.get("LINEAR_API_KEY", "")
                if not api_key and not args.apply:
                    report = {
                        "status": "blocked",
                        "reason": "LINEAR_API_KEY missing; local desired payloads shown, remote team, labels, and existing issues have not been inspected",
                        "issues": items,
                    }
                    print(json_text(report), end="")
                    return 2
                client = LinearClient(api_key)
                report = synchronize(
                    items,
                    client,
                    repo.root / ".agent-workflow/linear-mapping.json",
                    args.team or linear_config(repo).get("team_key", "DOB"),
                    args.apply,
                    os.environ.get("LINEAR_PROJECT_ID"),
                )
            print(json_text(report), end="")
            return 0
        if args.command == "handoff":
            text = handoff(repo, args.spec, args.role)
            if args.output:
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(text)
                print(
                    json_text({"status": "written", "output": str(args.output)}), end=""
                )
            else:
                print(text, end="")
            return 0
        report = verify(repo, args.spec, args.skip)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json_text(report))
        print(json_text(report), end="")
        return (
            0
            if report["status"] == "passed"
            else (1 if report["status"] == "failed" else 2)
        )
    except (WorkflowError, KeyError, TypeError, ValueError, OSError) as exc:
        print(
            json_text({"status": "failed", "message": str(exc)}),
            end="",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
