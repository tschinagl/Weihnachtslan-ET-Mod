"""Portable package checks: run with host Python, never start Linux or a game."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SPEC = importlib.util.spec_from_file_location("etlab_linux", Path(__file__).resolve().parents[1] / "scripts/etlab-linux.py")
TOOLS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOLS)


class CombinedPackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.runtime = self.root / "runtime/linux/etbudget"
        self.runtime.mkdir(parents=True)
        self.logs = self.root / "logs/linux"
        self.logs.mkdir(parents=True)
        (self.root / "docs").mkdir()
        (self.root / "docs/installation.md").write_text("Test instructions", encoding="utf-8")
        (self.root / "LICENSE").write_text("Test fixture", encoding="utf-8")
        self.state = dict(version="2.86.2", runtimePath="runtime/linux", commit="release-commit", patchSha256="same-patch")
        linux_files = {name: ("linux-" + name).encode() for name in TOOLS.MODULES}
        pak = io.BytesIO()
        with zipfile.ZipFile(pak, "w") as archive:
            for name in ("cgame.mp.x86_64.so", "ui.mp.x86_64.so"):
                archive.writestr(name, linux_files[name])
            archive.writestr("ui/common.menu", b"shared assets")
        linux_files["etbudget_v2.86.2.pk3"] = pak.getvalue()
        for name, data in linux_files.items():
            (self.runtime / name).write_bytes(data)
        (self.logs / "build.json").write_text(json.dumps({"files": {name: hashlib.sha256(data).hexdigest() for name, data in linux_files.items()}}), encoding="utf-8")
        for target, value in (("ROOT", self.root), ("LOGS", self.logs)):
            stub = patch.object(TOOLS, target, value)
            stub.start()
            self.addCleanup(stub.stop)
        stub = patch.object(TOOLS, "build", return_value=self.state)
        stub.start()
        self.addCleanup(stub.stop)
        for name, value in (("freedesktop_os_release", {"PRETTY_NAME": "Linux fixture"}), ("libc_ver", ("glibc", "2.39"))):
            stub = patch.object(TOOLS.platform, name, return_value=value)
            stub.start()
            self.addCleanup(stub.stop)

    def windows_package(self, patch_hash="same-patch", corrupt=False):
        target = self.root / "windows.zip"
        files = []
        with zipfile.ZipFile(target, "w") as archive:
            for name in ("cgame_mp_x64.dll", "ui_mp_x64.dll", "qagame_mp_x64.dll", "tvgame_mp_x64.dll"):
                data = ("windows-" + name).encode()
                files.append(dict(name=name, sha256=hashlib.sha256(data).hexdigest()))
                archive.writestr("etbudget/" + name, b"modified" if corrupt else data)
            archive.writestr("manifest.json", json.dumps(dict(platform="windows-x64", commit="release-commit", patchSha256=patch_hash, files=files)))
        return target

    def test_combined_package_preserves_shared_assets_and_both_platforms(self):
        TOOLS.export_mod(1, self.windows_package())
        outputs = list((self.root / "dist").glob("*.zip"))
        self.assertEqual(len(outputs), 1)
        with zipfile.ZipFile(outputs[0]) as archive:
            manifest = json.loads(archive.read("manifest.json"))
            self.assertEqual(manifest["platform"], "windows-x64-linux-x86_64")
            for name, expected in manifest["files"].items():
                self.assertEqual(hashlib.sha256(archive.read("etbudget/" + name)).hexdigest(), expected)
            for name in ("qagame_mp_x64.dll", "qagame.mp.x86_64.so"):
                self.assertIn("etbudget/" + name, archive.namelist())
            with zipfile.ZipFile(io.BytesIO(archive.read("etbudget/etbudget_v2.86.2.pk3"))) as pak:
                self.assertEqual(pak.read("ui/common.menu"), b"shared assets")
                for name in ("cgame_mp_x64.dll", "ui_mp_x64.dll", "cgame.mp.x86_64.so", "ui.mp.x86_64.so"):
                    self.assertEqual(pak.read(name), archive.read("etbudget/" + name))

    def test_different_gameplay_patch_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "denselben Source-Commit und Mod-Patch"):
            TOOLS.export_mod(1, self.windows_package(patch_hash="different-patch"))
        self.assertFalse((self.root / "dist").exists())

    def test_tampered_windows_binary_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "Pruefsumme"):
            TOOLS.export_mod(1, self.windows_package(corrupt=True))
        self.assertFalse((self.root / "dist").exists())


if __name__ == "__main__":
    unittest.main()
