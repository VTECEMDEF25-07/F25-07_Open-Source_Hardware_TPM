"""Software-only width/capability/framing checks; never accesses hardware."""
import contextlib
import io
import struct
import unittest

import de25_crypto_demo as demo


def reply(opcode, width, result=b"", mode=1):
    payload=struct.pack(">BBBBIIHHIII",1,opcode,mode,0,42,0,1024,
                        2 if mode==1 else 0,0,0,width)+result
    return struct.pack(">HII",0x8001,10+len(payload),0)+payload


class WidthTests(unittest.TestCase):
    def test_default_remains_strict_2048(self):
        self.assertEqual(demo.parse_control(reply(0,2048),0)["width"],2048)
        for width in (1024,256):
            with self.assertRaises(AssertionError):
                demo.parse_control(reply(0,width),0)

    def test_explicit_approved_widths_and_exact_results(self):
        # Public RSA textbook fixture: 65**17 mod3233 ==2790, padded without truncation.
        self.assertEqual(pow(65,17,3233),2790)
        for width in (256,1024,2048):
            with self.subTest(width=width):
                b=width//8
                caps=demo.parse_control(reply(0,width),0,width)
                self.assertEqual(caps["width"],width)
                result=(2790).to_bytes(b,"big")
                parsed=demo.parse_control(reply(3,width,result),3,width)
                self.assertEqual(len(parsed["result"]),b)
                self.assertEqual(int.from_bytes(parsed["result"],"big"),2790)
                self.assertEqual(len(reply(3,width,result)),38+b)

    def test_layout_uses_actual_width(self):
        for width in (256,1024,2048):
            b=width//8
            base=(1<<(width-1))+65
            operands=b"".join(n.to_bytes(b,"big") for n in (base,17,3233))
            command=demo.control(3,42,operands=operands)
            self.assertEqual(len(command),26+3*b)
            self.assertEqual(struct.unpack(">HII",command[:10]),(0x8001,26+3*b,0x20000100))
            self.assertEqual(struct.unpack(">BBHIII",command[10:26]),(1,3,0,42,0,0))
            for i,n in enumerate((base,17,3233)):
                self.assertEqual(int.from_bytes(command[26+i*b:26+(i+1)*b],"big"),n)

    def test_capability_and_result_mismatch_never_fallback(self):
        for actual,expected in ((1024,2048),(2048,1024),(256,1024)):
            with self.subTest(actual=actual,expected=expected):
                with self.assertRaises(AssertionError):
                    demo.parse_control(reply(0,actual),0,expected)
                with self.assertRaises(AssertionError):
                    demo.parse_control(reply(3,actual,bytes(actual//8)),3,expected)
        with self.assertRaises(ValueError):
            demo.parse_control(reply(0,512),0,512)

    def test_exact_result_lengths_required(self):
        for width in (256,1024,2048):
            for delta in (-1,1):
                with self.subTest(width=width,delta=delta), self.assertRaises(AssertionError):
                    demo.parse_control(reply(3,width,bytes(width//8+delta)),3,width)

    def test_mode_and_aes_capacity_unchanged(self):
        test=demo.parse_control(reply(0,1024),0,1024)
        fresh=demo.parse_control(reply(0,1024,mode=0),0,1024)
        self.assertEqual((test["mode"],test["flags"]),(1,2))
        self.assertEqual((fresh["mode"],fresh["flags"]),(0,0))
        self.assertEqual(test["capacity"],1024)
        self.assertEqual(len(demo.aes_packet(1,bytes(1024),bytes(16))),1074)
        with self.assertRaises(ValueError):
            demo.aes_packet(1,bytes(1025),bytes(16))

    def test_run_rejects_unexpected_capability_before_generation(self):
        class Transport:
            def __init__(self): self.calls=[]
            def transact(self,command,timeout_s):
                self.calls.append(command)
                return struct.pack(">HII",0x8001,10,0) if len(self.calls)==1 else reply(0,1024)
        transport=Transport()
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(AssertionError):
            demo.run_demo(transport,b"message")
        self.assertEqual(len(transport.calls),2)

    def test_explicit_1024_host_flow_and_visible_claim(self):
        class Transport:
            live=False
            widths=[]
            def transact(self,command,timeout_s):
                tag,_,code=struct.unpack(">HII",command[:10])
                p=command[10:]
                def framed(payload=b"",tag=0x8001,rc=0):
                    return struct.pack(">HII",tag,10+len(payload),rc)+payload
                if code==0x144: return framed()
                if code==0x20000100:
                    _,op,_,ident,handle,_=struct.unpack(">BBHIII",p[:16])
                    result=b""
                    if op==1: self.live=True; handle=0x80000001
                    if op==2: self.live=False
                    if op==3:
                        self.widths.append(len(p[16:])*8//3)
                        b=128
                        base,e,n=(int.from_bytes(p[16+i*b:16+(i+1)*b],"big") for i in range(3))
                        result=pow(base,e,n).to_bytes(b,"big")
                    payload=struct.pack(">BBBBIIHHIII",1,op,1,0,ident,handle,1024,
                                        3 if op==1 else 2,0,0,1024 if op in (0,3) else 0)+result
                    return framed(payload)
                if code==0x193:
                    if not self.live: return framed(rc=0x18b)
                    # Empty-message AES response: unchanged IV; no hardware model claim.
                    return framed(struct.pack(">IH",20,0)+b"\0\x10"+bytes(range(16))+b"\0\0\1\0\0",0x8002)
                if code==0x17D:
                    return framed(bytes.fromhex("0020e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b8558024400000070000"))
                raise AssertionError(f"Unexpected command {code:#x}")
        transport=Transport(); output=io.StringIO()
        with contextlib.redirect_stdout(output):
            evidence=demo.run_demo(transport,b"",repeat=1,expected_modexp_width=1024)
        self.assertEqual(transport.widths,[1024])
        self.assertTrue(evidence)
        self.assertIn("1024-bit public MODEXP/Python pow PASS",output.getvalue())
        self.assertIn("no 2048-bit hardware claim",output.getvalue())
        self.assertNotIn("2048-bit public MODEXP/Python pow PASS",output.getvalue())


if __name__=="__main__":
    unittest.main()
