from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from urllib.parse import unquote, urlsplit

import yaml


class WorkflowError(Exception):
    pass


class UniqueLoader(yaml.SafeLoader):
    pass


def unique_mapping(loader, node, deep=False):
    result = {}
    for key_node, value_node in node.value:
        key = loader.construct_object(key_node, deep=deep)
        if key in result:
            raise WorkflowError(f"Duplicate YAML key: {key}")
        result[key] = loader.construct_object(value_node, deep=deep)
    return result


UniqueLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, unique_mapping
)


def read_json(path: Path):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError) as exc:
        raise WorkflowError(f"Cannot read JSON: {path}: {exc}") from exc


def json_text(value) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def atomic_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json_text(value))
    temporary.replace(path)


def frontmatter(path: Path) -> tuple[dict, str]:
    try:
        text = path.read_text()
        match = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|$)", text, re.S)
        if not match:
            raise WorkflowError(f"Missing YAML frontmatter: {path}")
        data = yaml.load(match.group(1), Loader=UniqueLoader)
        if not isinstance(data, dict):
            raise WorkflowError(f"Frontmatter must be a mapping: {path}")
        return data, text[match.end() :]
    except (OSError, yaml.YAMLError) as exc:
        raise WorkflowError(f"Invalid document: {path}: {exc}") from exc


@dataclass
class Spec:
    path: Path
    meta: dict
    body: str

    @property
    def id(self):
        return self.meta["id"]

    @property
    def criteria(self):
        return sorted(
            set(
                re.findall(
                    rf"(?m)^- \*\*({re.escape(self.id)}-AC\d{{2}})\*\*\s", self.body
                )
            )
        )


