"""DE25 test-image client. Only explicit CLI execution opens the named SPI adapter; never flashes."""
import argparse
import ctypes as c
import json
from pathlib import Path
import statistics
import sys
import time

SERIAL = "FTA6H280"
TIMEOUT = 180.0


class SpiAdapter:
    def __init__(self, frequency=1000000):
        if frequency not in (100000, 500000, 1000000):
            raise ValueError("supported SPI rates: 100k, 500k, 1MHz")
        self.dll = c.WinDLL("C:/Windows/System32/ftd2xx.dll")
        self.handle = c.c_void_p()
        self.u = c.c_uint32
        u, p, h = self.u, c.POINTER(self.u), c.c_void_p
        signatures = {
            "FT_CreateDeviceInfoList": [p], "FT_GetDeviceInfoDetail": [u,p,p,p,p,h,h,c.POINTER(h)],
            "FT_OpenEx": [h,u,c.POINTER(h)], "FT_Close": [h], "FT_ResetDevice": [h],
            "FT_SetTimeouts": [h,u,u], "FT_SetLatencyTimer": [h,c.c_ubyte],
            "FT_SetBitMode": [h,c.c_ubyte,c.c_ubyte], "FT_Purge": [h,u],
            "FT_Write": [h,h,u,p], "FT_Read": [h,h,u,p],
        }
        for name, signature in signatures.items():
            function = getattr(self.dll, name)
            function.argtypes, function.restype = signature, u
        count = u()
        self.ok(self.dll.FT_CreateDeviceInfoList(c.byref(count)), "enumerate")
        matches = []
        for index in range(count.value):
            flags, kind, identifier, location = u(),u(),u(),u()
            serial, description, handle = c.create_string_buffer(64),c.create_string_buffer(64),h()
            self.ok(self.dll.FT_GetDeviceInfoDetail(index,c.byref(flags),c.byref(kind),c.byref(identifier),c.byref(location),serial,description,c.byref(handle)), "device detail")
            if serial.value.decode() == SERIAL and kind.value == 8 and b"C232HM" in description.value:
                matches.append(description.value.decode())
        if len(matches) != 1:
            raise RuntimeError(f"exactly one C232HM adapter with serial {SERIAL} required")
        self.ok(self.dll.FT_OpenEx(c.cast(c.c_char_p(SERIAL.encode()),h),1,c.byref(self.handle)), "open named adapter")
        try:
            self.ok(self.dll.FT_ResetDevice(self.handle), "reset adapter")
            self.ok(self.dll.FT_SetTimeouts(self.handle,200,200), "timeouts")
            self.ok(self.dll.FT_SetLatencyTimer(self.handle,2), "latency")
            self.ok(self.dll.FT_SetBitMode(self.handle,0,0), "disable MPSSE")
            self.ok(self.dll.FT_SetBitMode(self.handle,0,2), "enable MPSSE")
            time.sleep(.1)
            self.ok(self.dll.FT_Purge(self.handle,3), "purge")
            self.write(bytes([0xAA,0x87]))
            if self.read(2) != b"\xfa\xaa":
                raise RuntimeError("MPSSE synchronization failed")
            divisor = 30000000 // frequency - 1
            self.write(bytes([0x8A,0x97,0x8D,0x85,0x86,divisor&255,divisor>>8]))
            self.pins(0x18)
        except Exception:
            self.close()
            raise

    @staticmethod
    def ok(status, action):
        if status:
            raise RuntimeError(f"{action}: FT_STATUS={status}")

    def write(self, payload):
        buffer, transferred = c.create_string_buffer(payload), self.u()
        self.ok(self.dll.FT_Write(self.handle,buffer,len(payload),c.byref(transferred)), "write")
        if transferred.value != len(payload):
            raise RuntimeError("short USB write")

    def read(self, length):
        result = bytearray()
        deadline = time.monotonic()+3
        while len(result) < length:
            if time.monotonic() > deadline:
                raise TimeoutError("USB response timeout")
            buffer, transferred = c.create_string_buffer(length-len(result)),self.u()
            self.ok(self.dll.FT_Read(self.handle,buffer,len(buffer),c.byref(transferred)), "read")
            result.extend(buffer.raw[:transferred.value])
        return bytes(result)

    def pins(self, value):
        self.write(bytes([0x80,value,0x1B]))

    def reset_board_core(self):
        self.pins(0x08);time.sleep(.02)
        self.pins(0x18);time.sleep(.02)

    def transfer(self, payload):
        if not 1 <= len(payload) <= 8:
            raise ValueError("frame must contain one through eight bytes")
        self.pins(0x10)
        try:
            self.write(bytes([0x31,len(payload)-1,0])+payload+bytes([0x87]))
            return self.read(len(payload))
        finally:
            self.pins(0x18)

    def register(self, address, data=None):
        payload = bytes([1 if data is None else 2,address,0,0])+(0 if data is None else data).to_bytes(4,"big")
        response = self.transfer(payload)
        if response[:4] != b"\xa5\x00\x00\x00":
            raise RuntimeError(f"SPI image/protocol mismatch: {response.hex()}")
        return int.from_bytes(response[4:],"big")

    def close(self):
        if self.handle.value:
            try:
                self.write(bytes([0x80,0,0]))
            finally:
                self.dll.FT_Close(self.handle)
                self.handle = c.c_void_p()

    def __enter__(self):
        return self

    def __exit__(self, exception_type, exception, traceback):
        try:
            self.close()
        except Exception as cleanup:
            if exception is None:
                raise
            errors=getattr(exception,"cleanup_errors",[])
            errors.append("adapter close: " + str(cleanup))
            exception.cleanup_errors=errors


