"""Offline tests: decoded actual snapshot -> text -> captured LCD DDRAM writes.

No HPS, SPI, GPIO, FPGA or camera is accessed. A passing capture is not glass QA.
"""
import importlib.util
from pathlib import Path
import unittest
from unittest import mock
from types import SimpleNamespace

spec=importlib.util.spec_from_file_location('de25_lcd',Path(__file__).with_name('de25_lcd.py'))
lcd=importlib.util.module_from_spec(spec); spec.loader.exec_module(lcd)


def snapshot(code=0,mode=0,detail=0,op=42,seq=1,valid=True):
    return {'status_word':0x01000000 | detail<<16 | int(valid)<<7 | int(code>=9)<<6 | mode<<4 | code,
            'operation_id':op,'sequence':seq}


class Capture:
    def __init__(self):
        self.events=[]; self.ram=[bytearray([0xaa]*132) for _ in range(8)]
        self.page=self.column=0; self.on=False
    def reset(self,high): self.events.append(('reset',high))
    def backlight(self,high): self.events.append(('backlight',high))
    def write(self,dc,data):
        self.events.append(('write',dc,bytes(data)))
        for b in data:
            if dc:
                assert 0<=self.page<8 and 0<=self.column<132
                self.ram[self.page][self.column]=b
                self.column=(self.column+1)%132
            elif b==0xae: self.on=False
            elif b==0xaf:
                # Display is never enabled with undefined DDRAM.
                assert all(not any(page) for page in self.ram)
                self.on=True
            elif 0xb0<=b<=0xb7: self.page=b&7
            elif b<0x10: self.column=(self.column&0xf0)|b
            elif 0x10<=b<=0x1f: self.column=(b&15)*16+(self.column&15)


