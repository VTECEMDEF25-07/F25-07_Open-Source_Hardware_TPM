"""Software-only D2XX-wait/status tests. Driver/device is never opened."""
import struct,unittest
from unittest.mock import Mock
from de25_customer_transport import Transport
from de25_customer_protocol import ProtocolError


def bare_transport(responses):
    t=object.__new__(Transport)
    t.status_callback=Mock(); t.expected_provider=0; t.last_poll=0
    t._transfer=Mock(side_effect=responses)
    return t


class TransportTests(unittest.TestCase):
    def test_torn_snapshot_is_retried_without_fake_callback(self):
        word=0x01000084
        t=bare_transport([struct.pack('<IIII',1,word,42,2),struct.pack('<IIII',2,word,42,2)])
        value=t.poll_status(force=True)
        self.assertEqual(value['operation_id'],42)
        self.assertEqual(t._transfer.call_args_list[0].args,(True,0x0f80,16))
        self.assertEqual(t.status_callback.call_count,1)

    def test_no_valid_snapshot_never_invents_progress(self):
        t=bare_transport([bytes(16)]*5)
        self.assertIsNone(t.poll_status(force=True))
        t.status_callback.assert_not_called()

    def test_wrong_provider_is_rejected(self):
        t=bare_transport([struct.pack('<IIII',1,0x01000094,42,1)])
        with self.assertRaises(ProtocolError): t.poll_status(force=True)

    def test_command_wait_polls_actual_status_and_retains_reply(self):
        t=object.__new__(Transport)
        t._write_reg=Mock(); t._read_reg=Mock(side_effect=[0xa1,0x40,0x00,0x10])
        reply=bytes.fromhex('80010000000a00000000')
        t._transfer=Mock(side_effect=[b'',reply]); t.poll_status=Mock()
        result=t.transact(bytes.fromhex('80010000000c000001440000'))
        self.assertEqual(result,reply)
        self.assertEqual(t.poll_status.call_count,2)
        self.assertEqual(t.poll_status.call_args.kwargs,{'force':True})


if __name__=='__main__': unittest.main()
