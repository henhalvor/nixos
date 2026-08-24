#!/usr/bin/env python3
"""Small, stateless facade for mutable userland package managers."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any


UNKNOWN = "unknown"
VALID_STATUSES = {"current", "outdated", "unknown", "unavailable", "error"}
FORBIDDEN_EXECUTABLES = {
    "bash",
    "dash",
    "fish",
    "home-manager",
    "nixos-rebuild",
    "sh",
    "sudo",
    "systemctl",
    "zsh",
}


def command_path(executable: str) -> str | None:
    return shutil.which(executable)


def first_line(value: str) -> str:
    for line in value.splitlines():
        line = line.strip()
        if line:
            return line
    return UNKNOWN


def parse_version(value: str) -> str:
    value = first_line(value)
    if value == UNKNOWN:
        return value
    match = re.search(r"(?:version\s+|v)?([0-9]+(?:\.[0-9]+)+(?:[-+][0-9A-Za-z.-]+)?)", value)
    return match.group(1) if match else value


def result_error(result: subprocess.CompletedProcess[str]) -> str:
    message = (result.stderr or result.stdout).strip()
    return message or f"command exited with status {result.returncode}"


def run_command(
    argv: list[str],
    *,
    cwd: Path | None = None,
    stream: bool = False,
) -> subprocess.CompletedProcess[str]:
    if not argv:
        raise ValueError("empty command")
    if any("\x00" in part for part in argv):
        raise ValueError("command contains a NUL byte")
    if stream:
        return subprocess.run(argv, cwd=cwd, check=False, text=True)
    return subprocess.run(
        argv,
        cwd=cwd,
        check=False,
        text=True,
        capture_output=True,
    )


def package_row(
    manager: str,
    package_id: str,
    name: str,
    installed: str = UNKNOWN,
    available: str = UNKNOWN,
    status: str = UNKNOWN,
    error: str | None = None,
) -> dict[str, str]:
    if status not in VALID_STATUSES:
        status = "error"
    row = {
        "manager": manager,
        "package_id": package_id,
        "name": name,
        "installed": installed or UNKNOWN,
        "available": available or UNKNOWN,
        "status": status,
    }
    if error:
        row["error"] = error
    return row


def parse_mise_ls(payload: str) -> list[dict[str, str]]:
    data = json.loads(payload or "{}")
    rows: list[dict[str, str]] = []
    if not isinstance(data, dict):
        raise ValueError("mise ls --json returned a non-object")
    for tool, versions in data.items():
        if not isinstance(versions, list):
            continue
        for entry in versions:
            if not isinstance(entry, dict):
                continue
            version = str(entry.get("version") or UNKNOWN)
            package_id = f"mise:{tool}@{version}" if version != UNKNOWN else f"mise:{tool}"
            rows.append(
                package_row(
                    "mise",
                    package_id,
                    str(tool),
                    installed=version,
                )
            )
    return rows


def parse_mise_outdated(payload: str) -> dict[str, str]:
    data = json.loads(payload or "{}")
    if not isinstance(data, dict):
        raise ValueError("mise outdated --json returned a non-object")
    latest: dict[str, str] = {}
    for tool, entry in data.items():
        if isinstance(entry, dict) and entry.get("latest"):
            latest[str(tool)] = str(entry["latest"])
    return latest


def upgrade_command(package_id: str) -> str:
    """Return the copy-paste command for one manager-qualified package ID."""

    return f"userland update {shlex.quote(package_id)}"


def parse_flatpak_list(payload: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for raw_line in payload.splitlines():
        line = raw_line.strip("\n")
        if not line.strip():
            continue
        fields = line.split("\t")
        fields.extend([""] * (6 - len(fields)))
        app_id, name, version, origin, active, latest = fields[:6]
        if not app_id or app_id == "Application":
            continue
        status = "outdated" if active and latest and active != latest else UNKNOWN
        rows.append(
            package_row(
                "flatpak",
                f"flatpak:{app_id}",
                name or app_id,
                installed=version or UNKNOWN,
                status=status,
            )
            | {"origin": origin, "active": active, "latest_commit": latest}
        )
    return rows


def parse_flatpak_remote_info(payload: str) -> str:
    for line in payload.splitlines():
        if line.lower().startswith("version:"):
            return line.split(":", 1)[1].strip() or UNKNOWN
    return UNKNOWN


def parse_gearlever_line(line: str) -> dict[str, str] | None:
    """Parse Gear Lever's stable bracketed CLI table format."""

    match = re.match(r"^(.+?)\s+\[([^\]]*)\]\s+\[([^\]]*)\]\s+(.+)$", line.strip())
    if not match:
        return None
    name, version, manager, path = match.groups()
    if not path.startswith("/"):
        return None
    return {
        "name": name.strip(),
        "version": version.strip() or UNKNOWN,
        "manager": manager.strip(),
        "path": path.strip(),
    }


