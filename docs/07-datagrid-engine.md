# DataGrid Engine

## Overview

The DataGrid engine is a C++ state container and renderer that powers the QML grid. It separates data state from UI, keeping rendering fast and consistent across views.

## Components

- DataGridEngine (C++): schema + rows + view state.
- DataGridView (C++ QQuickPaintedItem): renders headers, cells, and selection.
- DataGrid.qml (QML wrapper): provides a toolbar and scrollbars.

## Data Flow

1. AppContext fetches datasets.
2. DataGridEngine.loadFromVariant ingests columns and rows.
3. DataGridView pulls data from the engine and renders on paint.
4. Views are applied via DataGridEngine.applyView to update labels and visibility.

## Rendering Model

- Headers render from column metadata.
- Cells render row values from engine storage.
- Scrolling is managed by QML scrollbars binding contentX/contentY.

## Grid Controls

- DataGrid.qml exposes controlsVisible to toggle the toolbar.
- The toolbar includes Refresh, Wrap Text, and row count.

## Limitations

- Wrap Text is present but not wired to layout changes yet.
- Virtualized 2D paging is planned but not implemented in MVP.
