---
tags:
  - Architecture
created: 2026-03-03T15:00
modified: 2026-03-03T15:00
---

# Serverless Architecture Patterns

Notes from a conference talk on serverless design patterns that scale.

## Event-Driven Processing

Decouple producers from consumers. Use message queues (SQS, RabbitMQ) to buffer events. Each function handles one event type. Retry logic lives in the queue, not the function.

## API Gateway + Lambda

The most common pattern. Gateway handles routing, auth, and rate limiting. Lambda handles business logic. Keep functions small — one responsibility per function.

## Fan-Out / Fan-In

Split a large job into parallel chunks. Process each chunk independently. Aggregate results when all chunks complete. Works well for batch processing, report generation, and data pipelines.

## Saga Pattern

Distributed transactions across multiple services. Each step has a compensating action. If step 3 fails, undo steps 2 and 1. Eventual consistency instead of ACID.

#clippings

Source: re:Invent 2025 talk by Werner Vogels, captured during the livestream.