def parse_gearlever_list(payload: str) -> list[dict[str, str]]:
    return [
        entry
        for line in payload.splitlines()
        if (entry := parse_gearlever_line(line)) is not None
    ]


def load_adapters(path: Path) -> dict[str, dict[str, Any]]:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text())
    if not isinstance(data, dict):
        raise ValueError("upstream adapter configuration must be an object")
    adapters: dict[str, dict[str, Any]] = {}
    for name, spec in data.items():
        if not isinstance(name, str) or not isinstance(spec, dict):
            raise ValueError("upstream adapter entries must be objects")
        commands = spec.get("commands", {})
        if not isinstance(commands, dict):
            raise ValueError(f"adapter {name!r} commands must be an object")
        normalized: dict[str, list[str]] = {}
        for action, argv in commands.items():
            if not isinstance(action, str) or not isinstance(argv, list) or not argv:
                raise ValueError(f"adapter {name!r} has an invalid {action!r} command")
            if not all(isinstance(part, str) and part for part in argv):
                raise ValueError(f"adapter {name!r} has a malformed {action!r} command")
            executable = Path(argv[0]).name
            if executable in FORBIDDEN_EXECUTABLES:
                raise ValueError(f"adapter {name!r} may not invoke {executable}")
            if any(part in FORBIDDEN_EXECUTABLES or part in {"-c", "--command"} for part in argv):
                raise ValueError(f"adapter {name!r} contains a forbidden command")
            normalized[action] = argv
        adapters[name] = {
            "display_name": str(spec.get("displayName") or name),
            "commands": normalized,
        }
    return adapters


