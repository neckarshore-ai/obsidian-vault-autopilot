---
tags:
  - Architecture
  - API
created: 2026-03-08T09:15
modified: 2026-03-08T11:30
---

# API Rate Limiting Strategy

We need to implement rate limiting before opening the API to external partners. Current internal usage is ~200 req/s but partner traffic could spike to 2,000 req/s.

## Options Evaluated

### Token Bucket

Allows short bursts while enforcing average rate. Good for APIs with variable request patterns. Each client gets a bucket that refills at a fixed rate. Burst capacity equals bucket size.

### Sliding Window

More predictable than token bucket. Counts requests in a rolling time window. No burst allowance — a request either fits in the window or gets rejected.

### Leaky Bucket

Smoothest output rate but worst user experience during bursts. Queues excess requests instead of rejecting them. Only viable if clients can tolerate latency.

## Recommendation

Token bucket with a 100-token capacity and 50 tokens/second refill rate per API key. Implement at the API gateway level so individual services do not need to worry about it.

## Next Steps

- Prototype with Redis-based counter
- Load test with simulated partner traffic
- Define error response format (429 with Retry-After header)
