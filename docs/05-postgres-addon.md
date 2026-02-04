# Postgres Add-on

## Overview

The Postgres add-on provides catalog discovery, query execution, and query cancellation using Qt SQL with a Postgres backend.

## Connection Lifecycle

- Connection creation happens in the add-on host via PostgresAddon.
- PostgresConnection opens a QSqlDatabase with the provided host, port, database, user, and password.
- Catalog and query providers are created after a successful open.

## Catalog Provider

- Lists schemas from information_schema.schemata.
- Lists tables from information_schema.tables.
- Resolves table schema from information_schema.columns.

## Query Provider

- Executes SQL using QSqlQuery.
- Maps column metadata into the UDM schema.
- Applies a soft limit from DatasetRequest.
- Provides backendPid using SELECT pg_backend_pid().

## Cancellation

- AppContext requests cancellation via IConnectionProvider.cancelQuery.
- PostgresConnection issues SELECT pg_cancel_backend(:pid).
- If the driver or server rejects cancellation, lastError is populated.

## Testing

1. Start a Postgres instance.
2. Create a connection in the UI.
3. Run a SQL query from SQL Console.
4. Press Esc or click Cancel to trigger pg_cancel_backend.
