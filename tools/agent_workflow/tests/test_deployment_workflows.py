import fnmatch
import itertools
import os
import re
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

import yaml


class DeploymentWorkflowTests(unittest.TestCase):
    root = Path(__file__).resolve().parents[3]

    def workflow(self, name):
        return yaml.safe_load(
            (self.root / ".github/workflows" / name).read_text()
        )

    def triggers(self, workflow):
        return workflow.get("on", workflow.get(True))

    def needs(self, job):
        needs = job.get("needs", [])
        return [needs] if isinstance(needs, str) else needs

    def assert_success_gated(self, job):
        self.assertNotIn("if", job)
        self.assertFalse(job.get("continue-on-error", False))

    def test_one_production_entry_serializes_all_three_stages(self):
        workflow = self.workflow("deploy.yml")
        self.assertEqual(self.triggers(workflow)["push"]["branches"], ["main"])
        self.assertEqual(workflow["concurrency"]["group"], "production-deployment")
        self.assertIs(workflow["concurrency"]["cancel-in-progress"], False)
        jobs = workflow["jobs"]
        self.assertEqual(self.needs(jobs["dpe"]), ["changes"])
        self.assertEqual(self.needs(jobs["be"]), ["changes", "dpe"])
        self.assertEqual(self.needs(jobs["fe"]), ["changes", "dpe", "be"])
        for area in ("dpe", "be", "fe"):
            job = jobs[area]
            self.assertEqual(job["uses"], f"./.github/workflows/deploy-{area}.yml")
            self.assertEqual(job["secrets"], "inherit")
            self.assertFalse(job.get("continue-on-error", False))
            self.assertEqual(
                set(self.triggers(self.workflow(f"deploy-{area}.yml"))),
                {"workflow_call"},
            )

    def test_entry_only_triggers_for_service_changes(self):
        paths = self.triggers(self.workflow("deploy.yml"))["push"]["paths"]
        for area in ("dpe", "be", "fe"):
            self.assertTrue(any(fnmatch.fnmatchcase(f"{area}/source", pattern) for pattern in paths))
        for path in (
            "docs/AGENT_WORKFLOW.md", "tools/agent_workflow/fixtures/pix-checkout.json",
            ".github/workflows/deploy.yml", ".github/workflows/deploy-be.yml",
            ".github/workflows/fe-unit-tests.yml", ".github/workflows/run-migrations.yml",
            ".github/workflows/payment-contract-validation.yml",
        ):
            with self.subTest(path=path):
                self.assertFalse(any(fnmatch.fnmatchcase(path, pattern) for pattern in paths))

    def detection_script(self):
        job = self.workflow("deploy.yml")["jobs"]["changes"]
        checkout, detect = job["steps"]
        self.assertEqual(checkout["with"]["fetch-depth"], 0)
        self.assertEqual(detect["env"]["BEFORE_SHA"], "${{ github.event.before }}")
        for area in ("dpe", "be", "fe"):
            self.assertEqual(job["outputs"][area], "${{ steps.detect.outputs." + area + " }}")
        return textwrap.dedent(detect["run"].split("<<'PY'\n", 1)[1].rsplit("\nPY", 1)[0])

    def test_detection_compares_all_pushed_commits_and_handles_moves_deletions(self):
        script = self.detection_script()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)

            def git(*args):
                return subprocess.check_output(["git", *args], cwd=root, stderr=subprocess.PIPE).decode().strip()

            def commit():
                git("add", "-A")
                git("commit", "-qm", "fixture")
                return git("rev-parse", "HEAD")

            def detect(before, head):
                output = root / "outputs"
                output.unlink(missing_ok=True)
                subprocess.run(
                    ["python3", "-c", script], cwd=root, check=True,
                    env={**os.environ, "BEFORE_SHA": before, "GITHUB_SHA": head, "GITHUB_OUTPUT": str(output)},
                    capture_output=True,
                )
                return dict(line.split("=", 1) for line in output.read_text().splitlines())

            git("init", "-q")
            git("config", "user.email", "workflow@example.com")
            git("config", "user.name", "Workflow test")
            for area in ("fe", "be", "dpe", "docs"):
                (root / area).mkdir()
                (root / area / "source").write_text("original")
            base = commit()
            self.assertEqual(detect("0" * 40, base), {"dpe": "true", "be": "true", "fe": "true"})
            (root / "fe/source").write_text("frontend update")
            frontend = commit()
            self.assertEqual(detect(base, frontend), {"dpe": "false", "be": "false", "fe": "true"})
            (root / "be/source").write_text("backend update")
            backend = commit()
            self.assertEqual(detect(base, backend), {"dpe": "false", "be": "true", "fe": "true"})
            (root / "dpe/source").rename(root / "docs/moved")
            moved = commit()
            self.assertEqual(detect(backend, moved), {"dpe": "true", "be": "false", "fe": "false"})
            (root / "docs/source").write_text("documentation")
            docs = commit()
            self.assertEqual(detect(moved, docs), {"dpe": "false", "be": "false", "fe": "false"})
            (root / "fe/source").unlink()
            deleted = commit()
            self.assertEqual(detect(docs, deleted), {"dpe": "false", "be": "false", "fe": "true"})

    def condition_allows(self, area, changes, results, cancelled=False):
        expression = self.workflow("deploy.yml")["jobs"][area]["if"]
        expression = expression.replace("always()", "True").replace("!cancelled()", str(not cancelled))
        expression = expression.replace("&&", " and ").replace("||", " or ")
        expression = re.sub(r"needs\.changes\.outputs\.(\w+)", lambda match: repr(str(changes[match[1]]).lower()), expression)
        expression = re.sub(r"needs\.(\w+)\.result", lambda match: repr(results[match[1]]), expression)
        return eval(expression, {"__builtins__": {}})

    def test_only_changed_targets_run_for_every_folder_combination(self):
        for flags in itertools.product((False, True), repeat=3):
            changes = dict(zip(("dpe", "be", "fe"), flags))
            results = {"changes": "success"}
            for area in ("dpe", "be", "fe"):
                with self.subTest(changes=changes, area=area):
                    allowed = self.condition_allows(area, changes, results)
                    self.assertEqual(allowed, changes[area])
                    results[area] = "success" if allowed else "skipped"

    def test_failed_or_cancelled_upstream_blocks_changed_downstream(self):
        changes = {area: True for area in ("dpe", "be", "fe")}
        for outcome in ("failure", "cancelled"):
            self.assertFalse(self.condition_allows("be", changes, {"changes": "success", "dpe": outcome}))
            self.assertFalse(self.condition_allows("fe", changes, {"changes": "success", "dpe": outcome, "be": "skipped"}))
            self.assertFalse(self.condition_allows("fe", changes, {"changes": "success", "dpe": "skipped", "be": outcome}))
            self.assertFalse(self.condition_allows("fe", changes, {"changes": outcome, "dpe": "skipped", "be": "skipped"}))
        self.assertFalse(self.condition_allows("fe", changes, {"changes": "success", "dpe": "skipped", "be": "skipped"}, cancelled=True))

    def test_backend_completes_contracts_deploy_and_migrations_before_returning(self):
        jobs = self.workflow("deploy-be.yml")["jobs"]
        self.assertIn("test", self.needs(jobs["contracts"]))
        self.assertIn("contracts", self.needs(jobs["deploy"]))
        self.assertEqual(self.needs(jobs["check_migrations"]), ["deploy"])
        self.assertEqual(self.needs(jobs["migrations"]), ["check_migrations"])
        self.assertEqual(jobs["migrations"]["uses"], "./.github/workflows/run-migrations.yml")
        self.assertEqual(jobs["migrations"]["if"], "needs.check_migrations.outputs.should_migrate == 'true'")
        for job in jobs.values():
            self.assertFalse(job.get("continue-on-error", False))
        for stage in ("contracts", "deploy", "check_migrations"):
            self.assert_success_gated(jobs[stage])

    def test_service_deployments_require_their_tests_and_keep_caller_revision(self):
        for area in ("dpe", "be", "fe"):
            with self.subTest(area=area):
                workflow = self.workflow(f"deploy-{area}.yml")
                jobs = workflow["jobs"]
                self.assertIn("test", self.needs(jobs["deploy"]))
                self.assertEqual(jobs["test"]["uses"], f"./.github/workflows/{area}-unit-tests.yml")
                self.assertIn("workflow_call", self.triggers(self.workflow(f"{area}-unit-tests.yml")))
                self.assert_success_gated(jobs["deploy"])
                for job in jobs.values():
                    for step in job.get("steps", []):
                        if step.get("uses", "").startswith("actions/checkout@"):
                            self.assertNotIn("ref", step.get("with", {}))
