# Architecture Overview

## Modules

### 1. App Core (`src/core`)
- **Responsibility**: Domain logic, Service Container (DI), Command System, Add-on Host.
- **Dependencies**: Qt Core.

### 2. UI Shell (`src/ui`)
- **Responsibility**: QML Design System, Shared Components, Shell Layout.
- **Dependencies**: Qt Quick, Core.

### 3. DataGrid Engine (`src/datagrid`)
- **Responsibility**: High-performance grid rendering and state management.
- **Dependencies**: Qt Quick, Core (UDM).

### 4. Add-ons (`addons/`)
- **Responsibility**: Connectors for databases (e.g., Postgres).
- **Dependencies**: Core (Interfaces).

## Universal Data Model (UDM)
A unified way to represent schemas and datasets across different data sources.
