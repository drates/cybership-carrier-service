# Cybership - Carrier Integration Service

This project is a backend service built in TypeScript that provides a unified interface for fetching shipping rates from various carriers. It is designed with a highly extensible and maintainable **Hexagonal Architecture**, ensuring that new carriers can be added with minimal effort and zero changes to existing code.

This solution was built as a take-home assessment and demonstrates production-grade practices for architecture, authentication, error handling, and testing.

## Core Architectural Decisions

-   **Hexagonal Architecture (Ports & Adapters):** The core business logic (the "hexagon") is completely decoupled from external concerns like APIs, databases, or frameworks.
    -   **Ports:** The `domain/ports/ICarrier.ts` interface defines the contract that our application uses to talk to the outside world.
    -   **Adapters:** The `infrastructure/carriers/ups/UPSAdapter.ts` is a concrete implementation of the `ICarrier` port. It handles the specific details of communicating with the UPS API.

-   **Anti-Corruption Layer (ACL):** We use `Zod` schemas (`UPSSchemas.ts`) to validate and parse responses from external APIs. This protects our application from unexpected API changes or malformed data, ensuring that only clean, validated data enters our domain.

-   **Centralized, Smart HTTP Client:** All external communication happens through a single, pre-configured `Axios` instance (`HttpClient.ts`). This client uses **interceptors** to transparently handle complex, cross-cutting concerns:
    -   **Authentication:** Automatically acquires, caches, and refreshes OAuth 2.0 tokens on 401 errors. The rest of the application is completely unaware of this process.

-   **Dependency Injection & Registry Pattern:** The `CarrierService` does not know about `UPSAdapter`. Instead, it asks a `CarrierFactory` for an implementation of `ICarrier`. This Inversion of Control is key to the system's extensibility.

## How to Add a New Carrier (e.g., FedEx) in 5 Minutes

The architecture makes adding new providers incredibly simple.

1.  **Create the Adapter:**
    -   Create a new directory: `src/infrastructure/carriers/fedex/`.
    -   Inside, create `FedExAdapter.ts` that implements the `ICarrier` interface. It will contain the logic to call the FedEx API.
    -   Create `FedExMapper.ts` to translate between the Cybership domain models and the FedEx API format.
    -   Create `FedExSchemas.ts` with Zod schemas to validate the FedEx API responses.

2.  **Register the Adapter:**
    -   Open `src/infrastructure/carriers/CarrierFactory.ts`.
    -   Import your new `FedExAdapter`.
    -   Add one line in the constructor:
        ```typescript
        const fedexAdapter = new FedExAdapter();
        this.carriers.set(fedexAdapter.code, fedexAdapter);
        ```

**That's it.** The `CarrierService` can now be called with `carrierCode: 'fedex'` and it will work without any further changes.

## Setup

### Prerequisites

-   Node.js (v18 or later)
-   npm

### Installation

1.  Install dependencies:
    \`\`\`bash
    npm install
    \`\`\`

2.  Set up environment variables:
    \`\`\`bash
    cp .env.example .env
    \`\`\`
    Now, open the `.env` file and fill in the placeholder values. (For this assessment, dummy values are fine as the tests are fully stubbed).

### Running Tests

The integration test suite is the primary way to verify the service's functionality. It uses `nock` to stub all external HTTP calls, so no live API keys are needed.

3.  Run tests:
    \`\`\`bash
    npm test
    \`\`\`

## Future Improvements

Given more time, I would focus on these areas:

1.  **Multi-Carrier Rate Shopping:** Extend the `CarrierService` to accept a single request and fetch rates from multiple carriers concurrently (e.g., UPS, FedEx, DHL). It would then apply a business logic strategy (e.g., "return the cheapest rate," "return the fastest rate") to the aggregated results before responding to the client. The current architecture is already perfectly set up for this.
2.  **Business Intelligence Hooks:** Implement a system to track and store key metrics from rate requests and responses. This data (e.g., average cost per region, most used service level, provider response times) is invaluable for business intelligence, cost analysis, and identifying optimization opportunities. This would likely involve publishing events to a message queue for asynchronous processing.
3.  **Resilience & Retries:** Implement a full retry strategy in the `HttpClient` for transient errors. This would include exponential backoff for `429 Too Many Requests` and `5xx` server errors to make the service more robust.
4.  **Distributed Caching:** For a production environment with multiple service instances, the in-memory `TokenStore` would be replaced with a distributed cache like Redis to ensure all instances share the same auth token and avoid redundant refresh requests.
