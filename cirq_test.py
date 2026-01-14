"""Cirq sanity check.

This file is collected by pytest due to its name.
We keep Cirq optional: CI may not install it.
"""


def test_cirq_imports_when_installed():
	import pytest

	cirq = pytest.importorskip("cirq")
	assert hasattr(cirq, "__version__")


if __name__ == "__main__":
	try:
		import cirq  # type: ignore

		print("Hello from Cirq", cirq.__version__)
	except Exception as exc:  # pragma: no cover
		raise SystemExit(f"Cirq not available: {exc}")
