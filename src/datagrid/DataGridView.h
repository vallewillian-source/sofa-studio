#pragma once
#include <QQuickPaintedItem>
#include <QPainter>
#include <QSvgRenderer>
#include <QRectF>
#include <vector>
#include "DataGridEngine.h"

namespace Sofa::DataGrid {

class DataGridView : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(Sofa::DataGrid::DataGridEngine* engine READ engine WRITE setEngine NOTIFY engineChanged)
    Q_PROPERTY(double contentY READ contentY WRITE setContentY NOTIFY contentYChanged)
    Q_PROPERTY(double contentX READ contentX WRITE setContentX NOTIFY contentXChanged)
    Q_PROPERTY(double totalHeight READ totalHeight NOTIFY contentSizeChanged)
    Q_PROPERTY(double totalWidth READ totalWidth NOTIFY contentSizeChanged)
    Q_PROPERTY(double rowHeight READ rowHeight WRITE setRowHeight NOTIFY rowHeightChanged)
    Q_PROPERTY(QColor headerColor READ headerColor WRITE setHeaderColor NOTIFY headerColorChanged)
    Q_PROPERTY(QColor alternateRowColor READ alternateRowColor WRITE setAlternateRowColor NOTIFY alternateRowColorChanged)
    Q_PROPERTY(QColor selectionColor READ selectionColor WRITE setSelectionColor NOTIFY selectionColorChanged)
    Q_PROPERTY(QColor gridLineColor READ gridLineColor WRITE setGridLineColor NOTIFY gridLineColorChanged)
    Q_PROPERTY(QColor textColor READ textColor WRITE setTextColor NOTIFY textColorChanged)
    Q_PROPERTY(QColor resizeGuideColor READ resizeGuideColor WRITE setResizeGuideColor NOTIFY resizeGuideColorChanged)
    Q_PROPERTY(int sortedColumnIndex READ sortedColumnIndex WRITE setSortedColumnIndex NOTIFY sortedColumnIndexChanged)
    Q_PROPERTY(bool sortAscending READ sortAscending WRITE setSortAscending NOTIFY sortAscendingChanged)

public:
    explicit DataGridView(QQuickItem* parent = nullptr);
    
    DataGridEngine* engine() const { return m_engine; }
    void setEngine(DataGridEngine* engine);
    
    double contentY() const { return m_contentY; }
    void setContentY(double y);
    
    double contentX() const { return m_contentX; }
    void setContentX(double x);
    
    double rowHeight() const { return m_rowHeight; }
    void setRowHeight(double h);

    QColor headerColor() const { return m_headerColor; }
    void setHeaderColor(const QColor& c);

    QColor alternateRowColor() const { return m_alternateRowColor; }
    void setAlternateRowColor(const QColor& c);

    QColor selectionColor() const { return m_selectionColor; }
    void setSelectionColor(const QColor& c);

    QColor gridLineColor() const { return m_lineColor; }
    void setGridLineColor(const QColor& c);

    QColor textColor() const { return m_textColor; }
    void setTextColor(const QColor& c);

    QColor resizeGuideColor() const { return m_resizeGuideColor; }
    void setResizeGuideColor(const QColor& c);

    int sortedColumnIndex() const { return m_sortedColumnIndex; }
    void setSortedColumnIndex(int index);

    bool sortAscending() const { return m_sortAscending; }
    void setSortAscending(bool ascending);

    double totalHeight() const;
    double totalWidth() const;
    
    void paint(QPainter* painter) override;

signals:
    void engineChanged();
    void contentYChanged();
    void contentXChanged();
    void contentSizeChanged();
    void rowHeightChanged();
    void headerColorChanged();
    void alternateRowColorChanged();
    void selectionColorChanged();
    void gridLineColorChanged();
    void textColorChanged();
    void resizeGuideColorChanged();
    void sortedColumnIndexChanged();
    void sortAscendingChanged();
    
    void sortRequested(int columnIndex, bool ascending);
    void cellContextMenuRequested(int row, int column, double x, double y);
    void columnResized(int index, int width);
    void rowHeightResized(double height);
    void rowResized(int row, double height);

protected:
    void mousePressEvent(QMouseEvent* event) override;
    void mouseMoveEvent(QMouseEvent* event) override;
    void mouseReleaseEvent(QMouseEvent* event) override;
    void mouseDoubleClickEvent(QMouseEvent* event) override;
    void hoverMoveEvent(QHoverEvent* event) override;
    void hoverLeaveEvent(QHoverEvent* event) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    
private slots:
    void onEngineUpdated();

private:
    static constexpr int kRowResizeHandleNone = -1;
    static constexpr int kRowResizeHandleAll = -2;

    int columnAtPosition(double x) const;
    int columnResizeHandleAt(double x, double y) const;
    int rowResizeHandleAt(double x, double y) const;
    double columnRightX(int column) const;
    int autoFitColumnWidth(int column) const;
    QString cellDisplayText(int row, int column) const;
    double rowHeightForRow(int row) const;
    double rowTopContentY(int row) const;
    int rowAtContentY(double y) const;
    void setRowHeightForRow(int row, double height);
    void syncRowOverridesWithEngine();
    void ensureRowLayoutCache() const;
    void markRowLayoutDirty();
    double maxContentX() const;
    double maxContentY() const;
    void clampScrollOffsets();
    void updateHoverState(double x, double y);
    void refreshCursor();

    DataGridEngine* m_engine = nullptr;
    double m_contentY = 0;
    double m_contentX = 0;
    double m_rowHeight = 30;
    
    QColor m_headerColor;
    QColor m_lineColor;
    QColor m_alternateRowColor;
    QColor m_selectionColor;
    QColor m_textColor;
    QColor m_resizeGuideColor;
    
    // Selection
    int m_selectedRow = -1;
    int m_selectedCol = -1;
    
    // Header Interaction
    int m_hoveredHeaderColumn = -1;
    bool m_hoveredHeaderRow = false;
    int m_hoveredResizeColumn = -1;
    int m_hoveredRowResizeHandle = kRowResizeHandleNone;
    int m_hoveredGutterRow = -1;
    QSvgRenderer* m_primaryKeyIcon = nullptr;
    int m_sortedColumnIndex = -1;
    bool m_sortAscending = true;

    // Resize Interaction
    int m_resizingColumn = -1;
    double m_resizeStartX = 0;
    int m_resizeInitialWidth = 0;
    int m_resizingRowResizeHandle = kRowResizeHandleNone;
    double m_rowResizeStartY = 0;
    double m_rowResizeInitialHeight = 30;

    std::vector<double> m_rowHeightOverrides;
    bool m_hasRowOverrides = false;
    mutable std::vector<double> m_rowOffsets;
    mutable bool m_rowLayoutDirty = true;

    // Gutter
    double m_gutterWidth = 50;

    // UX Constraints
    int m_columnResizeHitArea = 5;
    int m_minColumnWidth = 72;
    int m_maxColumnWidth = 900;
    double m_rowResizeHitArea = 4.0;
    double m_minRowHeight = 24;
    double m_maxRowHeight = 72;
    double m_defaultRowHeight = 30;
    int m_autoFitSampleLimit = 500;
};

}
