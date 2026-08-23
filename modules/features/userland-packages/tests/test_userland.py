#!/usr/bin/env python3

import json
import sys
import tempfile
import unittest
from pathlib import Path


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