def telemetry(adapter):
    temperatures = adapter.register(13)
    flags = adapter.register(15)
    def signed16(value):
        return value-65536 if value & 32768 else value
    return {"fpga_c":signed16(temperatures>>16),"board_c":signed16(temperatures&65535),
            "fan_rpm":adapter.register(14),"alarm":flags&255,
            "i2c_ready":bool(flags&256),"temperature_valid":bool(flags&512),"fan_fail_safe":bool(flags&1024)}


def poll(adapter, mask, samples=None, source_schedule=None, transitions=None):
    deadline = time.monotonic()+TIMEOUT
    started = deadline-TIMEOUT
    pending = list(source_schedule or [])
    next_sample = 0.0
    while time.monotonic() < deadline:
        status = adapter.register(3)
        while pending and time.monotonic()-started >= pending[0][0]:
            scheduled, hold = pending.pop(0)
            if not status & 2:
                raise RuntimeError("source-stall schedule reached outside busy generation")
            adapter.register(11,hold)
            transitions.append({"scheduled_seconds":scheduled,"observed_seconds":time.monotonic()-started,"hold_generation":bool(hold)})
        if samples is not None and time.monotonic() >= next_sample:
            samples.append(telemetry(adapter))
            next_sample = time.monotonic()+1
        if status & mask:
            if pending:
                raise RuntimeError("generation completed before source-stall replay schedule finished")
            return status
        time.sleep(.01)
    raise TimeoutError(f"core did not reach status mask {mask:#x} within {TIMEOUT}s")


def identify(adapter, manifest=None):
    if adapter.register(0) != 0x4B473031:
        raise RuntimeError("unexpected build identity")
    config = adapter.register(1)
    if not config & 4 or config & ~7:
        raise RuntimeError("explicit test-image configuration required")
    control = "softcore" if config&1 else "rtl"
    backend = "altera" if config&2 else "generic"
    fingerprint = "".join(f"{adapter.register(address):08x}" for address in range(24,32))
    if manifest is not None:
        expected = manifest.get("build_fingerprint", "")
        if len(expected) != 64 or expected == "0"*64 or fingerprint != expected:
            raise RuntimeError("loaded image build fingerprint does not match selected manifest")
        if manifest.get("variant") != f"{control}_{backend}":
            raise RuntimeError("loaded image configuration does not match selected manifest")
    return {"control": control, "backend": backend, "test_mode": True, "build_fingerprint": fingerprint}


def transport_test(adapter):
    for pattern in (0,0xFFFFFFFF,0x01234567,0xAA55AA55):
        adapter.register(63,pattern)
        if adapter.register(63) != pattern:
            raise RuntimeError("scratch mismatch")
    adapter.transfer(bytes([2,63,0,0,0,0,0]))
    if adapter.register(63) != 0xAA55AA55:
        raise RuntimeError("partial frame modified scratch")
    return {"transport": "PASS", "partial_frame_abort": "PASS"}


def recover_operation(adapter, primary, force_reset):
    """Recover the demo without replacing the failure that triggered recovery."""
    primary.cleanup_errors = []
    if not force_reset:
        try:
            adapter.register(2,2)
            poll(adapter,1)
            primary.recovery = {"action":"acknowledge", "success":True}
            return
        except Exception as cleanup:
            primary.cleanup_errors.append("acknowledge: " + str(cleanup))
    try:
        reset_and_check(adapter)
        primary.recovery = {"action":"reset", "success":True}
    except Exception as cleanup:
        primary.cleanup_errors.append("reset: " + str(cleanup))
        primary.recovery = {"action":"reset", "success":False}


