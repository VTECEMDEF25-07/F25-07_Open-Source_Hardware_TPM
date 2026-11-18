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

## Connect key generation to standard TPM object commands

The planned AES-256 and RSA-2048 integrations exercise the internal keygen
lifecycle with one protected volatile slot. They prove that the execution
engine can request generation, commit a complete result, and release and
clear the slot. They add no host-facing TPM command codes. A testbench can
supply an allow or deny decision to exercise the integration.

### Command prerequisites

| Command | What remains to implement |
| --- | --- |
| `TPM2_ReadPublic` | Resolve a loaded object by its transient handle and marshal its public area, Name, and qualified Name. The basic read requires no object-use authorization. |
| `TPM2_FlushContext` | Release a valid transient object, invalidate its handle, and clear sensitive state before reusing the slot. The first slice can cover transient objects. |
| `TPM2_Create` | Validate the public template and sensitive inputs, authorize the storage parent, call the appropriate generator, and package the result in a private blob protected for that parent. |
| `TPM2_Load` | Authorize the parent, verify and unwrap the private blob, and install the object under a transient handle without regenerating its key. |
| `TPM2_CreateLoaded` | Implement the required parent or hierarchy rules, authorization, and protected object handling for creation followed immediately by loading. |
| `TPM2_CreatePrimary` | Authorize the hierarchy and derive a repeatable generation stream from its protected primary seed and the relevant creation inputs. Connect that stream to the existing core and load the resulting object. |

### Phase Three handoff

- Keep command parsing and response formatting in the execution engine.
  Give Phase Three a documented authorization request and result interface
  for the command, target object or hierarchy, and relevant session context.
  Start protected work only after the matching request is authorized.
- Keep key bytes inside the protected receiver and authorized consumers.
  Document complete-result commit, terminal status, handle publication,
  release, and reset. If a failure occurs after commit and before a success
  reply, reconcile the committed slot and clear it before reuse.
- Add the protected parent and hierarchy infrastructure separately from the
  generation core. Phase Three owns actual sessions and policy, external
  nonvolatile storage, hierarchy seed lifecycle, and protected object
  wrapping and loading. A fresh RNG stream alone is insufficient for
  reproducible primary keys.
- Verify that denied requests start no work, aborted operations expose no
  usable object, flushed handles fail lookup, and successful public replies
  contain no sensitive key bytes. For standard creation and loading, also
  test wrong-parent and corrupt-blob rejection. For primary creation, verify
  repeatability with the same seed and creation inputs.
