# RNG module

Author: Aaron Grossman (organization notes; original source authorship preserved).

These sources were added to main by PR #38 (merge commit `847341411dae1319951a0198ed7ce99630b6bf65`) and relocated here without changing their contents or author notices.

- `RNG.v`: standalone RNG command/response wrapper.
- `entropy_source.v`, `ring_osc.v`: entropy-source implementation and oscillator model.
- `random_number_generation.v`: the supplied RNG processing state machine.
- `tpm2_get_random.v`: standalone TPM2_GetRandom byte-stream handler.
- `entropy_capture.v`, `uart.v`: raw-sample capture and UART transfer; these are required by the DE25 entropy-capture feature, not by the standalone `RNG` wrapper.

Hash conditioning and Hash_DRBG remain placeholders in the supplied code. The existing DE1/DE25 TPM projects do not yet instantiate this standalone RNG wrapper. Moving these sources does not integrate them into the TPM command path.

See [RNG simulations](../../Testing/Simulation/RNG%20Module/README.md) and [DE25 entropy capture](../../Testing/Hardware/DE25/Entropy%20Capture/README.md).
