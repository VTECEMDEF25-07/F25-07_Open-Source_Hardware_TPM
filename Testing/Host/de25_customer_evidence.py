"""Gate customer flow on actual, same-image, complete original Phase I evidence."""
from pathlib import Path
import json,re

PHASE1_SUITES=('test_debugRW','test_localityChanging','test_localityPermissions',
               'test_statusStateMachine','test_localitySeizeCommandAbort',
               'test_hierarchyControl','test_hierarchyControl2','test_ccQuote')


def validate_phase1(record: dict,expected_sof_sha256: str) -> dict:
    if not re.fullmatch('[0-9a-f]{64}',expected_sof_sha256):
        raise ValueError('Expected a complete lowercase final-image SOF SHA256')
    if record.get('hardware',True) is not True or record.get('simulation',False) is True or record.get('status')!='PASS':
        raise ValueError('Actual passing hardware Phase I evidence is required')
    if record.get('sof_sha256')!=expected_sof_sha256:
        raise ValueError('Phase I evidence is for a different FPGA image')
    if record.get('assertions_unchanged') is not True:
        raise ValueError('Original Phase I assertions must be unchanged')
    if not re.fullmatch('[0-9a-f]{40}',record.get('source_commit','')):
        raise ValueError('Phase I record lacks exact source revision')
    suites=record.get('suites',[])
    if type(record.get('suite_count')) is not int or record['suite_count']!=8 or record.get('completion_marker') is not True or type(record.get('failure_count')) is not int or record['failure_count']!=0:
        raise ValueError('Phase I requires an explicit eight-suite completion marker and zero failures')
    if len(suites)!=len(PHASE1_SUITES) or {s.get('name') for s in suites}!=set(PHASE1_SUITES):
        raise ValueError('All eight original enabled suites must appear exactly once')
    for suite in suites:
        if suite.get('completed') is not True:
            raise ValueError(f'Incomplete or failed Phase I suite: {suite.get("name")}')
        if type(suite.get('failures')) is not int or suite['failures']!=0:
            raise ValueError(f'Phase I assertion errors: {suite.get("name")}')
        if type(suite.get('assertion_calls')) is not int or suite['assertion_calls']<0:
            raise ValueError('Phase I record must contain actual per-suite assertion counts')
        if ('status' in suite and suite['status']!='PASS') or ('errors' in suite and suite['errors']!=suite['failures']) or ('assertions' in suite and suite['assertions']!=suite['assertion_calls']):
            raise ValueError('Conflicting Phase I per-suite aliases')
    if type(record.get('assertion_count')) is not int or record['assertion_count']!=sum(s['assertion_calls'] for s in suites):
        raise ValueError('Phase I total assertion count does not match actual per-suite counts')
    if record.get('core_hz')!=50000000 or record.get('spi_hz') not in (100000,1000000):
        raise ValueError('Phase I clock/rate must identify the accepted 50 MHz hardware profile')
    if not all(record.get(k) for k in ('log_path','started_utc','ended_utc')):
        raise ValueError('Phase I record must retain log and actual run timestamps')
    ordered={s['name']:s for s in suites}
    return dict(record,suites=[ordered[n] for n in PHASE1_SUITES])


def load_phase1(path: Path,expected_sof_sha256: str) -> dict:
    return validate_phase1(json.loads(path.read_text(encoding='utf-8-sig')),expected_sof_sha256)


def display_phase1(record: dict,recorder):
    recorder.emit('phase1-start','PHASE I — ORIGINAL HARDWARE TESTS',source_commit=record['source_commit'],
                  sof_sha256=record['sof_sha256'],hardware=True)
    for s in record['suites']:
        recorder.emit('phase1-suite',f'PASS  {s["name"]}  ({s["assertion_calls"]} assertion calls, 0 failures)',
                      name=s['name'],assertion_calls=s['assertion_calls'],failures=0,completed=True)
    recorder.emit('phase1-pass','PHASE I: 8 / 8 ORIGINAL SUITES PASS',passed=8,total=8)
