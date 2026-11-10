"""Software-only gate tests. Fixtures here never claim real board acceptance."""
import unittest
from de25_customer_evidence import PHASE1_SUITES,validate_phase1


def fixture():
    return dict(hardware=True,status='PASS',assertions_unchanged=True,sof_sha256='a'*64,
                source_commit='b'*40,suite_count=8,assertion_count=28,failure_count=0,completion_marker=True,
                core_hz=50000000,spi_hz=100000,log_path='actual-hardware.log',started_utc='2026-11-10T05:55:00Z',
                ended_utc='2026-11-10T05:55:01Z',
                suites=[dict(name=n,completed=True,failures=0,assertion_calls=i)
                for i,n in enumerate(PHASE1_SUITES)])


class EvidenceTests(unittest.TestCase):
    def test_exact_eight_same_image_required(self):
        f=fixture(); result=validate_phase1(f,'a'*64)
        self.assertEqual(tuple(s['name'] for s in result['suites']),PHASE1_SUITES)
        with self.assertRaises(ValueError): validate_phase1(f,'c'*64)

    def test_missing_duplicate_or_extra_suite_rejected(self):
        for suites in (fixture()['suites'][:-1],fixture()['suites'][:-1]+[fixture()['suites'][0]],
                       fixture()['suites']+[dict(name='extra')]):
            f=fixture(); f['suites']=suites
            with self.assertRaises(ValueError): validate_phase1(f,'a'*64)

    def test_failure_incomplete_or_missing_counts_rejected(self):
        for field,value in (('failures',1),('failures',False),('completed',False),('status','FAIL'),('assertion_calls',None)):
            f=fixture(); f['suites'][4][field]=value
            with self.assertRaises(ValueError): validate_phase1(f,'a'*64)

    def test_simulation_or_changed_assertions_never_promoted(self):
        for field,value in (('hardware',False),('status','FAIL'),('assertions_unchanged',False),('source_commit','unknown')):
            f=fixture(); f[field]=value
            with self.assertRaises(ValueError): validate_phase1(f,'a'*64)


if __name__=='__main__': unittest.main()
