#!/usr/bin/env python3

import json
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch


SOURCE_DIR = Path(__file__).parents[1]
sys.path.insert(0, str(SOURCE_DIR))
import userland  # noqa: E402


FIXTURES = Path(__file__).parent / "fixtures"


class ParserTests(unittest.TestCase):
    def test_mise_rows_keep_manager_qualified_versions(self):
        payload = (FIXTURES / "mise-ls.json").read_text()
        rows = userland.parse_mise_ls(payload)
        self.assertEqual(
            [row["package_id"] for row in rows],
            ["mise:node@22.14.0", "mise:npm:@openai/codex@0.42.0"],
        )

    def test_mise_outdated_extracts_latest_versions(self):
        payload = (FIXTURES / "mise-outdated.json").read_text()
        self.assertEqual(
            userland.parse_mise_outdated(payload),
            {"node": "22.15.0", "npm:@openai/codex": "0.42.0"},
        )

    def test_mise_rows_fall_back_to_latest_for_direct_github_tools(self):
        class FakeUserland(userland.Userland):
            def __init__(self):
                super().__init__({})
                self.calls = []

            def _run(self, manager, argv, *, cwd=None):
                self.calls.append(argv)
                if argv == ["mise", "ls", "--global", "--json"]:
                    return subprocess.CompletedProcess(
                        argv,
                        0,
                        '{"github:anomalyco/opencode":[{"version":"1.18.21"}]}',
                        "",
                    )
                if argv == ["mise", "outdated", "--json"]:
                    return subprocess.CompletedProcess(argv, 0, "{}", "")
                if argv == ["mise", "latest", "github:anomalyco/opencode"]:
                    return subprocess.CompletedProcess(argv, 0, "1.18.22\n", "")
                raise AssertionError(f"unexpected command: {argv}")

        fake = FakeUserland()
        with patch.object(userland, "command_path", return_value="/nix/store/mise/bin/mise"):
            rows = fake.list_rows(manager="mise", include_available=True)

        self.assertEqual(rows[0]["available"], "1.18.22")
        self.assertEqual(rows[0]["status"], "outdated")
        self.assertEqual(
            rows[0]["upgrade_command"],
            "userland update mise:github:anomalyco/opencode@1.18.21",
        )
        self.assertIn(["mise", "latest", "github:anomalyco/opencode"], fake.calls)

    def test_print_rows_adds_upgrade_command_column_for_outdated_packages(self):
        output = StringIO()
        with redirect_stdout(output):
            userland.print_rows(
                [
                    {
                        "manager": "mise",
                        "package_id": "mise:github:anomalyco/opencode@1.18.21",
                        "name": "github:anomalyco/opencode",
                        "installed": "1.18.21",
                        "available": "1.18.22",
                        "status": "outdated",
                        "upgrade_command": "userland update mise:github:anomalyco/opencode@1.18.21",
                    }
                ]
            )
        rendered = output.getvalue()
        self.assertIn("UPGRADE COMMAND", rendered)
        self.assertIn("userland update mise:github:anomalyco/opencode@1.18.21", rendered)

    def test_flatpak_rows_detect_commit_changes(self):
        payload = (FIXTURES / "flatpak-list.tsv").read_text()
        rows = userland.parse_flatpak_list(payload)
        self.assertEqual(rows[0]["status"], "outdated")
        self.assertEqual(rows[1]["status"], "unknown")
        self.assertEqual(rows[0]["package_id"], "flatpak:org.example.Editor")

    def test_version_parser_handles_common_prefixes(self):
        self.assertEqual(userland.parse_version("tool 1.2.3\n"), "1.2.3")
        self.assertEqual(userland.parse_version("v4.5.6"), "4.5.6")

    def test_gearlever_list_parser_preserves_paths_with_spaces(self):
        payload = (FIXTURES / "gearlever-list.txt").read_text()
        rows = userland.parse_gearlever_list(payload)
        self.assertEqual(rows[0]["name"], "Example Editor")
        self.assertEqual(rows[0]["path"], "/home/test/Applications/Example Editor.AppImage")
        self.assertEqual(rows[1]["version"], "2.0.0")

    def test_mise_update_ids_drop_only_the_version_suffix(self):
        self.assertEqual(userland.Userland.mise_tool_name("node@22.14.0"), "node")
        self.assertEqual(
            userland.Userland.mise_tool_name("npm:@openai/codex@0.42.0"),
            "npm:@openai/codex",
        )

    def test_adapter_validation_rejects_privileged_commands(self):
        with tempfile.NamedTemporaryFile(mode="w+", suffix=".json") as fixture:
            fixture.write(json.dumps({"bad": {"commands": {"update": ["sudo", "thing"]}}}))
            fixture.flush()
            with self.assertRaises(ValueError):
                userland.load_adapters(Path(fixture.name))


if __name__ == "__main__":
    unittest.main()