class Repository:
    def __init__(self, root: Path, catalog: str = "mvp-v0.1"):
        self.root = root.resolve()
        if not re.fullmatch(r"[a-z0-9][a-z0-9.-]*", catalog) or catalog in {".", ".."}:
            raise WorkflowError(
                "Catalog must be a local name such as mvp-v0.1 or platform"
            )
        self.catalog = catalog
        self.spec_dir = self.local(self.root / ".specs", catalog)
        self.manifest = read_json(self.spec_dir / "manifest.json")
        self.specs = {}
        for name in self.manifest["specs"]:
            path = self.local(self.spec_dir, name)
            meta, body = frontmatter(path)
            identifier = meta.get("id")
            if identifier in self.specs:
                raise WorkflowError(f"Duplicate spec ID: {identifier}")
            if not isinstance(identifier, str):
                raise WorkflowError(f"Missing spec ID: {path}")
            self.specs[identifier] = Spec(path, meta, body)
        self.roles = self.load_documents(".agents/roles", "*.md", "id")
        self.skills = self.load_documents(".agents/skills", "*/SKILL.md", "name")
        self.checks = read_json(self.root / "tools/agent_workflow/checks.json")[
            "checks"
        ]

    def local(self, base: Path, name: str) -> Path:
        path = (base / name).resolve()
        if not path.is_relative_to(self.root):
            raise WorkflowError(f"Reference escapes repository: {name}")
        return path

    def relative(self, path: Path) -> str:
        return path.relative_to(self.root).as_posix()

    def load_documents(self, directory: str, glob: str, key: str):
        result = {}
        for path in sorted((self.root / directory).glob(glob)):
            meta, body = frontmatter(path)
            identifier = meta.get(key)
            if not isinstance(identifier, str) or identifier in result:
                raise WorkflowError(f"Missing or duplicate {key}: {path}")
            result[identifier] = (path, meta, body)
        return result

    def spec(self, identifier: str) -> Spec:
        if identifier not in self.specs:
            raise WorkflowError(f"Unknown spec: {identifier}")
        return self.specs[identifier]

    def validate(self) -> dict:
        findings = []

        def fail(code, path, message):
            findings.append(
                {"code": code, "path": self.relative(path), "message": message}
            )

        expected = (
            {f"C{i:02}" for i in range(1, 12)}
            | {f"B{i:02}" for i in range(1, 13)}
            | {"S01", "S02"}
        )
        if self.catalog != "mvp-v0.1":
            declared = self.manifest.get("expected_ids")
            if (
                not isinstance(declared, list)
                or not declared
                or any(not isinstance(value, str) for value in declared)
            ):
                raise WorkflowError("Additional catalogs require explicit expected_ids")
            expected = set(declared)
        if set(self.specs) != expected:
            fail(
                "spec-inventory",
                self.spec_dir,
                f"Expected {len(expected)} specs; missing {sorted(expected - self.specs.keys())}; extra {sorted(self.specs.keys() - expected)}",
            )
        manifest_paths = {s.path for s in self.specs.values()}
        for path in self.spec_dir.glob("*.md"):
            if (
                re.match(r"[A-Z]\d{2}[-_]", path.name)
                and path.resolve() not in manifest_paths
            ):
                fail("unindexed-spec", path, "Spec is absent from manifest")
        required = {
            "title",
            "owner",
            "areas",
            "priority",
            "depends_on",
            "source_requirements",
            "planning_role",
            "implementation_roles",
            "skills",
            "delivery_status",
            "verification_status",
            "checks",
        }
        for spec in self.specs.values():
            meta = spec.meta
            for key in sorted(required - meta.keys()):
                fail("spec-metadata", spec.path, f"Missing {key}")
            malformed = False
            for key in (
                "areas",
                "depends_on",
                "source_requirements",
                "implementation_roles",
                "skills",
                "checks",
            ):
                if not isinstance(meta.get(key), list) or any(
                    not isinstance(v, str) for v in meta.get(key, [])
                ):
                    fail("spec-metadata", spec.path, f"{key} must be a list of strings")
                    malformed = True
                elif len(meta[key]) != len(set(meta[key])):
                    fail(
                        "spec-metadata", spec.path, f"{key} contains duplicate entries"
                    )
            if malformed:
                continue
            tasks = meta.get("tasks", {})
            if not isinstance(tasks, dict) or any(
                area not in meta["areas"]
                or not isinstance(task, dict)
                or not isinstance(task.get("title"), str)
                or not isinstance(task.get("description"), str)
                for area, task in tasks.items()
            ):
                fail(
                    "spec-tasks",
                    spec.path,
                    "tasks must map affected areas to title/description objects",
                )
            if not set(meta.get("areas", [])) <= {"fe", "be", "dpe"} or not meta.get(
                "areas"
            ):
                fail("spec-area", spec.path, "areas must contain fe, be, or dpe")
            for role in [
                meta.get("owner"),
                meta.get("planning_role"),
                *meta.get("implementation_roles", []),
            ]:
                if role not in self.roles:
                    fail("spec-role", spec.path, f"Unknown role: {role}")
            for skill in meta.get("skills", []):
                if skill not in self.skills:
                    fail("spec-skill", spec.path, f"Unknown skill: {skill}")
            for dependency in meta.get("depends_on", []):
                if dependency not in self.specs:
                    fail(
                        "spec-dependency",
                        spec.path,
                        f"Unknown dependency: {dependency}",
                    )
            if meta.get("priority") not in {"P0", "P1", "P2"}:
                fail("spec-priority", spec.path, "priority must be P0, P1, or P2")
            if meta.get("delivery_status") not in {
                "draft",
                "ready",
                "in_progress",
                "done",
            }:
                fail("spec-delivery", spec.path, "Unknown delivery_status")
            if meta.get("verification_status") not in {
                "unverified",
                "partial",
                "validated",
            }:
                fail("spec-verification", spec.path, "Unknown verification_status")
            if meta.get("verification_status") == "validated":
                evidence = meta.get("verification_evidence")
                try:
                    report = (
                        read_json(self.local(self.root, evidence))
                        if isinstance(evidence, str)
                        else {}
                    )
                    from .verification import checkout_fingerprint

                    results = report.get("results", [])
                    result_ids = [result.get("check") for result in results]
                    covered = len(result_ids) == len(set(result_ids)) and set(
                        result_ids
                    ) == set(meta.get("checks", []))
                    checks_passed = bool(results) and all(
                        result.get("status") == "passed"
                        and result.get("returncode") == 0
                        for result in results
                    )
                    if (
                        not covered
                        or not checks_passed
                        or report.get("spec_id") != spec.id
                        or report.get("status") != "passed"
                        or report.get("checkout_sha256") != checkout_fingerprint(self)
                    ):
                        fail(
                            "spec-evidence",
                            spec.path,
                            "Validated metadata requires a passing verify report for the current checkout",
                        )
                except WorkflowError:
                    fail(
                        "spec-evidence",
                        spec.path,
                        "Validated metadata requires a readable verification_evidence report",
                    )
            checks = meta.get("checks", [])
            required_checks = set(
                self.manifest.get("required_checks", ["foundation", "product-e2e"])
            )
            if not required_checks <= set(checks):
                fail(
                    "spec-checks",
                    spec.path,
                    f"Required catalog checks: {', '.join(sorted(required_checks))}",
                )
            for check in checks:
                if check not in self.checks:
                    fail("spec-checks", spec.path, f"Unknown check: {check}")
            if not spec.criteria:
                fail("acceptance", spec.path, "No stable acceptance criteria found")

        visited, visiting = set(), set()

        def visit(identifier):
            if identifier in visiting:
                fail(
                    "dependency-cycle",
                    self.specs[identifier].path,
                    f"Cycle involving {identifier}",
                )
                return
            if identifier in visited:
                return
            visiting.add(identifier)
            for other in (
                self.specs[identifier].meta.get("depends_on", [])
                if isinstance(self.specs[identifier].meta.get("depends_on"), list)
                else []
            ):
                if isinstance(other, str) and other in self.specs:
                    visit(other)
            visiting.remove(identifier)
            visited.add(identifier)

        for identifier in self.specs:
            visit(identifier)

        for identifier, (path, meta, _) in self.roles.items():
            if not meta.get("owner") or not meta.get("preferred_agent"):
                fail("role-metadata", path, "owner and preferred_agent are required")
            for skill in meta.get("skills", []):
                if skill not in self.skills:
                    fail("role-skill", path, f"Unknown skill {skill}")
        required_skills = {
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
        }
        for name in sorted(required_skills - self.skills.keys()):
            fail("missing-skill", self.root / ".agents/skills", name)
        for identifier, (path, meta, _) in self.skills.items():
            if (
                identifier != path.parent.name
                or not meta.get("description")
                or not meta.get("metadata", {}).get("owner")
            ):
                fail(
                    "skill-metadata",
                    path,
                    "Skill needs matching name, description, and metadata.owner",
                )
            for adapter in (".claude/skills", ".cline/skills"):
                link = self.root / adapter / identifier
                if not link.is_symlink() or link.resolve() != path.parent.resolve():
                    fail(
                        "skill-discovery",
                        path,
                        f"Missing relative discovery link in {adapter}",
                    )
                elif Path(link.readlink()).is_absolute():
                    fail(
                        "skill-discovery",
                        path,
                        "Discovery links must be repository-relative",
                    )

        self.validate_coverage(fail)
        self.validate_communication_docs(fail)
        managed = (
            list(self.spec_dir.rglob("*.md"))
            + [v[0] for v in self.roles.values()]
            + [v[0] for v in self.skills.values()]
        )
        managed += [
            self.root / p
            for p in (
                "AGENTS.md",
                "fe/AGENTS.md",
                "be/AGENTS.md",
                "dpe/AGENTS.md",
                "CLAUDE.md",
                "GEMINI.md",
                "docs/AGENT_WORKFLOW.md",
                "docs/AGENT_CONTEXT.md",
                "docs/FE_BE_COMMUNICATION.md",
                "docs/BE_DPE_COMMUNICATION.md",
            )
            if (self.root / p).exists()
        ]
        for path in managed:
            self.validate_links(path, fail)
        return {
            "status": "failed" if findings else "passed",
            "counts": {
                "specs": len(self.specs),
                "roles": len(self.roles),
                "skills": len(self.skills),
            },
            "findings": findings,
            "product_verification": "unverified",
        }

    def validate_communication_docs(self, fail):
        for name, senders in (
            ("FE_BE_COMMUNICATION.md", ("frontend", "backend")),
            ("BE_DPE_COMMUNICATION.md", ("backend", "DPE")),
        ):
            path = self.root / "docs" / name
            if not path.exists():
                continue
            text = path.read_text()
            if len(text.splitlines()) > 80:
                fail(
                    "communication-size",
                    path,
                    "Rolling communication docs must stay within 80 lines; use Git/Linear for history",
                )
            headings = re.findall(r"(?m)^## (.+)$", text)
            expected = [
                "Contract references",
                *[f"Latest {sender} update" for sender in senders],
            ]
            if sorted(headings) != sorted(expected):
                fail(
                    "communication-sections",
                    path,
                    "Keep one contract-reference section and one latest update per sender",
                )
            match = re.search(r"(?m)^Last updated: (\d{4}-\d{2}-\d{2})$", text)
            try:
                date.fromisoformat(match.group(1) if match else "")
            except ValueError:
                fail("communication-date", path, "Use Last updated: YYYY-MM-DD")
            for sender in senders:
                section = re.search(
                    rf"(?ms)^## Latest {sender} update\n(.*?)(?=^## |\Z)", text
                )
                if section and not re.search(
                    r"(?m)^- Date: \d{4}-\d{2}-\d{2}", section.group(1)
                ):
                    fail(
                        "communication-date",
                        path,
                        f"Latest {sender} update needs its own date",
                    )

    def validate_coverage(self, fail):
        path = self.local(self.spec_dir, self.manifest["requirements"])
        coverage = read_json(path)
        sources = {}
        for source in coverage["sources"]:
            if source["id"] in sources:
                fail("coverage-duplicate-source", path, source["id"])
            sources[source["id"]] = source
            if source.get("path"):
                target = self.local(self.root, source["path"])
                if not target.is_file():
                    fail("coverage-source", path, f"Missing source: {source['path']}")
                elif not re.fullmatch(r"[a-f0-9]{64}", source.get("sha256", "")):
                    fail(
                        "coverage-source",
                        path,
                        f"Missing reviewed source snapshot sha256: {source['path']}",
                    )
                elif (
                    hashlib.sha256(target.read_bytes()).hexdigest() != source["sha256"]
                ):
                    fail(
                        "coverage-drift",
                        path,
                        f"Source changed; review requirement coverage and refresh sha256: {source['path']}",
                    )
        requirements = {}
        for requirement in coverage["requirements"]:
            identifier = requirement["id"]
            if identifier in requirements:
                fail("coverage-duplicate", path, identifier)
            requirements[identifier] = requirement
            if requirement.get("source") not in sources or not requirement.get(
                "source_text"
            ):
                fail("coverage-source", path, f"Invalid source for {identifier}")
            if not requirement.get("specs") or not requirement.get("criteria"):
                fail("coverage-unmapped", path, f"No spec/criteria for {identifier}")
            criteria = set()
            for spec_id in requirement.get("specs", []):
                if spec_id not in self.specs:
                    fail("coverage-spec", path, f"Unknown spec {spec_id}")
                    continue
                spec = self.specs[spec_id]
                criteria.update(spec.criteria)
                if identifier not in spec.meta.get("source_requirements", []):
                    fail(
                        "coverage-inverse",
                        spec.path,
                        f"Missing requirement {identifier}",
                    )
            for criterion in requirement.get("criteria", []):
                if criterion not in criteria:
                    fail(
                        "coverage-criterion",
                        path,
                        f"Unknown acceptance criterion {criterion}",
                    )
        for spec in self.specs.values():
            if not spec.meta.get("source_requirements"):
                fail("coverage-unmapped", spec.path, "Spec has no source requirements")
            for identifier in (
                spec.meta.get("source_requirements", [])
                if isinstance(spec.meta.get("source_requirements"), list)
                else []
            ):
                if not isinstance(identifier, str):
                    continue
                if identifier not in requirements or spec.id not in requirements[
                    identifier
                ].get("specs", []):
                    fail(
                        "coverage-inverse",
                        spec.path,
                        f"Missing reverse mapping for {identifier}",
                    )

    def validate_links(self, path, fail):
        body = re.sub(r"```.*?```", "", path.read_text(), flags=re.S)
        for target in re.findall(r"(?<!!)\[[^\]]+\]\(([^)]+)\)", body):
            target = target.split(' "', 1)[0].strip("<>")
            parsed = urlsplit(target)
            if parsed.scheme or target.startswith("#"):
                continue
            name = unquote(parsed.path)
            name = re.sub(r":\d+$", "", name)
            try:
                resolved = self.local(
                    self.root if name.startswith("/") else path.parent,
                    name.lstrip("/") if name.startswith("/") else name,
                )
                if not resolved.exists():
                    fail("broken-reference", path, target)
            except WorkflowError:
                fail("broken-reference", path, target)


def require_valid(repo: Repository):
    report = repo.validate()
    if report["status"] != "passed":
        raise WorkflowError("Foundation validation failed:\n" + json_text(report))
