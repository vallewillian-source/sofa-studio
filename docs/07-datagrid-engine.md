# DataGrid Engine

**Namespace**: `Sofa::DataGrid`
**Path**: [src/datagrid/](src/datagrid/)

The DataGrid Engine is a high-performance, C++ based grid component designed to handle large datasets more efficiently than standard QML `TableView`.

## Architecture

The system is split into the **Engine** (Logic/Model) and the **View** (Rendering).

### 1. DataGridEngine (The Model)
**File:** [DataGridEngine.cpp](src/datagrid/DataGridEngine.cpp)

A `QObject` subclass exposed to QML. It holds the "Single Source of Truth" for the grid data.

*   **State**:
    *   `m_schema`: The `TableSchema` (columns, types).
    *   `m_rows`: `std::vector<QVariantList>` (the actual data).
*   **Methods**:
    *   `loadFromVariant(QVariantMap)`: Parses the result from `AppContext` (UDM format) and populates the internal vectors.
    *   `rowCount()`, `columnCount()`, `data(row, col)`: Accessors for the renderer.

### 2. DataGridView (The Renderer)
**File:** [DataGridView.cpp](src/datagrid/DataGridView.cpp)

A `QQuickPaintedItem` subclass. This is where the pixels are drawn.

*   **Painting Strategy**:
    *   It does **not** create QML Items for cells (too heavy).
    *   It overrides `paint(QPainter*)`.
    *   It calculates which rows/columns are visible based on `contentX`, `contentY`, and `viewport` size.
    *   It iterates only the visible cells and draws text/lines using `QPainter`.
*   **Input Handling**:
    *   Handles mouse clicks for cell selection.
    *   Calculates row/column from X/Y coordinates.

### 3. QML Integration (`DataGrid.qml`)
**File:** [DataGrid.qml](src/ui/DataGrid.qml)

Combines the C++ Renderer with QML controls.
*   **ScrollBars**: Standard `ScrollBar` controls are bound to the `DataGridView`'s `contentX`/`contentY`.
*   **Toolbar**: Provides "Refresh", "Export" (future), and status info.

## Key Features

*   **Virtualization**: Only draws what is visible. Can handle 100k+ rows (memory permitting) with smooth scrolling.
*   **Type Aware**: Renders different types differently (e.g., right-align numbers, special formatting for dates).
