# Postgres Add-on

**Id**: `postgres`
**Implementation**: Uses `QtSql` module (`QSqlDatabase`, `QSqlQuery`) with the `QPSQL` driver.

## Architecture

The Postgres add-on implements the interfaces defined in `IAddon.h`.

### 1. PostgresAddon
Factory class that registers the driver with `AddonHost`.
*   `createConnection()`: Returns a new `PostgresConnection`.

### 2. PostgresConnection
Manages the `QSqlDatabase` handle.
*   **Connection Name**: Generates a unique connection name (e.g., `postgres_uuid`) to allow multiple connections to the same DB in Qt.
*   **Open**: Calls `db.open()`.
*   **Capabilities**: Returns `PostgresCatalog` and `PostgresQuery` instances.

### 3. PostgresCatalog
Responsible for metadata discovery using `information_schema`.

*   **`listSchemas()`**:
    ```sql
    SELECT schema_name FROM information_schema.schemata
    WHERE schema_name NOT IN ('information_schema', 'pg_catalog', ...)
    ```
*   **`listTables(schema)`**:
    ```sql
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = :schema
    ```
*   **`getTableSchema(schema, table)`**:
    Queries `information_schema.columns` to build the `TableSchema` struct (column names, types, primary keys).

### 4. PostgresQuery
Handles SQL execution.

*   **`execute(query, request)`**:
    *   Wraps the user query to apply LIMIT/OFFSET if needed (though currently `SqlConsole` sends raw queries).
    *   Iterates `QSqlQuery::next()`.
    *   **Type Mapping**: Converts `QVariant` types from QtSql to UDM `DataType`.
        *   `QMetaType::Int`, `LongLong` -> `DataType::Integer`
        *   `QMetaType::QString` -> `DataType::Text`
        *   `QMetaType::QByteArray` -> `DataType::Blob`
*   **`backendPid()`**:
    Executes `SELECT pg_backend_pid()` immediately after connection to store the Process ID for cancellation.

### 5. Cancellation
**File:** [IConnectionProvider.h](src/core/addons/IAddon.h)

The `cancelQuery(pid)` method is critical for UX.
*   **Mechanism**: It opens a **new, separate** connection to the database (since the main one is blocked by the running query).
*   **Command**: `SELECT pg_cancel_backend(:pid)`.
*   **Result**: The server terminates the query on the main connection, causing `QSqlQuery::exec()` to return with an error (e.g., "Query canceled").
