FROM python:3.12-slim

# Install cirq (small image, no cache)
RUN pip install --no-cache-dir cirq

# Default command prints a hello message with version
CMD ["python","-c","import cirq; print('Hello from Cirq in image', cirq.__version__)"]
