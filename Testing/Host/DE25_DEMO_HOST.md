# Explicit public MODEXP width

The host defaults to expecting the full2048-bit portable target. The approved
bounded DE25 configuration must be requested explicitly:

```text
python de25_crypto_demo.py --transport module:factory --expected-modexp-width 1024 --evidence result.json
```

The factory supplies the hardware owner's locked FIFO/SPI transport. CAPS and
MODEXP results must advertise the exact expected width. There is no automatic
fallback or truncation. Choices256/1024/2048 are accepted only when the caller
expects them;256 is a possible future explicit configuration, not a board claim.
Packet operands and result lengths derive from the matched actual capability.

For1024 bits: B=128, public byte-RAM layout0/128/256/384 (base/exponent/modulus/
result), request410 bytes and response166 bytes. AES256,1024-byte payload
capacity, TEST_DETERMINISTIC and FRESH_UNQUALIFIED labels remain unchanged.
Output identifies1024-bit public MODEXP and makes no2048-bit hardware claim.

Run `python test_de25_crypto_demo_width.py` for focused software-only capability,
layout/length, mismatched-width rejection and visible-claim checks. The scripted
empty-message flow is a host protocol test, not RTL or physical acceptance.
`python de25_crypto_demo.py --self-test` retains independent NIST AES and public
test-key fixtures. Hardware owner performs configured RTL/build/physical gates.
