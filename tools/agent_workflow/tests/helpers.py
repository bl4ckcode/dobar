import copy
import hashlib
from pathlib import Path

import yaml

from tools.agent_workflow.repository import atomic_json


def write_document(path, meta, body):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("---\n" + yaml.safe_dump(meta, sort_keys=False) + "---\n\n" + body)


def fixture(root):
    identifiers = (
        [f"C{i:02}" for i in range(1, 12)]
        + [f"B{i:02}" for i in range(1, 13)]
        + ["S01", "S02"]
    )
    skills = [
        "dobar-" + name
        for name in (
            "orchestrate",
            "spec",
            "linear",
            "lovable-prompt",
            "cross-repo-plan",
            "react-to-flutter",
            "frontend",
            "backend",
            "payments",
            "bugfix",
            "validation",
        )
    ]
    for name in skills:
        directory = root / ".agents/skills" / name
        write_document(
            directory / "SKILL.md",
            {
                "name": name,
                "description": "Concrete test capability",
                "metadata": {"owner": "product"},
            },
            "Use acceptance evidence.",
        )
        for adapter in (".claude/skills", ".cline/skills"):
            link = root / adapter / name
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(
                Path("../../.agents/skills") / name, target_is_directory=True
            )
    for role in (
        "product",
        "frontend",
        "backend",
        "cross-repo-planner",
        "verifier",
        "payments",
        "heavy-ui",
        "bugfix",
    ):
        write_document(
            root / ".agents/roles" / f"{role}.md",
            {
                "id": role,
                "owner": role,
                "preferred_agent": "Test agent",
                "skills": ["dobar-spec"],
            },
            "Read the spec.",
        )
    source = root / "docs/source.md"
    source.parent.mkdir(parents=True, exist_ok=True)
    source.write_text("Approved launch behavior")
    specs, requirements = [], []
    for identifier in identifiers:
        name = identifier + "-journey.md"
        specs.append(name)
        write_document(
            root / ".specs/mvp-v0.1" / name,
            {
                "id": identifier,
                "title": identifier + " journey",
                "owner": "product",
                "areas": ["fe", "be"],
                "priority": "P0",
                "depends_on": [],
                "source_requirements": ["REQ-" + identifier],
                "planning_role": "cross-repo-planner",
                "implementation_roles": ["frontend", "backend"],
                "skills": ["dobar-spec"],
                "delivery_status": "ready",
                "verification_status": "unverified",
                "checks": ["foundation", "product-e2e"],
            },
            f"# {identifier}\n\n- **{identifier}-AC01** — Verified behavior.\n",
        )
        requirements.append(
            {
                "id": "REQ-" + identifier,
                "source": "mvp",
                "source_text": "Approved behavior",
                "specs": [identifier],
                "criteria": [identifier + "-AC01"],
            }
        )
    atomic_json(
        root / ".specs/mvp-v0.1/manifest.json",
        {
            "version": 1,
            "specs": specs,
            "requirements": "requirements.json",
            "pilot": "B08",
        },
    )
    atomic_json(
        root / ".specs/mvp-v0.1/requirements.json",
        {
            "version": 1,
            "sources": [
                {
                    "id": "mvp",
                    "path": "docs/source.md",
                    "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                }
            ],
            "requirements": requirements,
        },
    )
    atomic_json(
        root / "tools/agent_workflow/checks.json",
        {
            "version": 1,
            "checks": {
                "foundation": {
                    "command": ["{python}", "-c", "print('checked')"],
                    "timeout": 5,
                },
                "product-e2e": {
                    "command": None,
                    "reason": "No journey runner configured",
                },
            },
        },
    )


class FakeLinear:
    def __init__(self):
        self.remote = {}
        self.calls = []
        self.fail_at = None
        self.lose_response_at = None

    def team(self, key):
        if key != "DOB":
            raise ValueError("Unknown team")
        return {"id": "test-team", "key": key}

    def labels(self, team_id):
        return {"frontend": "label-fe", "backend": "label-be", "payments": "label-dpe"}

    def issues(self, team_id):
        return copy.deepcopy(list(self.remote.values()))

    def create(self, fields):
        from tools.agent_workflow.repository import WorkflowError

        self.calls.append(("create", copy.deepcopy(fields)))
        if len(self.calls) == self.fail_at:
            raise WorkflowError("Simulated API failure")
        if fields["id"] in self.remote:
            raise WorkflowError("Duplicate ID")
        issue = {
            **fields,
            "identifier": f"DOB-{len(self.remote) + 1}",
            "url": "https://linear.app/test",
            "parent": {"id": fields["parentId"]} if fields.get("parentId") else None,
            "team": {"id": fields["teamId"]},
        }
        self.remote[fields["id"]] = issue
        if len(self.calls) == self.lose_response_at:
            raise WorkflowError("Response lost after successful create")
        return copy.deepcopy(issue)

    def update(self, identifier, fields):
        self.calls.append(("update", copy.deepcopy(fields)))
        self.remote[identifier].update(fields)
        return copy.deepcopy(self.remote[identifier])
