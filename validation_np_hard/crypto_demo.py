"""Safe crypto demos.

This module intentionally does NOT attempt to break RSA or recover private keys.
It only demonstrates *generating* an RSA keypair and performing basic operations.

If the optional 'cryptography' package is not installed, the demo is skipped.
"""

from __future__ import annotations

from typing import Any, Dict


def rsa_keygen_smoke() -> Dict[str, Any]:
    try:
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.asymmetric import padding, rsa
    except Exception as exc:
        return {"skipped": True, "reason": f"cryptography not installed: {exc}"}

    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    public_key = private_key.public_key()

    message = b"plm-rsa-smoke"

    signature = private_key.sign(
        message,
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
        hashes.SHA256(),
    )

    public_key.verify(
        signature,
        message,
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()), salt_length=padding.PSS.MAX_LENGTH),
        hashes.SHA256(),
    )

    ciphertext = public_key.encrypt(
        message,
        padding.OAEP(mgf=padding.MGF1(algorithm=hashes.SHA256()), algorithm=hashes.SHA256(), label=None),
    )
    plaintext = private_key.decrypt(
        ciphertext,
        padding.OAEP(mgf=padding.MGF1(algorithm=hashes.SHA256()), algorithm=hashes.SHA256(), label=None),
    )

    return {
        "skipped": False,
        "key_size": 2048,
        "public_exponent": 65537,
        "signature_ok": True,
        "encrypt_decrypt_ok": plaintext == message,
        "ciphertext_len": len(ciphertext),
    }
