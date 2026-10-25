from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from datetime import datetime, timezone

from .repository import Repository, WorkflowError, frontmatter, json_text


def checkout_fingerprint(repo: Repository):
    result = subprocess.run(
        [
            os.environ.get("DOBAR_GIT", "git"),
            "ls-files",
            "-z",
            "--cached",
            "--others",
            "--exclude-standard",
        ],
        cwd=repo.root,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise WorkflowError(
            "Cannot fingerprint checkout with Git: "
            + redact(result.stderr.decode(errors="replace").strip())[:600]
        )
    digest = hashlib.sha256()
    spec_paths = {spec.path for spec in repo.specs.values()}
    for name in sorted(set(result.stdout.split(b"\0")) - {b""}):
        path = repo.root / os.fsdecode(name)
        if path.is_symlink():
            digest.update(name + b"\0" + os.fsencode(path.readlink()) + b"\0")
        elif path.is_file():
            digest.update(name + b"\0")
            if path in spec_paths:
                meta, body = frontmatter(path)
                for field in ("verification_status", "verification_evidence"):
                    meta.pop(field, None)
                digest.update((json_text(meta) + body).encode())
            else:
                digest.update(path.read_bytes())
            digest.update(b"\0")
    return digest.hexdigest()


def redact(text: str) -> str:
    for name, value in os.environ.items():
        if len(value) >= 8 and any(
            part in name.upper() for part in ("TOKEN", "SECRET", "API_KEY", "PASSWORD")
        ):
            text = text.replace(value, "[redacted]")
    return text[-12000:]


def verify(repo: Repository, spec_id: str, skip=None):
    spec = repo.spec(spec_id)
    skipped = set(skip or [])
    unknown = skipped - set(spec.meta["checks"])
    if unknown:
        raise WorkflowError(
            f"Cannot skip checks absent from spec: {', '.join(sorted(unknown))}"
        )
    results = []
    try:
        before = checkout_fingerprint(repo)
    except (WorkflowError, FileNotFoundError) as exc:
        before = None
        results.append(
            {"check": "checkout-fingerprint", "status": "blocked", "reason": str(exc)}
        )
    for name in spec.meta["checks"]:
        check = repo.checks[name]
        if name in skipped:
            results.append(
                {
                    "check": name,
                    "status": "skipped",
                    "reason": "Explicitly skipped by operator",
                }
            )
            continue
        command = check.get("command")
        if not command:
            results.append(
                {
                    "check": name,
                    "status": "blocked",
                    "reason": check.get("reason", "No command configured"),
                }
            )
            continue
        missing = [
            variable
            for variable in check.get("requires_env", [])
            if not os.environ.get(variable)
        ]
        if missing:
            results.append(
                {
                    "check": name,
                    "status": "blocked",
                    "reason": "Missing environment variables: " + ", ".join(missing),
                }
            )
            continue
        if not isinstance(command, list) or any(
            not isinstance(arg, str) for arg in command
        ):
            raise WorkflowError(f"Check {name}: command must be an argument list")
        command = [
            arg.replace("{python}", sys.executable)
            .replace("{spec}", spec_id)
            .replace("{catalog}", repo.catalog)
            for arg in command
        ]
        cwd = repo.local(repo.root, check.get("cwd", "."))
        try:
            process = subprocess.run(
                command,
                cwd=cwd,
                capture_output=True,
                text=True,
                timeout=check.get("timeout", 300),
                check=False,
            )
            results.append(
                {
                    "check": name,
                    "status": "passed" if process.returncode == 0 else "failed",
                    "returncode": process.returncode,
                    "stdout": redact(process.stdout),
                    "stderr": redact(process.stderr),
                }
            )
        except FileNotFoundError:
            results.append(
                {
                    "check": name,
                    "status": "blocked",
                    "reason": "Check executable or working directory unavailable",
                }
            )
        except subprocess.TimeoutExpired:
            results.append(
                {"check": name, "status": "failed", "reason": "Check timed out"}
            )
    try:
        after = checkout_fingerprint(repo) if before else None
    except (WorkflowError, FileNotFoundError):
        after = None
    if before and before != after:
        results.append(
            {
                "check": "checkout-stability",
                "status": "failed",
                "reason": "Checkout changed during verification; inspect changes and rerun",
            }
        )
    states = {result["status"] for result in results}
    status = (
        "failed"
        if "failed" in states
        else ("passed" if states == {"passed"} else "incomplete")
    )
    verification = (
        "validated"
        if status == "passed"
        else ("partial" if "passed" in states else "unverified")
    )
    return {
        "spec_id": spec_id,
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "checkout_sha256": before,
        "status": status,
        "verification_status": verification,
        "results": results,
    }


def handoff(repo: Repository, spec_id: str, role_id: str):
    spec = repo.spec(spec_id)
    if role_id not in repo.roles:
        raise WorkflowError(f"Unknown role: {role_id}")
    path, role, body = repo.roles[role_id]
    skills = sorted(set(role["skills"]) | set(spec.meta["skills"]))
    areas = spec.meta["areas"]
    context = ["AGENTS.md"] + [f"{area}/AGENTS.md" for area in areas]
    context += ["docs/AGENT_WORKFLOW.md", "docs/FE_BE_COMMUNICATION.md"]
    if "dpe" in areas:
        context.append("docs/BE_DPE_COMMUNICATION.md")
    text = f"# {spec_id}: {spec.meta['title']} — {role_id}\n\nPreferred agent: {role['preferred_agent']}. Launch it explicitly in your existing tool; this package does not invoke an API.\n\n"
    text += "## Required context\n\n" + "\n".join(f"- `{name}`" for name in context)
    text += f"\n- `{repo.relative(path)}`\n" + "\n".join(
        f"- `{repo.relative(repo.skills[name][0])}`" for name in skills
    )
    text += "\n\n## Role instructions\n\n" + body.strip()
    text += "\n\n## Dependencies\n\n" + (
        "\n".join(
            f"- `{other}`: `{repo.relative(repo.spec(other).path)}`"
            for other in spec.meta["depends_on"]
        )
        or "None."
    )
    text += f"\n\n## Journey spec\n\nSource: `{repo.relative(spec.path)}`\n\n{spec.body.strip()}"
    catalog_option = f"--catalog {repo.catalog} " if repo.catalog != "mvp-v0.1" else ""
    text += f"\n\n## Verification handoff\n\nRun `python -m tools.agent_workflow {catalog_option}verify --spec {spec_id}` and attach the report. Required checks: {', '.join(spec.meta['checks'])}. An incomplete report cannot establish validation. Include changed files, contract changes, acceptance evidence, and remaining blockers. Never stage, commit, or deploy automatically.\n"
    return text
