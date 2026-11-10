"""Bounded actual-status relay unit checks; no subprocess/HPS/hardware is opened."""
import json,queue,unittest
from unittest.mock import Mock
from de25_customer_lcd_relay import Relay


def relay():
    r=object.__new__(Relay); r.error=None; r.process=Mock(); r.process.poll.return_value=None
    r.pending=queue.Queue(maxsize=1)
    return r


class RelayTests(unittest.TestCase):
    def test_exact_snapshot_forwarded_without_state_invention(self):
        r=relay(); a=dict(status_word=0x01000084,operation_id=42,sequence=8)
        r(a); self.assertEqual(json.loads(r.pending.get_nowait()),a)

    def test_backpressure_keeps_only_latest_actual_snapshot(self):
        r=relay(); r(dict(status_word=0x01000084,operation_id=42,sequence=8))
        latest=dict(status_word=0x01000088,operation_id=42,sequence=9); r(latest)
        self.assertEqual(r.pending.qsize(),1); self.assertEqual(json.loads(r.pending.get_nowait()),latest)

    def test_extra_or_non_uint_fields_rejected(self):
        for a in (dict(status_word=0,operation_id=0,sequence=0,assumed_state=7),
                  dict(status_word=True,operation_id=0,sequence=0),
                  dict(status_word=0,operation_id=-1,sequence=0)):
            with self.assertRaises(ValueError): relay()(a)

    def test_unavailable_child_is_not_silent_success(self):
        r=relay(); r.error=BrokenPipeError('closed')
        with self.assertRaises(RuntimeError): r(dict(status_word=0,operation_id=0,sequence=0))


if __name__=='__main__': unittest.main()