class Userland:
    def __init__(self, adapters: dict[str, dict[str, Any]]) -> None:
        self.home = Path.home()
        self.adapters = adapters
        self.backend_errors: dict[str, str] = {}

    def _record_error(self, manager: str, error: str) -> None:
        self.backend_errors[manager] = error

    def _run(self, manager: str, argv: list[str], *, cwd: Path | None = None) -> subprocess.CompletedProcess[str] | None:
        try:
            result = run_command(argv, cwd=cwd)
        except (OSError, ValueError) as exc:
            self._record_error(manager, str(exc))
            return None
        if result.returncode != 0:
            self._record_error(manager, result_error(result))
        return result

    def mise_rows(self, include_available: bool) -> list[dict[str, str]]:
        if not command_path("mise"):
            self._record_error("mise", "mise is not available in PATH")
            return []
        result = self._run("mise", ["mise", "ls", "--global", "--json"], cwd=self.home)
        if result is None or result.returncode != 0:
            return []
        try:
            rows = parse_mise_ls(result.stdout)
        except (TypeError, ValueError, json.JSONDecodeError) as exc:
            self._record_error("mise", str(exc))
            return []
        if not include_available:
            return rows
        outdated = self._run("mise", ["mise", "outdated", "--json"], cwd=self.home)
        latest: dict[str, str] = {}
        if outdated is not None and outdated.returncode == 0:
            try:
                latest = parse_mise_outdated(outdated.stdout)
            except (TypeError, ValueError, json.JSONDecodeError) as exc:
                self._record_error("mise", str(exc))
        for row in rows:
            tool = row["name"]
            available = latest.get(tool, UNKNOWN)
            if available == UNKNOWN and outdated is not None and outdated.returncode == 0:
                # `mise outdated --json` omits direct GitHub tools when they are
                # current. Query `mise latest` so those tools still get a
                # useful AVAILABLE/STATUS result in the unified inventory.
                latest_result = self._run("mise", ["mise", "latest", tool], cwd=self.home)
                if latest_result is not None and latest_result.returncode == 0:
                    parsed_latest = parse_version(latest_result.stdout)
                    if parsed_latest != UNKNOWN:
                        available = parsed_latest
            row["available"] = available
            if available == UNKNOWN:
                row["status"] = "unknown"
            else:
                row["status"] = "outdated" if available != row["installed"] else "current"
        return rows

    def flatpak_rows(self, include_available: bool) -> list[dict[str, str]]:
        if not command_path("flatpak"):
            self._record_error("flatpak", "flatpak is not available in PATH")
            return []
        result = self._run(
            "flatpak",
            [
                "flatpak",
                "--user",
                "list",
                "--app",
                "--columns=application,name,version,origin,active,latest",
            ],
            cwd=self.home,
        )
        if result is None or result.returncode != 0:
            return []
        try:
            rows = parse_flatpak_list(result.stdout)
        except (TypeError, ValueError) as exc:
            self._record_error("flatpak", str(exc))
            return []
        if not include_available:
            return rows
        for row in rows:
            origin = row.get("origin")
            app_id = row["package_id"].split(":", 1)[1]
            if not origin:
                continue
            remote = self._run(
                "flatpak",
                ["flatpak", "--user", "remote-info", "--app", origin, app_id],
                cwd=self.home,
            )
            if remote is None or remote.returncode != 0:
                row["status"] = "unknown"
                row["error"] = "unable to query the configured Flatpak remote"
                continue
            row["available"] = parse_flatpak_remote_info(remote.stdout)
            if row["available"] != UNKNOWN and row["installed"] != UNKNOWN:
                row["status"] = "outdated" if row["available"] != row["installed"] else "current"
        return rows

    def appimage_rows(self, include_available: bool) -> list[dict[str, str]]:
        if not command_path("gearlever"):
            self._record_error("appimage", "Gear Lever is not available in PATH")
            return []
        result = self._run("appimage", ["gearlever", "--list-installed"], cwd=self.home)
        if result is None or result.returncode != 0:
            return []
        try:
            installed = parse_gearlever_list(result.stdout)
        except (TypeError, ValueError) as exc:
            self._record_error("appimage", str(exc))
            return []
        update_paths: set[str] = set()
        if include_available:
            updates = self._run("appimage", ["gearlever", "--list-updates"], cwd=self.home)
            if updates is not None and updates.returncode == 0:
                update_paths = {
                    entry["path"]
                    for entry in parse_gearlever_list(updates.stdout)
                }
        rows: list[dict[str, str]] = []
        for entry in installed:
            path = Path(entry["path"])
            try:
                display_path = path.relative_to(self.home).as_posix()
            except ValueError:
                display_path = str(path)
            status = "outdated" if entry["path"] in update_paths else UNKNOWN
            rows.append(
                package_row(
                    "appimage",
                    f"appimage:{display_path}",
                    entry["name"],
                    installed=entry["version"],
                    status=status,
                )
            )
        return rows

    def upstream_rows(self, include_available: bool) -> list[dict[str, str]]:
        rows: list[dict[str, str]] = []
        for name, adapter in self.adapters.items():
            commands = adapter["commands"]
            version_command = commands.get("version")
            if not version_command:
                rows.append(
                    package_row(
                        "upstream",
                        f"upstream:{name}",
                        adapter["display_name"],
                        status="unavailable",
                        error="adapter has no version command",
                    )
                )
                continue
            result = self._run("upstream", version_command, cwd=self.home)
            if result is None or result.returncode != 0:
                rows.append(
                    package_row(
                        "upstream",
                        f"upstream:{name}",
                        adapter["display_name"],
                        status="error",
                        error=self.backend_errors.get("upstream", "version command failed"),
                    )
                )
                continue
            installed = parse_version(result.stdout)
            available = UNKNOWN
            status = "unknown"
            if include_available and commands.get("available"):
                available_result = self._run("upstream", commands["available"], cwd=self.home)
                if available_result is not None and available_result.returncode == 0:
                    available = parse_version(available_result.stdout)
                    status = "current" if available == installed else "outdated"
                else:
                    status = "unknown"
            rows.append(
                package_row(
                    "upstream",
                    f"upstream:{name}",
                    adapter["display_name"],
                    installed=installed,
                    available=available,
                    status=status,
                )
            )
        return rows

    def list_rows(self, manager: str | None = None, include_available: bool = False) -> list[dict[str, str]]:
        rows: list[dict[str, str]] = []
        selected = {manager} if manager else {"mise", "flatpak", "appimage", "upstream"}
        if "mise" in selected:
            rows.extend(self.mise_rows(include_available))
        if "flatpak" in selected:
            rows.extend(self.flatpak_rows(include_available))
        if "appimage" in selected:
            rows.extend(self.appimage_rows(include_available))
        if "upstream" in selected:
            rows.extend(self.upstream_rows(include_available))
        for row in rows:
            if row.get("status") == "outdated":
                row["upgrade_command"] = upgrade_command(row["package_id"])
        return rows

    def manager_status(self) -> list[dict[str, Any]]:
        statuses: list[dict[str, Any]] = []

        def add(
            manager: str,
            executable: str,
            scope: str,
            capabilities: list[str],
            network: str,
            credentials: str,
            note: str | None = None,
        ) -> None:
            path = command_path(executable)
            version = UNKNOWN
            error = None
            if path:
                result = self._run(manager, [executable, "--version"], cwd=self.home)
                if result is not None and result.returncode == 0:
                    version = parse_version(result.stdout)
                elif result is not None:
                    error = result_error(result)
            else:
                error = f"{executable} is not available in PATH"
            entry: dict[str, Any] = {
                "manager": manager,
                "executable": executable,
                "available": bool(path),
                "version": version,
                "scope": scope,
                "network": network,
                "credentials": credentials,
                "capabilities": capabilities,
            }
            if note:
                entry["note"] = note
            if error:
                entry["error"] = error
            statuses.append(entry)

        add(
            "mise",
            "mise",
            "user",
            ["list", "search", "install", "update", "remove"],
            "on demand",
            "none by facade",
        )
        add(
            "flatpak",
            "flatpak",
            "user only",
            ["list", "search", "install", "update", "remove"],
            "on demand",
            "none by facade",
        )
        if command_path("gearlever"):
            statuses.append(
                {
                    "manager": "appimage",
                    "executable": "gearlever",
                    "available": True,
                    "version": os.environ.get("USERLAND_GEARLEVER_VERSION", UNKNOWN),
                    "scope": "user",
                    "network": "on demand",
                    "credentials": "none by facade",
                    "capabilities": ["list", "install", "update", "remove"],
                    "note": "Gear Lever 3.4.7 CLI is used for AppImage lifecycle operations",
                }
            )
        else:
            statuses.append(
                {
                    "manager": "appimage",
                    "executable": "gearlever",
                    "available": False,
                    "version": UNKNOWN,
                    "scope": "user",
                    "network": "on demand",
                    "credentials": "none by facade",
                    "capabilities": [],
                    "error": "Gear Lever is not available in PATH",
                }
            )
        for name, adapter in self.adapters.items():
            commands = adapter["commands"]
            executable = Path(next(iter(commands.values()))[0]).name if commands else name
            statuses.append(
                {
                    "manager": f"upstream:{name}",
                    "executable": executable,
                    "available": bool(commands.get("version")),
                    "version": UNKNOWN,
                    "scope": "user",
                    "network": "adapter-defined",
                    "credentials": "adapter-defined",
                    "capabilities": sorted(
                        action
                        for action in commands
                        if action in {"version", "available", "install", "update", "remove", "health"}
                    ),
                    "note": adapter["display_name"],
                }
            )
        return statuses

    def search(self, manager: str, query: str) -> int:
        if manager == "mise":
            argv = ["mise", "search", "--no-header", query]
        elif manager == "flatpak":
            argv = ["flatpak", "--user", "search", "--columns=application,name,version,remotes", query]
        else:
            print(f"Error: search is not supported for manager {manager!r}.", file=sys.stderr)
            return 2
        if not command_path(argv[0]):
            print(f"Error: {argv[0]} is not available in PATH.", file=sys.stderr)
            return 1
        result = self._run(manager, argv, cwd=self.home)
        if result is None:
            return 1
        if result.returncode == 0:
            print(result.stdout, end="")
            return 0
        print(result_error(result), file=sys.stderr)
        return result.returncode or 1

    def install(self, manager: str, spec: str) -> int:
        if not spec or spec.startswith("-") or "\x00" in spec:
            print("Error: package specification must be a non-option value.", file=sys.stderr)
            return 2
        if manager == "mise":
            argv = ["mise", "use", "--global", "--", spec]
        elif manager == "flatpak":
            argv = ["flatpak", "--user", "install", "--noninteractive", "--", spec]
        elif manager == "appimage":
            path = Path(spec).expanduser()
            if not path.is_file() or not path.is_absolute():
                print("Error: AppImage installation requires an existing absolute file path.", file=sys.stderr)
                return 2
            argv = ["gearlever", "--integrate", str(path), "--yes"]
        elif manager.startswith("upstream:"):
            name = manager.split(":", 1)[1]
            command = self.adapters.get(name, {}).get("commands", {}).get("install")
            if not command:
                print(f"Error: upstream adapter {name!r} has no install command.", file=sys.stderr)
                return 2
            argv = command + [spec]
        else:
            print(f"Error: installation is not supported for manager {manager!r}.", file=sys.stderr)
            return 2
        return self._mutate(manager, argv)

    def update_one(self, package_id: str) -> int:
        manager, value = split_package_id(package_id)
        if manager == "mise":
            return self._mutate(manager, ["mise", "upgrade", "--", self.mise_tool_name(value)])
        if manager == "flatpak":
            return self._mutate(manager, ["flatpak", "--user", "update", "--noninteractive", "--assumeyes", "--", value])
        if manager == "appimage":
            return self._mutate(manager, ["gearlever", "--update", str(self.appimage_path(value)), "--yes"])
        if manager == "upstream":
            name = value
            command = self.adapters.get(name, {}).get("commands", {}).get("update")
            if not command:
                print(f"Error: upstream adapter {name!r} has no update command.", file=sys.stderr)
                return 2
            return self._mutate(manager, command)
        print(f"Error: unknown package manager in {package_id!r}.", file=sys.stderr)
        return 2

    def update_all(self, assume_yes: bool) -> int:
        rows = self.list_rows(include_available=True)
        updates = [row for row in rows if row.get("status") == "outdated"]
        if updates:
            print("Proposed updates:")
            print_rows(updates)
        else:
            print("No updates were identified by the configured backends.")
        if self.backend_errors:
            print_backend_errors(self.backend_errors)
        if not assume_yes:
            if not sys.stdin.isatty():
                print("Error: userland update --all requires --yes without a TTY.", file=sys.stderr)
                return 2
            try:
                answer = input("Continue? [y/N] ")
            except EOFError:
                return 2
            if answer.strip().lower() not in {"y", "yes"}:
                print("Cancelled.")
                return 0
        failures = len(self.backend_errors)
        managers = {row["manager"] for row in updates}
        for manager in ("mise", "flatpak", "appimage"):
            if manager not in managers:
                continue
            if manager == "mise":
                code = self._mutate(manager, ["mise", "upgrade", "--yes"])
            elif manager == "flatpak":
                code = self._mutate(manager, ["flatpak", "--user", "update", "--noninteractive", "--assumeyes"])
            else:
                code = self._mutate(manager, ["gearlever", "--update", "--all", "--yes"])
            failures += int(code != 0)
        for row in updates:
            if row["manager"] == "upstream":
                failures += int(self.update_one(row["package_id"]) != 0)
        if failures:
            print(f"Update finished with {failures} failed backend operation(s).", file=sys.stderr)
            return 1
        print("Update finished.")
        return 0

    def remove(self, package_id: str) -> int:
        manager, value = split_package_id(package_id)
        if manager == "mise":
            return self._mutate(manager, ["mise", "unuse", "--global", "--", value])
        if manager == "flatpak":
            return self._mutate(manager, ["flatpak", "--user", "uninstall", "--noninteractive", "--assumeyes", "--", value])
        if manager == "appimage":
            return self._mutate(manager, ["gearlever", "--remove", str(self.appimage_path(value)), "--yes"])
        if manager == "upstream":
            name = value
            command = self.adapters.get(name, {}).get("commands", {}).get("remove")
            if not command:
                print(f"Error: upstream adapter {name!r} has no remove command.", file=sys.stderr)
                return 2
            return self._mutate(manager, command)
        print(f"Error: unknown package manager in {package_id!r}.", file=sys.stderr)
        return 2

    def appimage_path(self, value: str) -> Path:
        path = Path(value).expanduser()
        return path if path.is_absolute() else self.home / path

    @staticmethod
    def mise_tool_name(value: str) -> str:
        """Drop the installed version from an inventory ID before upgrading."""

        if "@" not in value:
            return value
        tool, requested = value.rsplit("@", 1)
        if requested == "latest" or re.match(r"^v?\d", requested):
            return tool
        return value

    def doctor(self) -> int:
        failures = 0
        statuses = self.manager_status()
        print_manager_status(statuses)
        if command_path("mise"):
            result = self._run("mise", ["mise", "doctor"], cwd=self.home)
            failures += int(result is None or result.returncode != 0)
        if command_path("flatpak"):
            result = self._run(
                "flatpak",
                ["flatpak", "--user", "remotes", "--columns=name,url"],
                cwd=self.home,
            )
            if result is None or result.returncode != 0:
                failures += 1
            else:
                print("Flatpak user remotes:")
                print(result.stdout, end="")
        if command_path("gearlever"):
            result = self._run("appimage", ["gearlever", "--list-installed"], cwd=self.home)
            failures += int(result is None or result.returncode != 0)
        for name, adapter in self.adapters.items():
            command = adapter["commands"].get("health")
            if command:
                result = self._run("upstream", command, cwd=self.home)
                failures += int(result is None or result.returncode != 0)
        if self.backend_errors:
            print_backend_errors(self.backend_errors)
            failures += len(self.backend_errors)
        return 1 if failures else 0

    def _mutate(self, manager: str, argv: list[str]) -> int:
        if os.geteuid() == 0:
            print("Error: userland must run as a normal user, not root.", file=sys.stderr)
            return 2
        if manager == "flatpak" and ("--system" in argv or "--installation" in argv):
            print("Error: userland only permits user-scoped Flatpak operations.", file=sys.stderr)
            return 2
        if not command_path(argv[0]):
            print(f"Error: {argv[0]} is not available in PATH.", file=sys.stderr)
            return 1
        try:
            result = run_command(argv, cwd=self.home, stream=True)
        except (OSError, ValueError) as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1
        return result.returncode


