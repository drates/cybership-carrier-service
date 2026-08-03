# Cybership - Carrier Integration Service

A professional-grade backend service built in TypeScript, designed for high extensibility, reliability, and observability. This project serves as a reference implementation for **Hexagonal Architecture**, demonstrating how to build resilient systems that interact with unpredictable external APIs.

## Key Architectural Highlights

- **Core Stack & Architecture:** Built with TypeScript and Node.js using a strict **Hexagonal Architecture (Ports & Adapters)** and the **Factory Pattern**. This ensures the core business logic is completely decoupled from external infrastructure, allowing for rapid extension and unit-testable domain code.

- **Data Integrity & Anti-Corruption Layer (ACL):** Leverages **Zod schemas** to strictly validate, parse, and sanitize external provider responses. This shields the core domain from upstream API changes and ensures that only clean, well-formed data enters the application.

- **Resilient Centralized HTTP Client:** An advanced `Axios` implementation using custom interceptors to handle cross-cutting concerns transparently:
    - **Token Lifecycle:** Automated OAuth 2.0 token acquisition, caching, and seamless 401 error token refresh flows.
    - **Resilience:** The application logic remains agnostic of the underlying auth complexity.

- **Structured Observability & Telemetry (Golden Signals):** Implements structured JSON logging to monitor the **Telemetry Golden Signals** (Latency, Error Rates, and Request Volume).
    - **Latency Tracking:** Interceptors automatically calculate `durationMs` for every call, enabling performance monitoring.
    - **Error Contextualization:** Failures are caught as structured objects (`ProviderError`, `AuthenticationError`), capturing the full API response context for rapid debugging and post-mortem analysis. This format is ready for ingestion into cloud monitoring stacks like Datadog, ELK, or AWS CloudWatch.

- **Production-Grade Testing Suite:** Powered by **Vitest and Nock** for deterministic integration testing. By fully stubbing network calls, we can validate critical paths—including multi-step token refresh lifecycles and structured error handling—without relying on live APIs or risking flaky, network-dependent tests.
## How to Add a New Carrier (e.g., FedEx) in 5 Minutes

1. **Create the Adapter:**
   Create `src/infrastructure/carriers/fedex/`, implementing the `ICarrier` interface. Use a dedicated `Mapper` for transformation and `Zod` schemas for your Anti-Corruption Layer.
2. **Register the Adapter:**
   Open `src/infrastructure/carriers/CarrierFactory.ts` and add one line:

