from __future__ import annotations

import json
import os
import re
import uuid
from contextlib import contextmanager
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .repository import WorkflowError, atomic_json, read_json
from .tickets import merge_owned, normalized_markdown

ENDPOINT = "https://api.linear.app/graphql"
ISSUE_FIELDS = "id identifier title description url parent { id } labels { nodes { id name } } team { id }"


class LinearClient:
    def __init__(self, api_key: str):
        if not api_key:
            raise WorkflowError(
                "LINEAR_API_KEY is missing. Local export and handoff do not require credentials."
            )
        self.api_key = api_key

    def query(self, query: str, variables: dict | None = None):
        request = Request(
            ENDPOINT,
            data=json.dumps({"query": query, "variables": variables or {}}).encode(),
            headers={"Authorization": self.api_key, "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urlopen(request, timeout=30) as response:
                payload = json.load(response)
        except HTTPError as exc:
            raise WorkflowError(
                f"Linear returned HTTP {exc.code}; no automatic mutation retries. Re-run sync to reconcile by stable issue ID."
            ) from None
        except (URLError, TimeoutError, ValueError, OSError):
            raise WorkflowError(
                "Linear transport/response failure; no automatic mutation retries. Re-run sync to reconcile by stable issue ID."
            ) from None
        if payload.get("errors") or not payload.get("data"):
            raise WorkflowError(
                "Linear GraphQL operation failed, including possible partial errors. No automatic retries; re-run sync to reconcile."
            )
        return payload["data"]

    def connection(self, query: str, name: str, variables=None):
        variables = dict(variables or {})
        result, seen = [], set()
        while True:
            variables["after"] = variables.get("after")
            data = self.query(query, variables)[name]
            result.extend(data["nodes"])
            page = data["pageInfo"]
            if not page["hasNextPage"]:
                return result
            cursor = page["endCursor"]
            if not cursor or cursor in seen:
                raise WorkflowError("Linear pagination did not advance")
            seen.add(cursor)
            variables["after"] = cursor

    def team(self, key: str):
        teams = self.connection(
            "query Teams($after: String) { teams(first: 100, after: $after) { nodes { id key name } pageInfo { hasNextPage endCursor } } }",
            "teams",
        )
        matches = [team for team in teams if team["key"] == key]
        if len(matches) != 1:
            raise WorkflowError(
                f"Expected one existing Linear team with key {key}; found {len(matches)}"
            )
        return matches[0]

    def labels(self, team_id: str):
        labels = self.connection(
            "query Labels($after: String) { issueLabels(first: 100, after: $after) { nodes { id name team { id } } pageInfo { hasNextPage endCursor } } }",
            "issueLabels",
        )
        labels = [
            label
            for label in labels
            if not label.get("team") or label["team"]["id"] == team_id
        ]
        result = {}
        for label in labels:
            name = label["name"].lower()
            if name in result:
                raise WorkflowError(
                    f"Ambiguous Linear label: {name}; resolve team/global duplicates"
                )
            result[name] = label["id"]
        return result

    def issues(self, team_id: str):
        query = f"query Issues($filter: IssueFilter!, $after: String) {{ issues(first: 100, after: $after, includeArchived: true, filter: $filter) {{ nodes {{ {ISSUE_FIELDS} }} pageInfo {{ hasNextPage endCursor }} }} }}"
        return self.connection(
            query, "issues", {"filter": {"team": {"id": {"eq": team_id}}}}
        )

    def project(self, identifier: str, team_id: str):
        data = self.query(
            "query Project($id: String!) { project(id: $id) { id teams { nodes { id } } } }",
            {"id": identifier},
        )["project"]
        if not data or team_id not in {team["id"] for team in data["teams"]["nodes"]}:
            raise WorkflowError(
                "LINEAR_PROJECT_ID must identify an existing project associated with the selected team"
            )
        return data["id"]

    def create(self, fields: dict):
        data = self.query(
            f"mutation Create($input: IssueCreateInput!) {{ issueCreate(input: $input) {{ success issue {{ {ISSUE_FIELDS} }} }} }}",
            {"input": fields},
        )["issueCreate"]
        if not data.get("success") or not data.get("issue"):
            raise WorkflowError("Linear issue creation did not confirm success")
        return data["issue"]

    def update(self, identifier: str, fields: dict):
        data = self.query(
            f"mutation Update($id: String!, $input: IssueUpdateInput!) {{ issueUpdate(id: $id, input: $input) {{ success issue {{ {ISSUE_FIELDS} }} }} }}",
            {"id": identifier, "input": fields},
        )["issueUpdate"]
        if not data.get("success") or not data.get("issue"):
            raise WorkflowError("Linear issue update did not confirm success")
        return data["issue"]


def stable_issue_id(team_id: str, key: str):
    return str(
        uuid.uuid5(
            uuid.NAMESPACE_URL, f"https://dobar.app/agent-workflow/{team_id}/{key}"
        )
    )


@contextmanager
def sync_lock(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    except FileExistsError:
        raise WorkflowError(
            f"Another sync holds {path}; investigate stale locks before retrying"
        ) from None
    try:
        os.write(descriptor, str(os.getpid()).encode())
        os.close(descriptor)
        yield
    finally:
        path.unlink(missing_ok=True)


def synchronize(
    items, client, mapping_path: Path, team_key="DOB", apply=False, project_id=None
):
    if not apply:
        return _synchronize(items, client, mapping_path, team_key, False, project_id)
    with sync_lock(mapping_path.with_suffix(".lock")):
        return _synchronize(items, client, mapping_path, team_key, True, project_id)


def _synchronize(items, client, mapping_path, team_key, apply, project_id):
    team = client.team(team_key)
    labels = client.labels(team["id"])
    required_labels = {label.lower() for item in items for label in item["labels"]}
    missing = required_labels - labels.keys()
    if missing:
        raise WorkflowError(
            f"Configure existing area labels before sync: {', '.join(sorted(missing))}"
        )
    project = client.project(project_id, team["id"]) if project_id else None
    remote = client.issues(team["id"])
    known, by_id = {}, {}
    for issue in remote:
        by_id[issue["id"]] = issue
        text = issue.get("description") or ""
        keys = re.findall(r"<!-- dobar-task:([^\s]+) -->", text)
        if len(keys) > 1:
            raise WorkflowError(
                f"Issue {issue['id']} contains multiple task identity markers; reconcile before syncing"
            )
        for key in keys:
            if key in known:
                raise WorkflowError(
                    f"Duplicate remote ownership marker for {key}; reconcile before syncing"
                )
            known[key] = issue
    mapping = (
        read_json(mapping_path)
        if mapping_path.exists()
        else {"version": 1, "issues": {}}
    )
    planned, resolved = [], {}
    for item in items:
        key = item["key"]
        deterministic_id = stable_issue_id(team["id"], key)
        existing = known.get(key) or by_id.get(deterministic_id)
        saved = mapping["issues"].get(key)
        if saved and saved.get("team_id") != team["id"]:
            raise WorkflowError(f"Mapping for {key} belongs to another team")
        if saved and saved["id"] in by_id:
            mapped = by_id[saved["id"]]
            if existing and existing["id"] != mapped["id"]:
                raise WorkflowError(f"Mapping and remote marker disagree for {key}")
            existing = mapped
        if saved and not existing:
            raise WorkflowError(
                f"Previously mapped issue for {key} is unavailable; refusing replacement"
            )
        if existing:
            if f"<!-- dobar-task:{key} -->" not in (existing.get("description") or ""):
                raise WorkflowError(
                    f"Mapped issue for {key} has lost its identity marker"
                )
            if item["parent_key"] and (existing.get("parent") or {}).get(
                "id"
            ) != resolved.get(item["parent_key"]):
                raise WorkflowError(
                    f"Child issue for {key} has an unexpected parent; reconcile without overwriting human hierarchy choices"
                )
            description = merge_owned(existing.get("description"), item["description"])
            action = (
                "unchanged"
                if normalized_markdown(description)
                == normalized_markdown(existing.get("description") or "")
                else "update"
            )
            fields = {"description": description}
            issue_id = existing["id"]
        else:
            action, issue_id = "create", deterministic_id
            fields = {
                "id": issue_id,
                "teamId": team["id"],
                "title": item["title"],
                "description": item["description"],
                "priority": item["priority"],
                "labelIds": [labels[label.lower()] for label in item["labels"]],
            }
            if project:
                fields["projectId"] = project
            if item["parent_key"]:
                if item["parent_key"] not in resolved:
                    raise WorkflowError(f"Parent must precede child: {key}")
                fields["parentId"] = resolved[item["parent_key"]]
        resolved[key] = issue_id
        planned.append({"key": key, "action": action, "id": issue_id, "fields": fields})
    if apply:
        for operation in planned:
            if operation["action"] == "create":
                issue = client.create(operation["fields"])
            elif operation["action"] == "update":
                issue = client.update(operation["id"], operation["fields"])
            else:
                issue = by_id[operation["id"]]
            mapping["issues"][operation["key"]] = {
                "id": issue["id"],
                "identifier": issue.get("identifier"),
                "url": issue.get("url"),
                "team_id": team["id"],
            }
            atomic_json(mapping_path, mapping)
    return {
        "status": "applied" if apply else "preview",
        "team": team["key"],
        "operations": planned,
    }
