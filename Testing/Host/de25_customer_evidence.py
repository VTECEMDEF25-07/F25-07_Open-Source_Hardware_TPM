"""Gate customer flow on actual, same-image, complete original Phase I evidence."""
from pathlib import Path
import json,re

PHASE1_SUITES=('test_debugRW','test_localityChanging','test_localityPermissions',
               'test_statusStateMachine','test_localitySeizeCommandAbort',
               'test_hierarchyControl','test_hierarchyControl2','test_ccQuote')


def validate_phase1(record: dict,expected_sof_sha256: str) -> dict:
    if not re.fullmatch('[0-9a-f]{64}',expected_sof_sha256):
        raise ValueError('Expected a complete lowercase final-image SOF SHA256')
    if record.get('hardware') is not True or record.get('status')!='PASS':
        raise ValueError('Actual passing hardware Phase I evidence is required')
    if record.get('sof_sha256')!=expected_sof_sha256:
        raise ValueError('Phase I evidence is for a different FPGA image')
    if record.get('assertions_unchanged') is not True:
        raise ValueError('Original Phase I assertions must be unchanged')
    if not re.fullmatch('[0-9a-f]{40}',record.get('source_commit','')):
        raise ValueError('Phase I record lacks exact source revision')
    suites=record.get('suites',[])
    if len(suites)!=len(PHASE1_SUITES) or {s.get('name') for s in suites}!=set(PHASE1_SUITES):
        raise ValueError('All eight original enabled suites must appear exactly once')
    for suite in suites:
        if suite.get('status')!='PASS' or suite.get('completed') is not True:
            raise ValueError(f'Incomplete or failed Phase I suite: {suite.get("name")}')
        if type(suite.get('errors')) is not int or suite['errors']!=0:
            raise ValueError(f'Phase I assertion errors: {suite.get("name")}')
        if type(suite.get('assertions')) is not int or suite['assertions']<0:
            raise ValueError('Phase I record must contain actual per-suite assertion counts')
    ordered={s['name']:s for s in suites}
    return dict(record,suites=[ordered[n] for n in PHASE1_SUITES])


def load_phase1(path: Path,expected_sof_sha256: str) -> dict:
    return validate_phase1(json.loads(path.read_text(encoding='utf-8-sig')),expected_sof_sha256)


def display_phase1(record: dict,recorder):
    recorder.emit('phase1-start','PHASE I — ORIGINAL HARDWARE TESTS',source_commit=record['source_commit'],
                  sof_sha256=record['sof_sha256'],hardware=True)
    for s in record['suites']:
        recorder.emit('phase1-suite',f'PASS  {s["name"]}  ({s["assertions"]} assertions, 0 errors)',
                      name=s['name'],assertions=s['assertions'],errors=0,completed=True)
    recorder.emit('phase1-pass','PHASE I: 8 / 8 ORIGINAL SUITES PASS',passed=8,total=8)
