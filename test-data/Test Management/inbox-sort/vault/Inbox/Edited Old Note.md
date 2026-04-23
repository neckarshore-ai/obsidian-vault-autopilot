---
tags:
  - Architecture
created: 2026-02-20T14:00
modified: 2026-04-06T09:00
---

# Microservices Communication Patterns

Notes on choosing between sync and async communication patterns for service-to-service calls.

## Synchronous (REST/gRPC)

Simple request-response. Caller waits for the result. Works well when:
- The caller needs the response to continue
- Latency requirements are tight (< 100ms)
- The dependency graph is shallow (max 2-3 hops)

Downside: temporal coupling. If the downstream service is down, the caller fails too. Circuit breakers help but add complexity.

## Asynchronous (Message Queue)

Fire and forget. Caller publishes a message and moves on. Best when:
- The operation can be eventually consistent
- You need to handle traffic spikes (queue absorbs bursts)
- Multiple consumers need the same event (fan-out)

Downside: debugging is harder. A failed message in a dead-letter queue is less obvious than a 500 error in your logs.

## Our Decision

Use sync for reads (user-facing queries need immediate response) and async for writes (order processing, notifications, analytics). This gives us the best of both worlds without overcomplicating the architecture.

## Next Steps

- Set up RabbitMQ for the first async workflow (order confirmation emails)
- Define message schema conventions (CloudEvents format)
- Build a dead-letter queue dashboard
