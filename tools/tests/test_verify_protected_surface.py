from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "tools" / "verify_protected_surface.py"


class VerifyProtectedSurfaceTests(unittest.TestCase):
    def test_write_baseline_records_clean_protected_surface(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            self._init_repo(repo)

            result = self._run_verifier(repo, "--write-baseline")

            self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
            baseline_path = repo / "completion-evidence" / "protected-surface-baseline.json"
            baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
            self.assertEqual(baseline["mode"], "product")
            self.assertEqual(baseline["protected_surface_diff_status"], "clean")
            self.assertGreaterEqual(len(baseline["protected_items"]), 2)

    def test_modified_protected_file_blocks_product_verification(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            self._init_repo(repo)
            (repo / "governance" / "policy.md").write_text("changed\n", encoding="utf-8")

            result = self._run_verifier(repo)

            self.assertEqual(result.returncode, 1)
            self.assertIn("protected surface has changes", result.stdout)

    def _run_verifier(self, repo: Path, *extra_args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--mode",
                "product",
                "--output",
                "completion-evidence/protected-surface-baseline.json",
                *extra_args,
            ],
            cwd=repo,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )

    def _init_repo(self, repo: Path) -> None:
        subprocess.run(["git", "init"], cwd=repo, check=True, stdout=subprocess.PIPE)
        subprocess.run(["git", "config", "user.email", "owner@example.com"], cwd=repo, check=True)
        subprocess.run(["git", "config", "user.name", "Repo Owner"], cwd=repo, check=True)

        (repo / ".github" / "workflows").mkdir(parents=True)
        (repo / ".github" / "workflows" / "protected.yml").write_text("name: protected\n", encoding="utf-8")
        (repo / "governance").mkdir()
        (repo / "governance" / "policy.md").write_text("# Policy\n", encoding="utf-8")
        (repo / "README.md").write_text("# Test Repo\n", encoding="utf-8")

        subprocess.run(["git", "add", "."], cwd=repo, check=True)
        subprocess.run(["git", "commit", "-m", "Initial baseline"], cwd=repo, check=True, stdout=subprocess.PIPE)


if __name__ == "__main__":
    unittest.main()
