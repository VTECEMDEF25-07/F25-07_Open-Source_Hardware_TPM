"""Independent mathematical checker; does not import the generation procedure."""
import math
import secrets


def independently_probable_prime(value: int) -> bool:
    """64 fresh uniformly chosen bases, independent of the generation word stream."""
    if value < 2:
        return False
    for divisor in (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47):
        if value % divisor == 0:
            return value == divisor
    factor = value - 1
    shifts = (factor & -factor).bit_length() - 1
    factor >>= shifts
    for _ in range(64):
        base = 2 + secrets.randbelow(value - 3)
        x = pow(base, factor, value)
        if x in (1, value - 1):
            continue
        passed = False
        for _ in range(1, shifts):
            x = pow(x, 2, value)
            if x == value - 1:
                passed = True
                break
        if not passed:
            return False
    return True


def check_key(key: dict[str, int]) -> None:
    """Raise ValueError on any violation; never use Python assert for pass/fail."""
    def require(condition, detail):
        if not condition:
            raise ValueError(detail)

    require(set(key) == {"n", "e", "p", "q", "d"}, "missing or unexpected fields")
    require(all(type(x) is int and x > 0 for x in key.values()), "invalid integer")
    n, e, p, q, d = (key[x] for x in ("n", "e", "p", "q", "d"))
    require(e == 65537, "exponent")
    require(n.bit_length() == 2048 and p.bit_length() == q.bit_length() == 1024, "width")
    require(p & 1 and q & 1, "parity")
    # Squared bound avoids sharing the oracle's square-root constant.
    require(p * p >= 1 << 2047 and q * q >= 1 << 2047, "prime lower bound")
    require(abs(p - q) > 1 << 924, "prime separation")
    require(n == p * q, "modulus product")
    require(math.gcd(p - 1, e) == math.gcd(q - 1, e) == 1, "exponent compatibility")
    modulus = (p - 1) // math.gcd(p - 1, q - 1) * (q - 1)
    require((1 << 1024) < d < modulus and e * d % modulus == 1, "canonical private exponent")
    require(independently_probable_prime(p), "p composite")
    require(independently_probable_prime(q), "q composite")
    for message in (0, 1, 2, 65537, n - 1, p, q):
        require(pow(pow(message, e, n), d, n) == message, "RSA round trip")