class Tests(unittest.TestCase):
    def test_all_hardware_states_and_modes(self):
        frames=set()
        for code in range(16):
            for mode in range(4):
                rec=lcd.decode_snapshot(snapshot(code,mode,255,0x12345678,0xffffffff))
                lines=lcd.status_lines(rec)
                self.assertIn(lcd.MODES[mode],lines)
                self.assertIn(lcd.STATES[code] if code<10 else 'UNKNOWN HW STATE',lines)
                self.assertIn('OP 12345678',lines)
                frame=lcd.render(lines)
                self.assertEqual(len(frame),1024)
                self.assertTrue(any(frame)); frames.add(frame)
        self.assertGreaterEqual(len(frames),40)

    def test_exact_font_pixel_orientation(self):
        # Independent known letter A: each column is one page byte, bit0 at top.
        self.assertEqual(lcd.render(['A'])[:6],bytes((0x7e,0x09,0x09,0x09,0x7e,0)))
        self.assertEqual(lcd.render(['','A'])[128:134],bytes((0x7e,9,9,9,0x7e,0)))
        self.assertEqual(lcd.render([' ']),bytes(1024))

    def test_reset_stale_error_text(self):
        self.assertNotIn('READY',lcd.status_lines(lcd.decode_snapshot(snapshot(valid=False))))
        self.assertIn('WAIT HW STATUS',lcd.status_lines())
        lines=lcd.status_lines(lcd.decode_snapshot(snapshot(8)),stale=True)
        self.assertIn('STATUS STALE',lines); self.assertNotIn('DONE',lines)
        self.assertIn('INVALID HW SNAPSHOT',lcd.status_lines(invalid=True))

    def test_invalid_input_rejected(self):
        invalid=[{},dict(snapshot(),message='pretend done'),snapshot(-1),snapshot(op=-1),
                 snapshot(seq=2**32),dict(snapshot(),sequence=True),snapshot(valid=False,code=9)]
        # Valid=false error is a representable retained snapshot; it is not ready.
        invalid=invalid[:-1]
        for r in invalid:
            with self.subTest(r=r),self.assertRaises(ValueError): lcd.decode_snapshot(r)
        for word in (0x02000080,0x01000180,0x010000c0,0x01000089):
            with self.assertRaises(ValueError): lcd.decode_snapshot(dict(snapshot(),status_word=word))

    def test_bounds(self):
        for lines in (['A'*22],['']*9):
            with self.assertRaises(ValueError): lcd.render(lines)
        cap=Capture(); driver=lcd.ST7567(cap,sleep=lambda _:None)
        for frame in (b'',bytes(1023),bytes(1025)):
            with self.assertRaises(ValueError): driver.display(frame)
        self.assertEqual(cap.events,[])

    def test_vendor_init_and_serial_capture(self):
        cap=Capture(); sleeps=[]; driver=lcd.ST7567(cap,sleep=sleeps.append)
        driver.initialize()
        self.assertEqual(sleeps,[0.0625,0.0625,0.02])
        self.assertEqual(cap.events[:4],[('backlight',False),('reset',False),('reset',True),
                                       ('write',False,bytes((0xae,0xc8,0x2f,0x40)))])
        self.assertTrue(cap.on)
        self.assertTrue(all(not any(page) for page in cap.ram))
        for code in range(10):
            frame=lcd.render(lcd.status_lines(lcd.decode_snapshot(snapshot(code))))
            before=len(cap.events); driver.display(frame)
            self.assertEqual(len(cap.events)-before,16)
            for page in range(8):
                self.assertEqual(cap.ram[page][:128],frame[page*128:(page+1)*128])
                self.assertEqual(cap.ram[page][128:],bytes(4))
                self.assertEqual(cap.events[before+page*2],('write',False,bytes((0xb0|page,0,0x10))))

    def test_no_host_strings_accepted(self):
        for rec in ('DONE',{'state':'AES decrypt'},{'status_word':'01000080','operation_id':1,'sequence':1}):
            with self.assertRaises(ValueError): lcd.decode_snapshot(rec)

    def test_linux_transport_abi_and_partial_write(self):
        calls=[]
        def ioctl(fd,code,arg):
            if code==0xc16cb403:
                self.assertEqual(fd,31)
                self.assertEqual(list(arg.offsets)[:3],[10,11,18])
                self.assertEqual((arg.flags,arg.lines),(2,3))
                self.assertEqual(list(arg.defaults)[:3],[1,0,0])
                arg.fd=33
            else: calls.append((fd,code,bytes(arg)))
        with mock.patch.dict('sys.modules',{'fcntl':SimpleNamespace(ioctl=ioctl)}), \
             mock.patch.object(lcd.os,'O_CLOEXEC',0x80000,create=True), \
             mock.patch.object(lcd.os,'open',side_effect=[31,32]), \
             mock.patch.object(lcd.os,'close') as close, \
             mock.patch.object(lcd.os,'write',return_value=2) as write:
            backend=lcd.LinuxLCD()
            self.assertEqual([c[1] for c in calls],[0x40016b01,0x40016b02,0x40016b03,0x40046b04])
            backend.reset(False); backend.backlight(True); backend.write(True,b'AB')
            self.assertEqual(calls[-1][0:2],(33,0xc040b409))
            self.assertEqual(calls[-1][2][:3],bytes((0,1,1)))
            write.assert_called_with(32,b'AB')
            write.return_value=1
            with self.assertRaises(OSError): backend.write(True,b'AB')
            backend.close()
            self.assertEqual([c.args[0] for c in close.call_args_list],[31,32,33])

    def test_linux_transport_failure_closes_gpio(self):
        def ioctl(fd,code,arg):
            if code==0xc16cb403: arg.fd=33
        with mock.patch.dict('sys.modules',{'fcntl':SimpleNamespace(ioctl=ioctl)}), \
             mock.patch.object(lcd.os,'O_CLOEXEC',0x80000,create=True), \
             mock.patch.object(lcd.os,'open',side_effect=[31,OSError('no HPS SPI')]), \
             mock.patch.object(lcd.os,'close') as close:
            with self.assertRaises(OSError): lcd.LinuxLCD()
            self.assertEqual([c.args[0] for c in close.call_args_list],[31,33])


if __name__=='__main__': unittest.main(verbosity=2)
