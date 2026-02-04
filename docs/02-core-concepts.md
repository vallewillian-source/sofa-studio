# Core Concepts

This document details the internal C++ services and data structures that power Sofa Studio.

## AppContext

**File:** [AppContext.h](src/core/AppContext.h)

`AppContext` is the central "Brain" of the application. It is registered as a QML Singleton named `App`.

### Responsibilities
*   **Session Management**: Tracks the currently active connection ID (`activeConnectionId`) and the active `IConnectionProvider` instance.
*   **Async Dispatch**: Manages `QueryWorker` and `QThread` for non-blocking database operations.
*   **Signal Hub**: Centralizes signals like `connectionOpened`, `sqlFinished`, `datasetError` so different UI components (Sidebar, Console, DataGrid) can react to global state changes.
*   **CRUD Proxy**: Exposes methods to save/load connections and views by delegating to `LocalStoreService`.

### Async Pattern
To prevent UI freezing, `AppContext` uses a worker-thread pattern:
1.  **Request**: `runQueryAsync` creates a `QueryWorker`.
2.  **Thread**: The worker is moved to `m_workerThread`.
3.  **Execution**: `QMetaObject::invokeMethod` triggers the worker's `run()` slot.
4.  **Cancellation**: `cancelActiveQuery` calls `IConnectionProvider::cancelQuery(backendPid)`. This is a "best-effort" cancellation (e.g., sending `pg_cancel_backend`).

## LocalStore

**File:** [LocalStoreService.cpp](src/core/LocalStoreService.cpp)

Local persistence is handled by an SQLite database (`sofa.db`) stored in the user's standard data location (e.g., `~/Library/Application Support/sofa-studio/`).

### Schema
*   **connections**: Stores connection metadata (name, host, port, user, driver_id). Passwords are **not** stored here (see Secrets).
*   **views**: Stores saved view configurations.
    *   `id`: Primary Key.
    *   `connection_id`: Foreign Key to connections.
    *   `schema`, `table_name`: Target object.
    *   `name`: Display name of the view.
    *   `definition`: JSON blob containing column configurations (aliases, visibility).

## Universal Data Model (UDM)

**File:** [UDM.h](src/core/udm/UDM.h)

UDM provides a common language for all modules.

### Key Structs
*   **`DataType`**: Enum for standard types (Text, Integer, Date, Blob, etc.).
*   **`Column`**: Metadata for a single column.
    *   `name`: Physical DB name.
    *   `label`: Display name (alias).
    *   `visible`: Boolean for UI rendering.
    *   `type`: UDM DataType.
*   **`TableSchema`**: List of `Column`s + table name.
*   **`DatasetPage`**: A chunk of data rows + schema + execution metadata (time, warnings).

## Secrets Management

**File:** [SimpleSecretsService.cpp](src/core/SimpleSecretsService.cpp)

Currently, the MVP uses a simple in-memory or obfuscated file storage for passwords.
*   **Goal**: Abstract the OS keychain (Keychain on macOS, Credential Manager on Windows).
*   **Current**: `secretRef` in `ConnectionData` points to a key in the secrets service.
