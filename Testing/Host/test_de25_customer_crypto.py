"""Software-only encryption/encoding/recording checks; not FPGA acceptance."""
from pathlib import Path
import contextlib,io,json,unittest
import de25_customer_crypto as crypto
from de25_customer_console import PublicRecorder,show_bytes


class CryptoTests(unittest.TestCase):
    def test_aes_independent_fixed_known_answer(self):
        key=bytes.fromhex('603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4')
        iv=bytes(range(16)); pt=bytes.fromhex('6bc1bee22e409f96e93d7e117393172a')
        ct=crypto.aes_encrypt_on_laptop(key,iv,pt)
        self.assertEqual(ct.hex(),'dc7e84bfda79164b7ecd8486985d3860')
        self.assertEqual(crypto.expected_cfb_final_iv(ct,iv),ct)

    def test_aes_bounds_and_partial_iv_contract(self):
        for n in (0,1,15,16,17,1024):
            ct=crypto.aes_encrypt_on_laptop(bytes(32),bytes(16),bytes(n))
            self.assertEqual(len(ct),n)
            expected=bytes(16) if not n else ct[-(n%16 or 16):]+bytes(16-(n%16 or 16))
            self.assertEqual(crypto.expected_cfb_final_iv(ct,bytes(16)),expected)
        for key,iv,pt in ((bytes(16),bytes(16),b'x'),(bytes(32),bytes(15),b'x'),(bytes(32),bytes(16),bytes(1025))):
            with self.assertRaises(ValueError): crypto.aes_encrypt_on_laptop(key,iv,pt)

    def test_rsa_encoding_zero_exact_length_and_unicode(self):
        for message in (b'',b'a\0b','FPGA decrypts café'.encode(),bytes(range(240))):
            frame=crypto.encode_rsa_demo_message(message)
            self.assertEqual(len(frame),256); self.assertEqual(frame[:5],b'\0DE25')
            self.assertEqual(int.from_bytes(frame[5:7],'big'),len(message))
            self.assertEqual(crypto.validate_rsa_demo_frame(frame),message)
        with self.assertRaises(ValueError): crypto.encode_rsa_demo_message(bytes(241))
        with self.assertRaises(ValueError): crypto.utf8_message('é'*121,240)

    def test_rsa_malformed_frames_rejected(self):
        frame=crypto.encode_rsa_demo_message(b'hello')
        bad=[frame[:-1],b'X'+frame[1:],frame[:5]+(241).to_bytes(2,'big')+frame[7:],frame[:-1]+b'X']
        for b in bad:
            with self.assertRaises(ValueError): crypto.validate_rsa_demo_frame(b)

    def test_public_encryption_against_existing_keygen_fixture(self):
        repo=Path(__file__).resolve().parents[2]
        fixtures=json.loads((repo/'Testing/Simulation/Key Generation/reference/expected_keys.json').read_text(encoding='utf-8'))
        self.assertTrue(fixtures['test_only'])
        key=fixtures['results'][0]['key']; n=int(key['n'],0); e=int(key['e'],0); d=int(key['d'],0)
        public=crypto.FpgaRsaPublicKey.from_fpga(n.to_bytes(256,'big'),e.to_bytes(4,'big'))
        for msg in (b'',b'Actual FPGA private operation is required in the customer run.',bytes(240)):
            c=public.encrypt_on_laptop(msg); self.assertEqual(len(c),256)
            # Test fixture private computation exists only here, never in the customer client.
            decoded=pow(int.from_bytes(c,'big'),d,n).to_bytes(256,'big')
            self.assertEqual(crypto.validate_rsa_demo_frame(decoded),msg)

    def test_wrong_width_or_exponent_never_silently_accepted(self):
        for n,e in ((bytes(128),bytes.fromhex('00010001')),(bytes(256),bytes.fromhex('00010001')),
                    ((2**2047+1).to_bytes(256,'big'),bytes.fromhex('00000003'))):
            with self.assertRaises(ValueError): crypto.FpgaRsaPublicKey.from_fpga(n,e)

    def test_no_private_fields_or_fake_status_in_public_record(self):
        log=PublicRecorder()
        with contextlib.redirect_stdout(io.StringIO()):
            log.actual_status(7,42,0,0)
        self.assertEqual(log.events[0]['hardware_state'],7)
        self.assertIn('not a display-glass observation',log.events[0]['source'])
        with self.assertRaises(ValueError): log.emit('leak','bad',aes_key='x')
        with self.assertRaises(ValueError): log.actual_status(12,42,0,0)
        self.assertEqual(show_bytes(b'hello\nFPGA'),'"hello\\nFPGA"')


if __name__=='__main__': unittest.main()
