"""Windows PowerShell black-box launcher tests; only temporary fake executables run."""
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest


LAUNCHER = Path(__file__).with_name("map_production.ps1")
POWERSHELL = shutil.which("powershell.exe")


def ps_literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def powershell(script, env=None):
    encoded = base64.b64encode(script.encode("utf-16-le")).decode("ascii")
    return subprocess.run(
        [POWERSHELL, "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy",
         "Bypass", "-EncodedCommand", encoded], env=env, capture_output=True,
        text=True, errors="replace", timeout=30)


@unittest.skipUnless(os.name == "nt" and POWERSHELL, "Requires Windows PowerShell")
class MapProductionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="ops175_launcher_")
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.base = Path(cls.temporary.name)
        cls.launcher_source = LAUNCHER.read_bytes()
        print("Launcher SHA256: " + hashlib.sha256(cls.launcher_source).hexdigest(), flush=True)
        source = cls.base / "Fake.cs"
        source.write_text(r'''
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
public class Fake {
    public static int Main(string[] args) {
        string name = Path.GetFileNameWithoutExtension(Environment.GetCommandLineArgs()[0]);
        string directory = Environment.GetEnvironmentVariable("OPS175_LOG_DIR");
        var lines = new List<string>();
        foreach (string arg in args) lines.Add(Convert.ToBase64String(Encoding.UTF8.GetBytes(arg)));
        File.WriteAllLines(Path.Combine(directory, name + ".args"), lines.ToArray());
        int code;
        string key = name.Contains("blender") ? "OPS175_BLENDER_EXIT" : "OPS175_GODOT_EXIT";
        return Int32.TryParse(Environment.GetEnvironmentVariable(key), out code) ? code : 0;
    }
}
''', encoding="utf-8", newline="\n")
        cls.executable = cls.base / "fake.exe"
        result = powershell(
            "$ErrorActionPreference='Stop'; Add-Type -Path " + ps_literal(source)
            + " -OutputAssembly " + ps_literal(cls.executable)
            + " -OutputType ConsoleApplication")
        if result.returncode or not cls.executable.is_file():
            raise RuntimeError("Fake executable compilation failed: " + result.stdout + result.stderr)

    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="case ", dir=self.base)
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "clean project with spaces"
        self.launcher = self.repo / "tools" / "map_production.ps1"
        self.launcher.parent.mkdir(parents=True)
        self.launcher.write_bytes(self.launcher_source)
        self.profile = self.root / "fake user profile"
        configuration = self.profile / ".codex" / "tools" / "map-production"
        configuration.mkdir(parents=True)
        self.logs = self.root / "logs"
        self.logs.mkdir()
        binaries = self.root / "fake binaries with spaces"
        binaries.mkdir()
        for name in ("blender.exe", "godot_console.exe", "godot.exe"):
            shutil.copyfile(self.executable, binaries / name)
        self.workshop = self.root / "workshop with spaces"
        self.workshop.mkdir()
        space_kit = self.root / "space kit"
        space_kit.mkdir()
        config = {"blender": str(binaries / "blender.exe"),
                  "godot": str(binaries / "godot_console.exe"),
                  "workshop": str(self.workshop), "space_kit": str(space_kit),
                  "renderer": "forward_plus", "versions": {"proton_scatter": "fake",
                  "terrain3d": "fake", "blender": "fake", "space_kit": "fake"}}
        (configuration / "toolchain.json").write_text(json.dumps(config), encoding="utf-8")
        self.env = os.environ.copy()
        self.env.update(USERPROFILE=str(self.profile), OPS175_LOG_DIR=str(self.logs),
                        OPS175_BLENDER_EXIT="0", OPS175_GODOT_EXIT="0")

    def launch(self, tool, background=True, args=()):
        command = "& " + ps_literal(self.launcher) + " -Tool " + ps_literal(tool)
        if background:
            command += " -Background"
        if args:
            command += " -ToolArgs @(" + ",".join(map(ps_literal, args)) + ")"
        # Deliberately no exit $LASTEXITCODE: test the script's own success/failure contract.
        result = powershell(command, self.env)
        print(f"{self.id().split('.')[-1]}: launcher exit={result.returncode}", flush=True)
        return result

    def recorded(self, name):
        path = self.logs / (name + ".args")
        deadline = time.monotonic() + 5
        while not path.exists() and time.monotonic() < deadline:
            time.sleep(0.025)
        self.assertTrue(path.exists(), "Fake executable was not invoked: " + name)
        return [base64.b64decode(line).decode("utf-8")
                for line in path.read_text(encoding="utf-8-sig").splitlines()]

    def assert_failed(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_validate_rejects_blender_native_failure(self):
        self.env["OPS175_BLENDER_EXIT"] = "23"
        result = self.launch("Validate")
        self.assertIn("--version", self.recorded("blender"))
        self.assert_failed(result)

    def test_validate_rejects_godot_native_failure(self):
        self.env["OPS175_GODOT_EXIT"] = "24"
        result = self.launch("Validate")
        self.assertIn("--version", self.recorded("godot_console"))
        self.assert_failed(result)

    def test_workshop_background_rejects_native_failure(self):
        self.env["OPS175_GODOT_EXIT"] = "25"
        result = self.launch("Workshop")
        self.assertIn("--headless", self.recorded("godot_console"))
        self.assert_failed(result)

    def test_game_background_rejects_native_failure(self):
        self.env["OPS175_GODOT_EXIT"] = "26"
        result = self.launch("Game")
        self.assertIn("--headless", self.recorded("godot_console"))
        self.assert_failed(result)

    def test_game_default_opens_clean_project_without_lua_dependency(self):
        result = self.launch("Game")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        args = self.recorded("godot_console")
        self.assertIn(str(self.repo), args)
        self.assertIn("--editor", args)
        self.assertFalse(any("map_lua" in arg for arg in args), args)

    def test_blender_background_native_failure_is_control(self):
        self.env["OPS175_BLENDER_EXIT"] = "27"
        self.assert_failed(self.launch("Blender"))
        self.assertIn("--background", self.recorded("blender"))

    def test_validate_success_is_control(self):
        result = self.launch("Validate")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("--version", self.recorded("blender"))
        self.assertIn("--version", self.recorded("godot_console"))

    def test_workshop_gui_preserves_path_and_toolargs_with_spaces(self):
        extra = ("--custom-option", "value with spaces", "embedded\"quote")
        result = self.launch("Workshop", background=False, args=extra)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        actual = self.recorded("godot")
        self.assertEqual(actual, ["--path", str(self.workshop), "--rendering-method",
                                  "forward_plus", "--editor", *extra])

    def test_blender_gui_preserves_toolargs_with_spaces(self):
        extra = (str(self.root / "model with spaces.blend"), "--python-expr", "print('a b')")
        result = self.launch("Blender", background=False, args=extra)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.recorded("blender"), list(extra))


if __name__ == "__main__":
    unittest.main(verbosity=2)