def split_package_id(package_id: str) -> tuple[str, str]:
    if ":" not in package_id:
        raise ValueError("package identifiers must include a manager prefix")
    manager, value = package_id.split(":", 1)
    if not manager or not value or value.startswith("-") or "\x00" in value:
        raise ValueError("invalid package identifier")
    return manager, value


def print_rows(rows: list[dict[str, str]]) -> None:
    columns = ["manager", "package_id", "name", "installed", "available", "status"]
    if any(row.get("upgrade_command") for row in rows):
        columns.append("upgrade_command")
    if not rows:
        print("No packages reported.")
        return
    widths = {column: max(len(column), *(len(str(row.get(column, ""))) for row in rows)) for column in columns}
    headings = {"upgrade_command": "UPGRADE COMMAND"}
    print("  ".join(headings.get(column, column.upper()).ljust(widths[column]) for column in columns))
    print("  ".join("-" * widths[column] for column in columns))
    for row in rows:
        print("  ".join(str(row.get(column, "")).ljust(widths[column]) for column in columns))
    errors = [f"{row['package_id']}: {row['error']}" for row in rows if row.get("error")]
    if errors:
        print("\nPackage notes:")
        for error in errors:
            print(f"- {error}")


def print_manager_status(statuses: list[dict[str, Any]]) -> None:
    columns = ["manager", "available", "version", "scope", "network", "credentials", "capabilities"]
    widths = {column: max(len(column), *(len(str(entry.get(column, ""))) for entry in statuses)) for column in columns}
    print("  ".join(column.upper().ljust(widths[column]) for column in columns))
    print("  ".join("-" * widths[column] for column in columns))
    for entry in statuses:
        values = dict(entry)
        values["available"] = "yes" if entry.get("available") else "no"
        values["capabilities"] = ",".join(entry.get("capabilities", [])) or "none"
        print("  ".join(str(values.get(column, "")).ljust(widths[column]) for column in columns))
        if entry.get("note"):
            print(f"  note: {entry['note']}")
        if entry.get("error"):
            print(f"  error: {entry['error']}")


