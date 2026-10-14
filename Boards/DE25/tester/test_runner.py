"""Runner-only tests with a mocked child process: never open USB."""
import contextlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent

class RunnerTests(unittest.TestCase):
    def execute(self, hardware=False, log=b'', code=0, timeout=False):
        with tempfile.TemporaryDirectory(dir=HERE.parents[4]/'AI/tmp') as temporary:
            root = Path(temporary)
            exe = root/'mock.bin'
            exe.write_bytes(b'test fixture; never executed')
            output = root/'output'
            argv = ['run_original.py','--exe',str(exe),'--output',str(output)]
            if hardware:
                argv.append('--hardware')
            def child(command, **options):
                self.assertEqual('--hardware' in command, hardware)
                if timeout:
                    raise subprocess.TimeoutExpired(command,180,output=log)
                (Path(options['cwd'])/'tb_original.v').write_text('// mock')
                return SimpleNamespace(stdout=log,returncode=code)
            with patch.object(sys,'argv',argv),patch('subprocess.run',child),contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(SystemExit) as stopped:
                    runpy.run_path(str(HERE/'run_original.py'),run_name='__main__')
            return stopped.exception.code,json.loads((output/'result.json').read_text())

    def test_offline_distinct_from_hardware(self):
        code,result=self.execute(log=b'OFFLINE: no USB')
        self.assertEqual(code,0)
        self.assertEqual(result['result'],'OFFLINE_GENERATED')

    def test_success_requires_all_original_suites(self):
        log=('There were no errors in testing. test_debugRW test_localityChanging '
             'test_localityPermissions test_statusStateMachine test_localitySeizeCommandAbort '
             'test_ccQuote test_hierarchyControl test_hierarchyControl').encode()
        self.assertEqual(self.execute(True,log)[1]['result'],'HARDWARE_PASS')
        self.assertEqual(self.execute(True,b'There were no errors in testing.')[0],1)

    def test_failure_return_cannot_pass(self):
        self.assertEqual(self.execute(log=b'OFFLINE:',code=1)[0],1)

    def test_timeout_is_failure(self):
        code,result=self.execute(timeout=True)
        self.assertEqual(code,1)
        self.assertTrue(result['timeout'])

    def test_out_of_contract_speed_is_rejected(self):
        with patch.object(sys,'argv',['run_original.py','--exe','unused','--output','unused','--hz','24000000']),contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as stopped:
                runpy.run_path(str(HERE/'run_original.py'),run_name='__main__')
        self.assertEqual(stopped.exception.code,2)

if __name__=='__main__':
    unittest.main()