def run_key(adapter, profile, fixture, request_id, source_schedule=None):
    from keygen_reference import Sha256Words
    from key_checker import check_key
    poll(adapter,1)
    adapter.register(11,0)
    seed = bytes.fromhex(fixture["seed_hex"])
    for index in range(8):
        adapter.register(16+index,int.from_bytes(seed[index*4:index*4+4],"big"))
    adapter.register(4,profile);adapter.register(5,request_id)
    started = time.monotonic()
    adapter.register(2,1)
    samples = []
    transitions = []
    status = None
    try:
        status = poll(adapter,8,samples,source_schedule,transitions)
        elapsed = time.monotonic()-started
        if status>>8 & 15:
            raise RuntimeError(f"core returned status {(status>>8)&15}")
        if not status&4:
            raise RuntimeError("success without complete receiver ownership")
        cycles = (adapter.register(7)<<32)|adapter.register(6)
        count = 4 if profile==0 else 8 if profile==1 else 129
        words = []
        components = {}
        for index in range(count):
            adapter.register(8,index)
            word, meta = adapter.register(9),adapter.register(10)
            component, word_index = meta&7,(meta>>3)&127
            if not meta>>31 or bool(meta&0x800) != (index==count-1):
                raise RuntimeError("invalid result boundary")
            if profile<2:
                expected_component, expected_index, component_last = 1,index,index==count-1
            elif index<64:
                expected_component,expected_index,component_last=2,index,index==63
            elif index==64:
                expected_component,expected_index,component_last=3,0,True
            elif index<97:
                expected_component,expected_index,component_last=4,index-65,index==96
            else:
                expected_component,expected_index,component_last=5,index-97,index==128
            if (component,word_index,bool(meta&0x400)) != (expected_component,expected_index,component_last):
                raise RuntimeError("result component/index mismatch")
            words.append(word)
            components[component] = (components.get(component,0)<<32)|word
        if profile<2:
            source = Sha256Words(seed)
            if words != [source.word() for _ in range(count)]:
                raise RuntimeError("AES fixture mismatch")
        else:
            import math
            n,e,p,q = (components[i] for i in (2,3,4,5))
            d = pow(e,-1,math.lcm(p-1,q-1))
            check_key({"n":n,"e":e,"p":p,"q":q,"d":d})
            expected_path = Path(__file__).resolve().parents[2]/"reference/expected_keys.json"
            expected = next(item["key"] for item in json.loads(expected_path.read_text())["results"]
                            if item["seed_id"]==fixture["id"])
            if any(value != int(expected[name],16) for name,value in (("n",n),("e",e),("p",p),("q",q),("d",d))):
                raise RuntimeError("RSA deterministic corpus mismatch")
        result = {"profile":profile,"seed_id":fixture["id"],"request_id":request_id,"result":"PASS",
                "core_cycles":cycles,"core_seconds":cycles/50000000,"spi_completion_seconds":elapsed,"fan_samples":samples,
                "source_transitions":transitions}
    except Exception as error:
        error.fan_samples=samples
        error.source_transitions=transitions
        # A missing completion cannot be acknowledged: abort through gray reset.
        recover_operation(adapter,error,force_reset=status is None)
        raise
    try:
        adapter.register(2,2)
        poll(adapter,1)
    except Exception as error:
        error.fan_samples=samples
        error.source_transitions=transitions
        recover_operation(adapter,error,force_reset=True)
        raise
    return result



def configure_request(adapter, profile, fixture, request_id, controls=0):
    poll(adapter,1)
    adapter.register(11,controls)
    seed=bytes.fromhex(fixture["seed_hex"])
    for index in range(8):
        adapter.register(16+index,int.from_bytes(seed[index*4:index*4+4],"big"))
    adapter.register(4,profile)
    adapter.register(5,request_id)
    adapter.register(2,1)


def reset_and_check(adapter):
    adapter.reset_board_core()
    poll(adapter,1)
    status=adapter.register(3)
    if status & 0xE or adapter.register(9) or adapter.register(10):
        raise RuntimeError("reset exposed stale status/result")
    if any(adapter.register(address) for address in (4,5,8,11,63,*range(16,24))):
        raise RuntimeError("reset did not clear demo configuration")


def wait_running(adapter):
    """Busy also covers pre-admission setup; require the observable RUN state."""
    deadline=time.monotonic()+TIMEOUT
    while time.monotonic()<deadline:
        if adapter.register(12)&7 == 4:
            return
        time.sleep(.01)
    raise TimeoutError("demo did not enter RUN before reset boundary")


