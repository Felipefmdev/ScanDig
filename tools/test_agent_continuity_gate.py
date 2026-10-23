"""Exercise the real gate against isolated checkpoints, never the live schedule."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


class ContinuityGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        spec = importlib.util.spec_from_file_location(
            'isolated_gate', Path(__file__).with_name('agent_continuity_gate.py'))
        self.gate = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.gate)
        self.gate.ROOT = Path(self.temp.name)
        self.gate.STATE = self.gate.ROOT / '.bot_runs' / 'state.json'
        self.gate.WATCH = ['checkpoint.json', 'other.log']

    def run_gate(self):
        output = io.StringIO()
        errors = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
            code = self.gate.main()
        return code, output.getvalue(), errors.getvalue()

    def test_change_emits_once_and_unchanged_skips_without_rewriting(self):
        checkpoint = self.gate.ROOT / 'checkpoint.json'
        checkpoint.write_text('first', encoding='utf-8')
        code, output, _ = self.run_gate()
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(output)['changed_checkpoints'], ['checkpoint.json'])
        before = self.gate.STATE.stat().st_mtime_ns
        self.assertEqual(self.run_gate()[:2], (1, ''))
        self.assertEqual(self.gate.STATE.stat().st_mtime_ns, before)
        checkpoint.write_text('second', encoding='utf-8')
        self.assertEqual(self.run_gate()[0], 0)

    def test_removed_last_checkpoint_emits_once_then_skips(self):
        checkpoint = self.gate.ROOT / 'checkpoint.json'
        checkpoint.write_text('evidence', encoding='utf-8')
        self.assertEqual(self.run_gate()[0], 0)
        checkpoint.unlink()
        code, output, _ = self.run_gate()
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(output)['changed_checkpoints'], ['checkpoint.json'])
        self.assertEqual(json.loads(output)['removed_checkpoints'], ['checkpoint.json'])
        self.assertEqual(self.run_gate()[:2], (1, ''))

    def test_no_checkpoints_does_not_create_state_or_emit_work(self):
        self.assertEqual(self.run_gate()[:2], (1, ''))
        self.assertFalse(self.gate.STATE.exists())

    def test_invalid_state_fails_closed_and_preserves_original(self):
        (self.gate.ROOT / 'checkpoint.json').write_text('evidence', encoding='utf-8')
        self.gate.STATE.parent.mkdir()
        for invalid in ('{broken', 'null', '[]', '"text"', '1', '{"checkpoint.json": 42}'):
            with self.subTest(state=invalid):
                self.gate.STATE.write_text(invalid, encoding='utf-8')
                code, output, errors = self.run_gate()
                self.assertEqual(code, 2)
                self.assertEqual(output, '')
                self.assertTrue(errors)
                self.assertEqual(self.gate.STATE.read_text(encoding='utf-8'), invalid)

    def test_mixed_removal_and_edit_are_both_reported(self):
        first = self.gate.ROOT / 'checkpoint.json'
        other = self.gate.ROOT / 'other.log'
        first.write_text('first', encoding='utf-8')
        other.write_text('old', encoding='utf-8')
        self.run_gate()
        first.unlink()
        other.write_text('new', encoding='utf-8')
        code, output, _ = self.run_gate()
        self.assertEqual(code, 0)
        self.assertEqual(set(json.loads(output)['changed_checkpoints']),
                         {'checkpoint.json', 'other.log'})
        self.assertEqual(json.loads(output)['removed_checkpoints'], ['checkpoint.json'])
        self.assertEqual(self.run_gate()[0], 1)

    def test_stdout_failure_does_not_consume_checkpoint(self):
        (self.gate.ROOT / 'checkpoint.json').write_text('evidence', encoding='utf-8')
        class ClosedOutput(io.StringIO):
            def write(self, value):
                raise BrokenPipeError('consumer closed')
        with contextlib.redirect_stdout(ClosedOutput()):
            with self.assertRaises(BrokenPipeError):
                self.gate.main()
        self.assertFalse(self.gate.STATE.exists())
        self.assertEqual(self.run_gate()[0], 0)

    def test_failed_replace_preserves_baseline_and_can_retry(self):
        checkpoint = self.gate.ROOT / 'checkpoint.json'
        checkpoint.write_text('old', encoding='utf-8')
        self.run_gate()
        before = self.gate.STATE.read_bytes()
        checkpoint.write_text('new', encoding='utf-8')
        # Only the final OS rename fails; real hashing/temp write/flush still execute.
        with patch.object(self.gate.os, 'replace', side_effect=OSError('disk failure')):
            with self.assertRaises(OSError):
                self.run_gate()
        self.assertEqual(self.gate.STATE.read_bytes(), before)
        self.assertEqual(list(self.gate.STATE.parent.iterdir()), [self.gate.STATE])
        self.assertEqual(self.run_gate()[0], 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
