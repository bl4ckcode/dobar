import fnmatch
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
        self.assertEqual(self.needs(jobs["dpe"]), [])
        self.assertEqual(self.needs(jobs["be"]), ["dpe"])
        self.assertEqual(self.needs(jobs["fe"]), ["be"])
        for area in ("dpe", "be", "fe"):
            job = jobs[area]
            self.assertEqual(job["uses"], f"./.github/workflows/deploy-{area}.yml")
            self.assertEqual(job["secrets"], "inherit")
            self.assert_success_gated(job)
            self.assertEqual(
                set(self.triggers(self.workflow(f"deploy-{area}.yml"))),
                {"workflow_call"},
            )

    def test_entry_covers_service_and_workflow_changes(self):
        paths = self.triggers(self.workflow("deploy.yml"))["push"]["paths"]
        affected = [
            "dpe/dobar_payment/api/routes.py", "be/app/auth/profile.py",
            "fe/pubspec.yaml", "tools/agent_workflow/fixtures/pix-checkout.json",
            ".github/workflows/payment-contract-validation.yml",
            ".github/workflows/run-migrations.yml",
        ]
        affected += [f".github/workflows/deploy{suffix}.yml" for suffix in ("", "-dpe", "-be", "-fe")]
        affected += [f".github/workflows/{area}-unit-tests.yml" for area in ("dpe", "be", "fe")]
        for path in affected:
            with self.subTest(path=path):
                self.assertTrue(any(fnmatch.fnmatchcase(path, pattern) for pattern in paths))

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
