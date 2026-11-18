# Future work

## Validate RNG entropy for each implemented FPGA image

FPGA fitting can change the entropy source's physical placement, routing, and
sampling behavior. Bind the entropy evidence to the exact programmed image and
board profile, including the image identifier, board revision, and sampling
configuration.

- Provide built-in raw-sample collection and a self-test, or require an
  external hardware capture. Collect raw samples before conditioning and
  assess them offline.
- Define acceptance criteria before testing. Record the capture conditions,
  assessment method, results, and pass or fail decision for each image and
  board profile before relying on the RNG for cryptographic use.

The existing stuck- and biased-source checks detect runtime faults and stop
random output on detection. They do not establish the physical source's
entropy.

## Complete the Phase Three PCR handoff

- Replace the configured empty-password PCR profile with the real Phase Three
  authorization and session interface. Apply the profile's locality policy
  before any PCR mutation.
- Implement external NV and profile-defined Startup, PCR Reset, Shutdown,
  state save, and restore. Keep PCR bank updates and the update counter
  consistent through rejected requests, interruptions, and resume.
- Add end-to-end tests for authorization and locality rejection, unchanged PCRs
  and counter on rejection, and bank and counter behavior after resume.
