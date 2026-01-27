# EndpointVault API Requirements

This document describes the API endpoints, request/response formats, and data structures required for the EndpointVault backend.

## Table of Contents

1. [Authentication](#authentication)
2. [Endpoints](#endpoints)
3. [Data Models](#data-models)
4. [Server Settings](#server-settings)
5. [Retry Mechanism](#retry-mechanism)
6. [Error Handling](#error-handling)

---

## Authentication

All API requests must include the API key in the header:

```
X-API-Key: <api-key>
Content-Type: application/json
```

---

## Endpoints

### 1. GET /v1/settings

Fetch server settings for the client. Called during SDK initialization.

**Request:**
```http
GET /v1/settings HTTP/1.1
Host: api.endpoint.yahhi.me
X-API-Key: your-api-key
```

**Response (200 OK):**
```json
{
  "localResendEnabled": true,
  "otherSetting": "value"
}
```

**Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `localResendEnabled` | boolean | Yes | Whether client should store unencrypted data locally for replay |
| `*` | any | No | Additional settings as JSON map (extensible) |

---

### 2. POST /v1/events

Submit an error event with encrypted payload and statistical data.

**Request:**
```http
POST /v1/events HTTP/1.1
Host: api.endpoint.yahhi.me
X-API-Key: your-api-key
Content-Type: application/json

{
  "encrypted": {
    "eventId": "550e8400-e29b-41d4-a716-446655440000",
    "timestamp": "2024-01-15T10:30:00.000Z",
    "method": "POST",
    "url": "https://api.example.com/users",
    "encrypted": true,
    "statusCode": 500,
    "errorType": "server_error",
    "errorMessage": "Internal Server Error",
    "requestHeaders": "BASE64_ENCRYPTED_STRING",
    "requestBody": "BASE64_ENCRYPTED_STRING",
    "responseHeaders": "BASE64_ENCRYPTED_STRING",
    "responseBody": "BASE64_ENCRYPTED_STRING",
    "durationMs": 1234,
    "environment": "production",
    "appVersion": "1.2.3",
    "deviceId": "device-uuid-here",
    "extra": {
      "userId": "user123"
    }
  },
  "stats": {
    "eventId": "550e8400-e29b-41d4-a716-446655440000",
    "timestamp": "2024-01-15T10:30:00.000Z",
    "method": "POST",
    "url": "https://api.example.com/users",
    "statusCode": 500,
    "durationMs": 1234,
    "environment": "production",
    "appVersion": "1.2.3",
    "deviceId": "device-uuid-here",
    "isSuccess": false,
    "errorType": "server_error"
  }
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "message": "Event recorded"
}
```

**Response with Retry Command (200 OK):**
```json
{
  "success": true,
  "retry": {
    "retryId": "retry-123-abc",
    "commandType": "send_event",
    "delayMs": 5000,
    "maxAttempts": 3,
    "parameters": {}
  }
}
```

---

### 3. POST /v1/events/stats

Submit only statistical data (for successful requests).

**Request:**
```http
POST /v1/events/stats HTTP/1.1
Host: api.endpoint.yahhi.me
X-API-Key: your-api-key
Content-Type: application/json

{
  "eventId": "550e8400-e29b-41d4-a716-446655440001",
  "timestamp": "2024-01-15T10:31:00.000Z",
  "method": "GET",
  "url": "https://api.example.com/users/123",
  "statusCode": 200,
  "durationMs": 150,
  "environment": "production",
  "appVersion": "1.2.3",
  "deviceId": "device-uuid-here",
  "isSuccess": true
}
```

**Response (200 OK):**
```json
{
  "success": true
}
```

---

### 4. GET /v1/replay/pending

Check if there's a pending replay request for a device.

**Request:**
```http
GET /v1/replay/pending?deviceId=device-uuid-here HTTP/1.1
Host: api.endpoint.yahhi.me
X-API-Key: your-api-key
```

**Response (200 OK) - No pending:**
```json
{
  "pending": false
}
```

**Response (200 OK) - With pending request:**
```json
{
  "pending": true,
  "request": {
    "id": "replay-request-id",
    "eventId": "original-event-id",
    "method": "POST",
    "url": "https://api.example.com/users",
    "headers": {
      "Content-Type": "application/json"
    },
    "body": {
      "name": "John Doe"
    },
    "requestedAt": "2024-01-15T11:00:00.000Z"
  }
}
```

---

### 5. POST /v1/replay/result

Report the result of a replay attempt.

**Request:**
```http
POST /v1/replay/result HTTP/1.1
Host: api.endpoint.yahhi.me
X-API-Key: your-api-key
Content-Type: application/json

{
  "replayId": "replay-request-id",
  "deviceId": "device-uuid-here",
  "success": true,
  "statusCode": 200,
  "errorMessage": null,
  "timestamp": "2024-01-15T11:05:00.000Z"
}
```

**Response (200 OK):**
```json
{
  "success": true
}
```

---

## Data Models

### StatisticalPackage

Minimal metrics data, no sensitive information.

```json
{
  "eventId": "string (UUID)",
  "timestamp": "string (ISO 8601)",
  "method": "string (HTTP method)",
  "url": "string (full URL)",
  "statusCode": "number | null",
  "durationMs": "number | null",
  "environment": "string | null",
  "appVersion": "string | null",
  "deviceId": "string | null",
  "isSuccess": "boolean",
  "errorType": "string | null"
}
```

### EncryptedPackage

Contains encrypted request/response data.

```json
{
  "eventId": "string (UUID)",
  "timestamp": "string (ISO 8601)",
  "method": "string",
  "url": "string",
  "encrypted": true,
  "statusCode": "number | null",
  "errorType": "string | null",
  "errorMessage": "string | null",
  "requestHeaders": "string (base64 encrypted) | null",
  "requestBody": "string (base64 encrypted) | null",
  "responseHeaders": "string (base64 encrypted) | null",
  "responseBody": "string (base64 encrypted) | null",
  "durationMs": "number | null",
  "environment": "string | null",
  "appVersion": "string | null",
  "deviceId": "string | null",
  "extra": "object | null"
}
```

### UnencryptedPackage (Local Storage Only)

**IMPORTANT:** This is stored ONLY on the client device when `localResendEnabled` is true. It is NEVER sent to the server unencrypted.

```json
{
  "eventId": "string (UUID)",
  "timestamp": "string (ISO 8601)",
  "method": "string",
  "url": "string",
  "statusCode": "number | null",
  "errorType": "string | null",
  "errorMessage": "string | null",
  "requestHeaders": "object | null",
  "requestBody": "any | null",
  "responseHeaders": "object | null",
  "responseBody": "any | null",
  "durationMs": "number | null",
  "environment": "string | null",
  "appVersion": "string | null",
  "deviceId": "string | null",
  "extra": "object | null"
}
```

### RetryCommand

Included in server responses to request a retry.

```json
{
  "retryId": "string (unique identifier)",
  "commandType": "string (e.g., 'send_event', 'send_stats')",
  "delayMs": "number (milliseconds before retry)",
  "maxAttempts": "number",
  "parameters": "object | null"
}
```

---

## Server Settings

The server settings endpoint returns a JSON object. Currently supported fields:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `localResendEnabled` | boolean | false | Enable local storage of unencrypted data for replay |

**Future extensibility:** Add any new settings as additional fields. The client stores the entire response as `rawSettings` and provides a `getSetting<T>(key, defaultValue)` method.

---

## Retry Mechanism

### Client Behavior

1. When a request fails (network error, server unavailable), the client queues the request locally
2. Requests are retried with exponential backoff
3. If server returns a `retry` command in response, client uses the provided `retryId` and `delayMs`
4. Maximum retry attempts are configurable (default: 3)

### Server Retry Commands

The server can include a `retry` object in any response to request specific retry behavior:

```json
{
  "success": true,
  "retry": {
    "retryId": "unique-retry-identifier",
    "commandType": "send_event",
    "delayMs": 10000,
    "maxAttempts": 5
  }
}
```

The `retryId` allows the server to track and identify specific retry attempts.

---

## Error Handling

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| 200 | Success |
| 400 | Bad Request - Invalid payload |
| 401 | Unauthorized - Invalid or missing API key |
| 403 | Forbidden - API key doesn't have access |
| 429 | Too Many Requests - Rate limited |
| 500 | Internal Server Error |
| 503 | Service Unavailable - Retry later |

### Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "INVALID_PAYLOAD",
    "message": "Missing required field: eventId"
  }
}
```

---

## Flow Diagrams

### Success Request Flow

```
Client                          Server
  |                               |
  |-- captureSuccess() ---------> |
  |   (stats only)                |
  |                               |
  |<-- 200 OK ------------------- |
  |                               |
```

### Error Request Flow (localResendEnabled = false)

```
Client                          Server
  |                               |
  |-- captureFailure() ---------> |
  |   (encrypted + stats)         |
  |                               |
  |<-- 200 OK ------------------- |
  |                               |
```

### Error Request Flow (localResendEnabled = true)

```
Client                          Server
  |                               |
  |-- Store unencrypted locally   |
  |                               |
  |-- captureFailure() ---------> |
  |   (encrypted + stats)         |
  |                               |
  |<-- 200 OK ------------------- |
  |                               |
```

### Retry Flow (Server Unavailable)

```
Client                          Server
  |                               |
  |-- captureFailure() ---------> |
  |                               X (unavailable)
  |                               |
  |-- Queue for retry             |
  |                               |
  |   ... wait (exponential) ...  |
  |                               |
  |-- Retry request ------------> |
  |                               |
  |<-- 200 OK ------------------- |
  |                               |
  |-- Remove from queue           |
  |                               |
```
