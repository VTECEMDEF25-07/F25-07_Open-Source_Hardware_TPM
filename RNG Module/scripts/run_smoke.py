"""Sequential short regressions, separate from the long RSA generation tests."""
from test_integration import vectors,run
vectors()
run('tb_rng_crypto')
run('tb_rng_system')
run('tb_rng_system',extra=['+define+FRESH'])
run('tb_rng_system',extra=['+define+FRESH'],softcore=True)
