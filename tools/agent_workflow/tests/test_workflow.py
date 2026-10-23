import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.agent_workflow.__main__ import main
from tools.agent_workflow.linear import LinearClient, synchronize
from tools.agent_workflow.repository import (
    Repository,
    WorkflowError,
    atomic_json,
    frontmatter,
)
from tools.agent_workflow.tickets import END, drafts, export_tickets
from tools.agent_workflow.verification import checkout_fingerprint, handoff, verify
from tools.agent_workflow.tests.helpers import FakeLinear, fixture, write_document


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        fixture(self.root)
        self.repo = Repository(self.root)
        self.mapping = self.root / ".agent-workflow/mapping.json"
        self.items = drafts(self.repo, ["B08"])
        self.client = FakeLinear()

    def codes(self):
        return {finding["code"] for finding in self.repo.validate()["findings"]}

    def test_valid_foundation_does_not_validate_product(self):
        report = self.repo.validate()
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["product_verification"], "unverified")

    def test_dependency_cycles_and_unknown_roles_fail(self):
        self.repo.specs["B08"].meta["depends_on"] = ["B07"]
        self.repo.specs["B07"].meta["depends_on"] = ["B08"]
        self.repo.specs["C01"].meta["owner"] = "missing"
        self.assertTrue({"dependency-cycle", "spec-role"} <= self.codes())

    def test_broken_reference_and_source_drift_fail(self):
        path = self.repo.spec("B08").path
        path.write_text(path.read_text() + "\n[Missing](not-present.md)\n")
        (self.root / "docs/source.md").write_text("A new requirement")
        self.assertTrue({"broken-reference", "coverage-drift"} <= self.codes())

    def test_uncovered_requirements_and_duplicate_source_fail(self):
        path = self.root / ".specs/mvp-v0.1/requirements.json"
        data = json.loads(path.read_text())
        data["sources"].append(data["sources"][0])
        data["requirements"][0]["criteria"] = []
        atomic_json(path, data)
        self.assertTrue(
            {"coverage-duplicate-source", "coverage-unmapped"} <= self.codes()
        )

    def test_duplicate_frontmatter_is_rejected(self):
        path = self.root / "duplicate.md"
        path.write_text("---\nname: first\nname: second\n---\n")
        with self.assertRaisesRegex(WorkflowError, "Duplicate YAML"):
            frontmatter(path)

    def test_validated_metadata_requires_evidence(self):
        self.repo.spec("B08").meta["verification_status"] = "validated"
        self.assertIn("spec-evidence", self.codes())

    def test_validated_report_must_cover_every_required_check(self):
        spec = self.repo.spec("B08")
        spec.meta.update(
            {
                "verification_status": "validated",
                "verification_evidence": ".agent-workflow/evidence.json",
            }
        )
        report = {
            "spec_id": "B08",
            "status": "passed",
            "checkout_sha256": "checkout",
            "results": [],
        }
        path = self.root / ".agent-workflow/evidence.json"
        atomic_json(path, report)
        with patch(
            "tools.agent_workflow.verification.checkout_fingerprint",
            return_value="checkout",
        ):
            self.assertIn("spec-evidence", self.codes())
            report["results"] = [
                {"check": name, "status": "passed", "returncode": 0}
                for name in spec.meta["checks"]
            ]
            atomic_json(path, report)
            self.assertNotIn("spec-evidence", self.codes())
            report["results"][1]["status"] = "skipped"
            atomic_json(path, report)
            self.assertIn("spec-evidence", self.codes())

    def test_fingerprint_allows_evidence_metadata_but_detects_acceptance_edits(self):
        spec = self.repo.spec("B08")
        response = unittest.mock.Mock(
            returncode=0, stdout=(str(spec.path.relative_to(self.root)) + "\0").encode()
        )
        with patch(
            "tools.agent_workflow.verification.subprocess.run", return_value=response
        ):
            before = checkout_fingerprint(self.repo)
            meta, body = frontmatter(spec.path)
            meta.update(
                {
                    "verification_status": "validated",
                    "verification_evidence": ".agent-workflow/report.json",
                }
            )
            write_document(spec.path, meta, body.lstrip("\n"))
            self.assertEqual(before, checkout_fingerprint(self.repo))
            spec.path.write_text(
                spec.path.read_text().replace(
                    "Verified behavior", "A different acceptance requirement"
                )
            )
            self.assertNotEqual(before, checkout_fingerprint(self.repo))

    def test_acceptance_references_cannot_replace_definitions(self):
        self.repo.spec("B08").body = "Mentioned in another section: B08-AC01"
        self.assertIn("acceptance", self.codes())
        self.assertIn("coverage-criterion", self.codes())

    def test_ticket_export_is_deterministic_and_preserves_source(self):
        output = self.root / ".agent-workflow/export"
        before = self.repo.spec("B08").path.read_bytes()
        export_tickets(self.repo, output)
        first = {p.name: p.read_bytes() for p in output.iterdir()}
        export_tickets(self.repo, output)
        self.assertEqual(first, {p.name: p.read_bytes() for p in output.iterdir()})
        self.assertEqual(before, self.repo.spec("B08").path.read_bytes())
        self.assertEqual(len(self.items), 3)
        self.assertEqual({item["area"] for item in self.items}, {None, "fe", "be"})

    def test_preview_does_not_mutate_remote_or_mapping(self):
        result = synchronize(self.items, self.client, self.mapping)
        self.assertEqual(result["status"], "preview")
        self.assertEqual(len(result["operations"]), 3)
        self.assertEqual(self.client.calls, [])
        self.assertFalse(self.mapping.exists())

    def test_configured_workspace_labels_are_reused_case_insensitively(self):
        atomic_json(
            self.root / "tools/agent_workflow/linear-config.json",
            {
                "team_key": "DOB",
                "area_labels": {"fe": "barz-fe", "be": "barz-be", "dpe": "payments"},
                "feature_label": "Feature",
            },
        )
        items = drafts(self.repo, ["B08"])
        self.client.labels = lambda team: {
            "barz-fe": "fe",
            "barz-be": "be",
            "feature": "feature",
        }
        synchronize(items, self.client, self.mapping, apply=True)
        self.assertEqual(
            list(self.client.remote.values())[0]["labelIds"], ["feature", "fe", "be"]
        )

    def test_linear_markdown_normalization_does_not_trigger_an_update(self):
        synchronize(self.items, self.client, self.mapping, apply=True)
        for issue in self.client.remote.values():
            issue["description"] = (
                issue["description"]
                .replace("\n- ", "\n* ")
                .replace(
                    "\n<!-- dobar-workflow:end -->", "\n  <!-- dobar-workflow:end -->"
                )
            )
        result = synchronize(self.items, self.client, self.mapping)
        self.assertEqual(
            {operation["action"] for operation in result["operations"]}, {"unchanged"}
        )

    def test_repeat_sync_creates_no_duplicates_and_preserves_human_fields(self):
        synchronize(self.items, self.client, self.mapping, apply=True)
        parent = next(iter(self.client.remote.values()))
        parent["description"] = (
            "Human preface\n" + parent["description"] + "\nHuman notes"
        )
        parent.update(
            {
                "title": "Human title",
                "stateId": "doing",
                "assigneeId": "person",
                "labelIds": ["custom"],
            }
        )
        self.items[0]["description"] = self.items[0]["description"].replace(
            "Verified behavior", "Changed behavior"
        )
        synchronize(self.items, self.client, self.mapping, apply=True)
        synchronize(self.items, self.client, self.mapping, apply=True)
        self.assertEqual(len(self.client.remote), 3)
        self.assertEqual(sum(kind == "create" for kind, _ in self.client.calls), 3)
        parent = next(iter(self.client.remote.values()))
        self.assertTrue(parent["description"].startswith("Human preface\n"))
        self.assertTrue(parent["description"].endswith("\nHuman notes"))
        self.assertEqual(parent["title"], "Human title")
        self.assertEqual(parent["stateId"], "doing")
        self.assertEqual(parent["labelIds"], ["custom"])

    def test_partial_failure_saves_mapping_and_resumes(self):
        self.client.fail_at = 2
        with self.assertRaises(WorkflowError):
            synchronize(self.items, self.client, self.mapping, apply=True)
        self.assertEqual(len(json.loads(self.mapping.read_text())["issues"]), 1)
        self.client.fail_at = None
        synchronize(self.items, self.client, self.mapping, apply=True)
        self.assertEqual(len(self.client.remote), 3)

    def test_lost_create_response_recovers_by_remote_identity(self):
        self.client.lose_response_at = 1
        with self.assertRaises(WorkflowError):
            synchronize(self.items, self.client, self.mapping, apply=True)
        self.assertFalse(self.mapping.exists())
        self.client.lose_response_at = None
        synchronize(self.items, self.client, self.mapping, apply=True)
        self.assertEqual(len(self.client.remote), 3)
        self.assertEqual(sum(kind == "create" for kind, _ in self.client.calls), 3)

    def test_damaged_marker_and_wrong_parent_preflight_before_writes(self):
        synchronize(self.items, self.client, self.mapping, apply=True)
        child = list(self.client.remote.values())[1]
        child["parent"] = {"id": "human-chosen-other-parent"}
        previous_calls = len(self.client.calls)
        with self.assertRaisesRegex(WorkflowError, "unexpected parent"):
            synchronize(self.items, self.client, self.mapping, apply=True)
        self.assertEqual(len(self.client.calls), previous_calls)
        child["parent"] = {"id": next(iter(self.client.remote))}
        child["description"] = child["description"].replace(END, "")
        with self.assertRaisesRegex(WorkflowError, "ownership markers"):
            synchronize(self.items, self.client, self.mapping, apply=True)

    def test_multiple_task_markers_cannot_alias_distinct_tasks(self):
        synchronize(self.items, self.client, self.mapping, apply=True)
        parent = next(iter(self.client.remote.values()))
        parent["description"] += f"\n<!-- dobar-task:{self.items[1]['key']} -->"
        previous_calls = len(self.client.calls)
        with self.assertRaisesRegex(WorkflowError, "multiple task"):
            synchronize(self.items, self.client, self.mapping, apply=True)
        self.assertEqual(len(self.client.calls), previous_calls)

    def test_missing_label_blocks_before_creation(self):
        self.client.labels = lambda team: {"frontend": "fe"}
        with self.assertRaisesRegex(WorkflowError, "labels"):
            synchronize(self.items, self.client, self.mapping, apply=True)
        self.assertEqual(self.client.calls, [])

    def test_missing_credentials_preview_is_incomplete(self):
        with patch.dict(os.environ, {}, clear=True), patch("sys.stdout"):
            self.assertEqual(
                main(["--root", str(self.root), "tickets", "sync", "--spec", "B08"]), 2
            )
        self.assertFalse(self.mapping.exists())

    def test_graphql_partial_errors_are_not_success(self):
        response = unittest.mock.MagicMock()
        response.__enter__.return_value.read.return_value = (
            b'{"data":{"ok":true},"errors":[{"message":"bad"}]}'
        )
        with patch("tools.agent_workflow.linear.urlopen", return_value=response):
            with self.assertRaisesRegex(WorkflowError, "partial errors"):
                LinearClient("test-key").query("query { viewer { id } }")

    def test_pagination_collects_all_pages(self):
        client = LinearClient("test-key")
        with patch.object(
            client,
            "query",
            side_effect=[
                {
                    "teams": {
                        "nodes": [{"id": "first"}],
                        "pageInfo": {"hasNextPage": True, "endCursor": "next"},
                    }
                },
                {
                    "teams": {
                        "nodes": [{"id": "second"}],
                        "pageInfo": {"hasNextPage": False, "endCursor": None},
                    }
                },
            ],
        ):
            self.assertEqual(
                [item["id"] for item in client.connection("query", "teams")],
                ["first", "second"],
            )

    def test_handoff_includes_role_context_criteria_and_checks(self):
        text = handoff(self.repo, "B08", "frontend")
        for expected in (
            "B08-AC01",
            "fe/AGENTS.md",
            "dobar-spec",
            "product-e2e",
            "Test agent",
        ):
            self.assertIn(expected, text)

    def test_verification_blocks_unconfigured_journey_and_records_skip(self):
        with patch(
            "tools.agent_workflow.verification.checkout_fingerprint",
            return_value="checkout",
        ):
            report = verify(self.repo, "B08")
            self.assertEqual(report["status"], "incomplete")
            self.assertEqual(report["verification_status"], "partial")
            self.assertEqual(
                [r["status"] for r in report["results"]], ["passed", "blocked"]
            )
            skipped = verify(self.repo, "B08", ["product-e2e"])
            self.assertEqual(skipped["status"], "incomplete")
            self.assertEqual(skipped["results"][1]["status"], "skipped")

    def test_failed_check_missing_environment_and_changed_checkout(self):
        self.repo.checks["foundation"]["command"] = [
            "{python}",
            "-c",
            "raise SystemExit(3)",
        ]
        self.repo.checks["product-e2e"] = {
            "command": ["absent-executable"],
            "requires_env": ["DOBAR_TEST_MISSING_ENV"],
        }
        with patch.dict(os.environ, {}, clear=True), patch(
            "tools.agent_workflow.verification.checkout_fingerprint",
            side_effect=["before", "after"],
        ):
            report = verify(self.repo, "B08")
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["results"][1]["status"], "blocked")
        self.assertEqual(report["results"][-1]["check"], "checkout-stability")

    def test_unavailable_git_is_a_blocked_check_not_validated(self):
        with patch(
            "tools.agent_workflow.verification.checkout_fingerprint",
            side_effect=WorkflowError("Git unavailable"),
        ):
            report = verify(self.repo, "B08")
        self.assertEqual(report["status"], "incomplete")
        self.assertIsNone(report["checkout_sha256"])
        self.assertEqual(report["results"][0]["status"], "blocked")
        self.assertNotEqual(report["verification_status"], "validated")


if __name__ == "__main__":
    unittest.main()
