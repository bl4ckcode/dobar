from __future__ import annotations

import hashlib
import re
from pathlib import Path
from urllib.parse import unquote, urlsplit

from .repository import Repository, WorkflowError, json_text, read_json

BEGIN = "<!-- dobar-workflow:start -->"
END = "<!-- dobar-workflow:end -->"
AREA_LABEL = {"fe": "frontend", "be": "backend", "dpe": "payments"}
AREA_ROLE = {"fe": "frontend", "be": "backend", "dpe": "payments"}


def linear_config(repo):
    path = repo.root / "tools/agent_workflow/linear-config.json"
    return read_json(path) if path.exists() else {}


def normalized_markdown(text):
    lines = []
    for line in text.splitlines():
        line = re.sub(r"^([ \t]*)[*+] ", r"\1- ", line).rstrip()
        if line.lstrip().startswith("<!-- dobar-"):
            line = line.lstrip()
        lines.append(line)
    return re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()


def owned_content(key: str, body: str) -> str:
    return f"{BEGIN}\n<!-- dobar-task:{key} -->\n{body.strip()}\n{END}"


def merge_owned(existing: str | None, content: str) -> str:
    text = existing or ""
    if not text:
        return content
    if (
        text.count(BEGIN) != 1
        or text.count(END) != 1
        or text.index(BEGIN) >= text.index(END)
    ):
        raise WorkflowError(
            "Issue has missing, repeated, or damaged ownership markers; reconcile before updating"
        )
    start, end = text.index(BEGIN), text.index(END) + len(END)
    return text[:start] + content + text[end:]


def portable_body(repo: Repository, source: Path, body: str):
    def replace(match):
        label, target = match.groups()
        parsed = urlsplit(target)
        if parsed.scheme or target.startswith("#"):
            return match.group(0)
        name = repo.relative(repo.local(source.parent, unquote(parsed.path)))
        name += f"#{parsed.fragment}" if parsed.fragment else ""
        return f"`{name}`" if label == name else f"{label} (`{name}`)"

    return re.sub(r"(?<!!)\[([^\]]+)\]\(([^)]+)\)", replace, body)


def drafts(repo: Repository, spec_ids: list[str] | None = None) -> list[dict]:
    result = []
    config = linear_config(repo)
    area_labels = config.get("area_labels", AREA_LABEL)
    if set(area_labels) != set(AREA_LABEL) or any(
        not isinstance(value, str) or not value for value in area_labels.values()
    ):
        raise WorkflowError(
            "Linear area_labels must map fe, be, and dpe to existing label names"
        )
    for identifier in sorted(spec_ids or repo.specs):
        spec = repo.spec(identifier)
        key = f"dobar:mvp-v0.1:{identifier}"
        path = repo.relative(spec.path)
        body = portable_body(repo, spec.path, spec.body)
        revision = hashlib.sha256(spec.path.read_bytes()).hexdigest()
        common = f"Spec: `{path}`\n\nSpec SHA-256: `{revision}`\n\nDelivery: {spec.meta['delivery_status']}; product verification: {spec.meta['verification_status']}.\n\nDependencies: {', '.join(spec.meta['depends_on']) or 'none'}.\n\n"
        result.append(
            {
                "key": key,
                "spec_id": identifier,
                "area": None,
                "parent_key": None,
                "title": f"[{identifier}] {spec.meta['title']}",
                "labels": (
                    [config["feature_label"]] if config.get("feature_label") else []
                )
                + [area_labels[area] for area in spec.meta["areas"]],
                "priority": {"P0": 1, "P1": 2, "P2": 3}[spec.meta["priority"]],
                "description": owned_content(key, common + body),
            }
        )
        for area in spec.meta["areas"]:
            task = spec.meta.get("tasks", {}).get(area, {})
            task_key = f"{key}:{area}"
            responsibilities = task.get(
                "description",
                f"Implement the {AREA_LABEL[area]} responsibilities in this spec. Keep changes within {area}/; coordinate contract changes with the linked area tasks. Resolve the observed gaps before claiming the acceptance criteria pass.",
            )
            task_body = (
                common
                + f"Role: `{AREA_ROLE[area]}`.\n\n{responsibilities}\n\nAcceptance criteria: {', '.join(spec.criteria)}.\n\n"
                + body
            )
            result.append(
                {
                    "key": task_key,
                    "spec_id": identifier,
                    "area": area,
                    "parent_key": key,
                    "title": f"[{identifier}/{area}] {task.get('title', spec.meta['title'])}",
                    "labels": [area_labels[area]],
                    "priority": {"P0": 1, "P1": 2, "P2": 3}[spec.meta["priority"]],
                    "description": owned_content(task_key, task_body),
                }
            )
    return result


def export_tickets(repo: Repository, output: Path) -> dict:
    items = drafts(repo)
    output.mkdir(parents=True, exist_ok=True)
    (output / "tickets.json").write_text(
        json_text(
            {
                "version": 1,
                "team_key": linear_config(repo).get("team_key", "DOB"),
                "issues": items,
            }
        )
    )
    text = "# Dobar MVP Linear drafts\n\nGenerated from repository specs. Local drafts; this file does not create Linear issues.\n\n"
    for item in items:
        text += f"## {item['title']}\n\nKey: `{item['key']}`; labels: {', '.join(item['labels'])}.\n\n{item['description']}\n\n"
    (output / "tickets.md").write_text(text)
    return {
        "status": "exported",
        "specs": len(repo.specs),
        "issues": len(items),
        "output": str(output),
    }
