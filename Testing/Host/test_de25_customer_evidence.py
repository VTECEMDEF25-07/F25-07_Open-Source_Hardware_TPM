"""Software-only gate tests. Fixtures here never claim real board acceptance."""
import copy,unittest
from de25_customer_evidence import PHASE1_SUITES,validate_phase1


def fixture():
    return dict(hardware=True,status='PASS',assertions_unchanged=True,sof_sha256='a'*64,
                source_commit='b'*40,suites=[dict(name=n,status='PASS',completed=True,errors=0,assertions=i)
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
        for field,value in (('errors',1),('errors',False),('completed',False),('status','FAIL'),('assertions',None)):
            f=fixture(); f['suites'][4][field]=value
            with self.assertRaises(ValueError): validate_phase1(f,'a'*64)

    def test_simulation_or_changed_assertions_never_promoted(self):
        for field,value in (('hardware',False),('status','FAIL'),('assertions_unchanged',False),('source_commit','unknown')):
            f=fixture(); f[field]=value
            with self.assertRaises(ValueError): validate_phase1(f,'a'*64)


if __name__=='__main__': unittest.main()