def reset_replay(adapter, fixture, results, checkpoint=lambda:None):
    # These are observable boundaries, not an assertion about hidden RSA subphases.
    for name,profile,controls,mask in (
        ("generation_stall",2,1,2),
        ("rsa_active",2,0,2),
        ("result_stall",0,2,2),
        ("ownership_stall",1,4,4),
        ("held_success",0,0,8),
    ):
        reset_and_check(adapter)
        configure_request(adapter,profile,fixture,0xA000+len(results),controls)
        poll(adapter,mask)
        if name in ("generation_stall","rsa_active"):
            wait_running(adapter)
        if name=="rsa_active":
            time.sleep(.05)
            if not adapter.register(3)&2:raise RuntimeError("RSA was not busy at reset boundary")
        if name=="result_stall":
            deadline=time.monotonic()+TIMEOUT
            while not adapter.register(12)&8:
                if time.monotonic()>=deadline:raise TimeoutError("result stall not reached")
                time.sleep(.01)
        reset_and_check(adapter)
        results.append({"reset_boundary":name,"result":"PASS","fan":telemetry(adapter)})
        checkpoint()
    # Replay each profile after interruption; run_key checks every word against its oracle.
    for profile in (0,1,2):
        result=run_key(adapter,profile,fixture,0xB000+profile)
        result["reset_replay"]=True
        results.append(result)
        checkpoint()


def soak(adapter, seeds, results, checkpoint=lambda:None, duration=1800):
    if duration<=0:raise ValueError("soak duration must be positive")
    started=time.monotonic()
    index=0
    while time.monotonic()-started < duration:
        profile=index%3
        fixture=seeds[(index//3)%len(seeds)]
        result=run_key(adapter,profile,fixture,index+1)
        result["soak_elapsed_seconds"]=time.monotonic()-started
        results.append(result)
        checkpoint()
        index+=1
    return {"soak_seconds":time.monotonic()-started,"soak_jobs":index}


def stall_replay(adapter, fixture, results, checkpoint=lambda:None):
    for replay, schedule in (("baseline", None), ("generation_stalls", [(0.02,1),(0.12,0),(0.20,1),(0.30,0)])):
        result = run_key(adapter,2,fixture,fixture["id"],source_schedule=schedule)
        result["replay"] = replay
        results.append(result)
        checkpoint()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action",choices=("transport","aes","rsa","corpus","soak","reset-replay","stall-replay"),required=True)
    parser.add_argument("--seed",type=int,choices=range(1,21),default=1)
    parser.add_argument("--frequency",type=int,choices=(100000,500000,1000000),default=1000000)
    parser.add_argument("--reset",action="store_true",help="pulse gray core reset; fan control stays active")
    parser.add_argument("--report",type=Path,required=True)
    parser.add_argument("--manifest",type=Path,required=True,help="selected build evidence; loaded fingerprint must match")
    args = parser.parse_args()
    reference = Path(__file__).resolve().parents[2]/"reference"
    sys.path.insert(0,str(reference))
    seeds = json.loads((reference/"seeds.json").read_text())["seeds"]
    manifest = json.loads(args.manifest.read_text())
    args.report.parent.mkdir(parents=True,exist_ok=True)
    report = {"adapter_serial":SERIAL,"frequency_hz":args.frequency,"action":args.action,"result":"RUNNING","results":[]}
    def checkpoint():
        args.report.write_text(json.dumps(report,indent=2)+"\n")
    try:
        with SpiAdapter(args.frequency) as adapter:
            if args.reset:
                adapter.reset_board_core()
            report.update(identify(adapter,manifest))
            report.update(transport_test(adapter))
            checkpoint()
            if args.action=="soak":
                report.update(soak(adapter,seeds,report["results"],checkpoint))
            elif args.action=="reset-replay":
                reset_replay(adapter,seeds[args.seed-1],report["results"],checkpoint)
            elif args.action=="stall-replay":
                stall_replay(adapter,seeds[args.seed-1],report["results"],checkpoint)
            profiles = (0,1) if args.action=="aes" else (2,) if args.action in ("rsa","corpus") else ()
            chosen = seeds if args.action=="corpus" else [seeds[args.seed-1]]
            for profile in profiles:
                for fixture in chosen:
                    result = run_key(adapter,profile,fixture,fixture["id"])
                    report["results"].append(result)
                    checkpoint()
                    print(f"PASS profile={profile} seed={fixture['id']} cycles={result['core_cycles']}",flush=True)
            if args.action=="corpus":
                report["median_core_seconds"] = statistics.median(x["core_seconds"] for x in report["results"])
                if report["median_core_seconds"]>30:
                    raise RuntimeError("twenty-seed median exceeds 30-second acceptance target")
        report["result"]="PASS"
    except Exception as error:
        report["result"]="FAIL";report["error"]=str(error)
        report["failure_fan_samples"]=getattr(error,"fan_samples",[])
        report["failure_source_transitions"]=getattr(error,"source_transitions",[])
        report["failure_cleanup_errors"]=getattr(error,"cleanup_errors",[])
        report["failure_recovery"]=getattr(error,"recovery",None)
    args.report.parent.mkdir(parents=True,exist_ok=True)
    args.report.write_text(json.dumps(report,indent=2)+"\n")
    print(report["result"]+": "+str(args.report))
    if report["result"]!="PASS":
        print(report["error"],file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
