- Python: blocking calls inside async code, unbounded task or thread creation, sockets or HTTP calls
  without timeouts, broad `except` that swallows errors, shared state touched from several threads
  or tasks without a single owner, unvalidated input at trust boundaries.
