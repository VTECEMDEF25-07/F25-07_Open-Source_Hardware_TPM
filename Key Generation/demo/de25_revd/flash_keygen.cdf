/* Filename: flash_keygen.cdf
 * Authors: Project contributors; see Git history.
 * Date: 2026-10-14
 * General Description: Program the DE25 keygen image in its 128-Mbit QSPI flash.
 * AI Disclosure: Codex and GPT-6 Astra assisted with coding and verification.
 * Copy this file beside keygen_de25.jic before invoking quartus_pgm.
 */
JedecChain;
    FileRevision(JESD32A);
    DefaultMfr(6E);

    P ActionCode(Cfg)
        Device PartName(A5ED013BB32AE4SCS) Path("./") File("keygen_de25.jic") MfrSpec(OpMask(1) SEC_Device(MT25QU128) Child_OpMask(1 1));

ChainEnd;

AlteraBegin;
    ChainType(JTAG);
    Frequency(15000000);
AlteraEnd;