def print_backend_errors(errors: dict[str, str]) -> None:
    print("Backend errors:")
    for manager, error in errors.items():
        print(f"- {manager}: {error}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="userland", description="Inspect and update mutable userland packages.")
    parser.add_argument("--adapters-file", type=Path, required=True, help=argparse.SUPPRESS)
    subparsers = parser.add_subparsers(dest="command", required=True)

    managers = subparsers.add_parser("managers", help="Show configured managers")
    managers.add_argument("--json", action="store_true")

    for name in ("list", "outdated"):
        command = subparsers.add_parser(name, help=f"Show {name} packages")
        command.add_argument("--manager", choices=["mise", "flatpak", "appimage", "upstream"])
        command.add_argument("--json", action="store_true")

    search = subparsers.add_parser("search", help="Search a native manager")
    search.add_argument("--manager", choices=["mise", "flatpak"], required=True)
    search.add_argument("query")

    install = subparsers.add_parser("install", help="Install a package through one manager")
    install.add_argument("manager")
    install.add_argument("spec")

    update = subparsers.add_parser("update", help="Update one package or all known updates")
    update.add_argument("package_id", nargs="?")
    update.add_argument("--all", action="store_true")
    update.add_argument("--yes", action="store_true")

    remove = subparsers.add_parser("remove", help="Remove a package through its manager")
    remove.add_argument("package_id")

    doctor = subparsers.add_parser("doctor", help="Check manager availability and scope")
    doctor.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        adapters = load_adapters(args.adapters_file)
        userland = Userland(adapters)
        if args.command == "managers":
            statuses = userland.manager_status()
            if args.json:
                print(json.dumps(statuses, indent=2, sort_keys=True))
            else:
                print_manager_status(statuses)
            return 0
        if args.command in {"list", "outdated"}:
            rows = userland.list_rows(args.manager, include_available=True)
            if args.json:
                print(
                    json.dumps(
                        {
                            "packages": rows,
                            "backend_errors": userland.backend_errors,
                        },
                        indent=2,
                        sort_keys=True,
                    )
                )
            else:
                print_rows(rows)
                if userland.backend_errors:
                    print_backend_errors(userland.backend_errors)
            return 0
        if args.command == "search":
            return userland.search(args.manager, args.query)
        if args.command == "install":
            return userland.install(args.manager, args.spec)
        if args.command == "update":
            if args.all == bool(args.package_id):
                parser.error("use exactly one of PACKAGE_ID or --all")
            if args.all:
                return userland.update_all(args.yes)
            try:
                return userland.update_one(args.package_id)
            except ValueError as exc:
                print(f"Error: {exc}", file=sys.stderr)
                return 2
        if args.command == "remove":
            try:
                return userland.remove(args.package_id)
            except ValueError as exc:
                print(f"Error: {exc}", file=sys.stderr)
                return 2
        if args.command == "doctor":
            statuses = userland.manager_status()
            if args.json:
                print(json.dumps(statuses, indent=2, sort_keys=True))
                return 0
            return userland.doctor()
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
