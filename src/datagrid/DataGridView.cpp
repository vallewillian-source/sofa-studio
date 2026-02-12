#include "DataGridView.h"
#include <algorithm>
#include <cmath>
#include <QCursor>
#include <QFontMetrics>
#include <QHoverEvent>
#include <QMouseEvent>
#include <QPainterPath>
#include <QPixmap>

namespace Sofa::DataGrid {

DataGridView::DataGridView(QQuickItem* parent)
    : QQuickPaintedItem(parent)
    , m_lineColor("#333333")
    , m_headerColor("#181818")
    , m_alternateRowColor(Qt::transparent)
    , m_selectionColor("#264F78")
    , m_textColor("#E0E0E0")
    , m_resizeGuideColor("#FFA507")
{
    setFlag(ItemHasContents, true);
    setClip(true);
    setAcceptedMouseButtons(Qt::LeftButton | Qt::RightButton);
    setAcceptHoverEvents(true);
    // Transparent background to let QML Theme.background show through
    setFillColor(Qt::transparent);

    m_primaryKeyIcon = new QSvgRenderer(QString(":/qt/qml/sofa/ui/assets/key-solid-full.svg"), this);
}

void DataGridView::markRowLayoutDirty()
{
    m_rowLayoutDirty = true;
}

void DataGridView::syncRowOverridesWithEngine()
{
    const int rows = m_engine ? std::max(0, m_engine->rowCount()) : 0;
    m_rowHeightOverrides.resize(rows, 0.0);
    m_hasRowOverrides = std::any_of(
        m_rowHeightOverrides.begin(),
        m_rowHeightOverrides.end(),
        [](double h) { return h > 0.1; }
    );
    markRowLayoutDirty();
}

void DataGridView::ensureRowLayoutCache() const
{
    if (!m_rowLayoutDirty) {
        return;
    }

    const int rows = m_engine ? std::max(0, m_engine->rowCount()) : 0;
    m_rowOffsets.assign(rows + 1, 0.0);

    for (int r = 0; r < rows; ++r) {
        const double overrideHeight = (r < static_cast<int>(m_rowHeightOverrides.size()))
            ? m_rowHeightOverrides[r]
            : 0.0;
        const double rowHeight = overrideHeight > 0.1 ? overrideHeight : m_rowHeight;
        m_rowOffsets[r + 1] = m_rowOffsets[r] + rowHeight;
    }

    m_rowLayoutDirty = false;
}

double DataGridView::rowHeightForRow(int row) const
{
    if (!m_engine || row < 0 || row >= m_engine->rowCount()) {
        return m_rowHeight;
    }
    ensureRowLayoutCache();
    if (row + 1 >= static_cast<int>(m_rowOffsets.size())) {
        return m_rowHeight;
    }
    return m_rowOffsets[row + 1] - m_rowOffsets[row];
}

double DataGridView::rowTopContentY(int row) const
{
    ensureRowLayoutCache();
    if (row <= 0) return 0.0;
    if (row >= static_cast<int>(m_rowOffsets.size())) {
        return m_rowOffsets.empty() ? 0.0 : m_rowOffsets.back();
    }
    return m_rowOffsets[row];
}

int DataGridView::rowAtContentY(double y) const
{
    if (!m_engine || y < 0.0) {
        return -1;
    }

    ensureRowLayoutCache();
    if (m_rowOffsets.empty()) {
        return -1;
    }

    const double total = m_rowOffsets.back();
    if (y >= total) {
        return -1;
    }

    auto it = std::upper_bound(m_rowOffsets.begin(), m_rowOffsets.end(), y);
    int row = static_cast<int>(std::distance(m_rowOffsets.begin(), it)) - 1;
    row = std::max(0, row);
    row = std::min(row, m_engine->rowCount() - 1);
    return row;
}

void DataGridView::setRowHeightForRow(int row, double height)
{
    if (!m_engine || row < 0 || row >= m_engine->rowCount()) {
        return;
    }

    const double clampedHeight = std::clamp(height, m_minRowHeight, m_maxRowHeight);
    const double storedHeight = std::abs(clampedHeight - m_rowHeight) <= 0.1 ? 0.0 : clampedHeight;

    if (row >= static_cast<int>(m_rowHeightOverrides.size())) {
        m_rowHeightOverrides.resize(m_engine->rowCount(), 0.0);
    }

    const double previousHeight = m_rowHeightOverrides[row];
    if (std::abs(previousHeight - storedHeight) <= 0.1) {
        return;
    }

    m_rowHeightOverrides[row] = storedHeight;
    if (storedHeight > 0.1) {
        m_hasRowOverrides = true;
    } else if (previousHeight > 0.1) {
        m_hasRowOverrides = std::any_of(
            m_rowHeightOverrides.begin(),
            m_rowHeightOverrides.end(),
            [](double h) { return h > 0.1; }
        );
    }

    markRowLayoutDirty();
    clampScrollOffsets();
    emit contentSizeChanged();
    update();
}

int DataGridView::columnAtPosition(double x) const
{
    if (!m_engine || x < m_gutterWidth) return -1;

    const double absoluteX = (x - m_gutterWidth) + m_contentX;
    if (absoluteX < 0) return -1;

    double currentX = 0;
    const int columnCount = m_engine->columnCount();
    for (int c = 0; c < columnCount; ++c) {
        const auto colInfo = m_engine->getColumn(c);
        const double width = std::max(1, colInfo.displayWidth);
        if (absoluteX >= currentX && absoluteX < currentX + width) {
            return c;
        }
        currentX += width;
    }
    return -1;
}

int DataGridView::columnResizeHandleAt(double x, double y) const
{
    if (!m_engine) return -1;
    if (y < 0 || y > m_rowHeight) return -1;
    if (x < m_gutterWidth) return -1;

    const double absoluteX = (x - m_gutterWidth) + m_contentX;
    if (absoluteX < 0) return -1;

    double currentX = 0;
    const int columnCount = m_engine->columnCount();
    for (int c = 0; c < columnCount; ++c) {
        const auto colInfo = m_engine->getColumn(c);
        const double width = std::max(1, colInfo.displayWidth);
        const double edgeX = currentX + width;
        if (std::abs(absoluteX - edgeX) <= m_columnResizeHitArea) {
            return c;
        }
        currentX += width;
    }
    return -1;
}

int DataGridView::rowResizeHandleAt(double x, double y) const
{
    if (!m_engine) return kRowResizeHandleNone;
    if (x < 0 || x > m_gutterWidth) return kRowResizeHandleNone;

    if (std::abs(y - m_rowHeight) <= m_rowResizeHitArea) {
        return kRowResizeHandleAll;
    }

    if (y <= m_rowHeight) {
        return kRowResizeHandleNone;
    }

    const double contentY = (y - m_rowHeight) + m_contentY;
    const int row = rowAtContentY(contentY);
    if (row < 0) {
        return kRowResizeHandleNone;
    }

    const int rowCount = m_engine->rowCount();
    const int candidates[2] = { row, row - 1 };
    for (int candidate : candidates) {
        if (candidate < 0 || candidate >= rowCount) {
            continue;
        }

        const double boundaryY = rowTopContentY(candidate + 1);
        if (std::abs(contentY - boundaryY) <= m_rowResizeHitArea) {
            return candidate;
        }
    }

    return kRowResizeHandleNone;
}

double DataGridView::columnRightX(int column) const
{
    if (!m_engine || column < 0) return -1;

    double x = m_gutterWidth - m_contentX;
    const int columnCount = m_engine->columnCount();
    for (int c = 0; c <= column && c < columnCount; ++c) {
        x += std::max(1, m_engine->getColumn(c).displayWidth);
    }
    return x;
}

QString DataGridView::cellDisplayText(int row, int column) const
{
    if (!m_engine) return QString();

    QVariant dataVal = m_engine->getData(row, column);
    bool isNull = dataVal.isNull();

    if (!isNull && dataVal.userType() == QMetaType::QString && dataVal.toString().isEmpty()) {
        const auto col = m_engine->getColumn(column);
        if (col.type != Sofa::Core::DataType::Text) {
            isNull = true;
        }
    }

    return isNull ? QStringLiteral("NULL") : dataVal.toString();
}

int DataGridView::autoFitColumnWidth(int column) const
{
    if (!m_engine || column < 0 || column >= m_engine->columnCount()) {
        return m_minColumnWidth;
    }

    QFont font;
    font.setPixelSize(12);
    QFontMetrics metrics(font);

    int contentWidth = metrics.horizontalAdvance(m_engine->getColumnName(column));
    const int rowCount = m_engine->rowCount();
    const int sampleCount = std::min(rowCount, m_autoFitSampleLimit);
    const int step = sampleCount > 0 ? std::max(1, rowCount / sampleCount) : 1;

    for (int i = 0, row = 0; i < sampleCount && row < rowCount; ++i, row += step) {
        QString text = cellDisplayText(row, column);
        if (text.size() > 256) {
            text = text.left(256);
        }
        contentWidth = std::max(contentWidth, metrics.horizontalAdvance(text));
    }

    const int padded = contentWidth + 16; // 8px left + 8px right
    return std::clamp(padded, m_minColumnWidth, m_maxColumnWidth);
}

double DataGridView::maxContentX() const
{
    return std::max(0.0, totalWidth() - width());
}

double DataGridView::maxContentY() const
{
    return std::max(0.0, totalHeight() - height());
}

void DataGridView::clampScrollOffsets()
{
    const double clampedX = std::clamp(m_contentX, 0.0, maxContentX());
    const double clampedY = std::clamp(m_contentY, 0.0, maxContentY());

    bool changed = false;
    if (std::abs(m_contentX - clampedX) > 0.1) {
        m_contentX = clampedX;
        emit contentXChanged();
        changed = true;
    }

    if (std::abs(m_contentY - clampedY) > 0.1) {
        m_contentY = clampedY;
        emit contentYChanged();
        changed = true;
    }

    if (changed) {
        update();
    }
}

void DataGridView::updateHoverState(double x, double y)
{
    if (!m_engine) {
        if (m_hoveredHeaderColumn != -1
                || m_hoveredResizeColumn != -1
                || m_hoveredRowResizeHandle != kRowResizeHandleNone) {
            m_hoveredHeaderColumn = -1;
            m_hoveredHeaderRow = false;
            m_hoveredResizeColumn = -1;
            m_hoveredRowResizeHandle = kRowResizeHandleNone;
            update();
        }
        refreshCursor();
        return;
    }

    const int previousHoveredHeader = m_hoveredHeaderColumn;
    const int previousHoveredResizeColumn = m_hoveredResizeColumn;
    const int previousHoveredRowHandle = m_hoveredRowResizeHandle;
    const bool previousHoveredHeaderRow = m_hoveredHeaderRow;

    if (m_resizingColumn != -1) {
        m_hoveredResizeColumn = m_resizingColumn;
        m_hoveredRowResizeHandle = kRowResizeHandleNone;
        m_hoveredHeaderColumn = -1;
        m_hoveredHeaderRow = false;
    } else if (m_resizingRowResizeHandle != kRowResizeHandleNone) {
        m_hoveredResizeColumn = -1;
        m_hoveredRowResizeHandle = m_resizingRowResizeHandle;
        m_hoveredHeaderColumn = -1;
        m_hoveredHeaderRow = false;
    } else {
        m_hoveredRowResizeHandle = rowResizeHandleAt(x, y);
        m_hoveredResizeColumn = m_hoveredRowResizeHandle != kRowResizeHandleNone
            ? -1
            : columnResizeHandleAt(x, y);

        if (m_hoveredResizeColumn != -1
                || m_hoveredRowResizeHandle != kRowResizeHandleNone
                || y >= m_rowHeight
                || x < m_gutterWidth) {
            m_hoveredHeaderColumn = -1;
            m_hoveredHeaderRow = false;
        } else {
            m_hoveredHeaderColumn = columnAtPosition(x);
            m_hoveredHeaderRow = true;
        }
    }

    if (previousHoveredHeader != m_hoveredHeaderColumn
            || previousHoveredResizeColumn != m_hoveredResizeColumn
            || previousHoveredRowHandle != m_hoveredRowResizeHandle
            || previousHoveredHeaderRow != m_hoveredHeaderRow) {
        update();
    }

    refreshCursor();
}

void DataGridView::refreshCursor()
{
    if (m_resizingColumn != -1 || m_hoveredResizeColumn != -1) {
        setCursor(QCursor(Qt::SplitHCursor));
        return;
    }

    if (m_resizingRowResizeHandle != kRowResizeHandleNone
            || m_hoveredRowResizeHandle != kRowResizeHandleNone) {
        setCursor(QCursor(Qt::SplitVCursor));
        return;
    }

    if (m_hoveredHeaderRow) {
        setCursor(QCursor(Qt::PointingHandCursor));
        return;
    }

    unsetCursor();
}

void DataGridView::hoverMoveEvent(QHoverEvent* event)
{
    updateHoverState(event->position().x(), event->position().y());
    QQuickPaintedItem::hoverMoveEvent(event);
}

void DataGridView::hoverLeaveEvent(QHoverEvent* event)
{
    if (m_resizingColumn == -1 && m_resizingRowResizeHandle == kRowResizeHandleNone) {
        if (m_hoveredHeaderColumn != -1
                || m_hoveredResizeColumn != -1
                || m_hoveredRowResizeHandle != kRowResizeHandleNone) {
            m_hoveredHeaderColumn = -1;
            m_hoveredHeaderRow = false;
            m_hoveredResizeColumn = -1;
            m_hoveredRowResizeHandle = kRowResizeHandleNone;
            update();
        }
    }
    refreshCursor();
    QQuickPaintedItem::hoverLeaveEvent(event);
}

void DataGridView::mousePressEvent(QMouseEvent* event)
{
    if (!m_engine) return;

    const double x = event->position().x();
    const double y = event->position().y();

    if (event->button() == Qt::LeftButton) {
        const int rowHandle = rowResizeHandleAt(x, y);
        if (rowHandle != kRowResizeHandleNone) {
            m_resizingRowResizeHandle = rowHandle;
            m_rowResizeStartY = y;
            m_rowResizeInitialHeight = (rowHandle == kRowResizeHandleAll)
                ? m_rowHeight
                : rowHeightForRow(rowHandle);
            m_hoveredHeaderColumn = -1;
            m_hoveredResizeColumn = -1;
            m_hoveredRowResizeHandle = rowHandle;
            setKeepMouseGrab(true);
            refreshCursor();
            update();
            event->accept();
            return;
        }

        const int resizeColumn = columnResizeHandleAt(x, y);
        if (resizeColumn != -1) {
            m_resizingColumn = resizeColumn;
            m_resizeStartX = x;
            m_resizeInitialWidth = std::max(1, m_engine->columnDisplayWidth(resizeColumn));
            m_hoveredHeaderColumn = -1;
            m_hoveredResizeColumn = resizeColumn;
            m_hoveredRowResizeHandle = kRowResizeHandleNone;
            setKeepMouseGrab(true);
            refreshCursor();
            update();
            event->accept();
            return;
        }
    }

    if (event->button() == Qt::RightButton) {
        if (y < m_rowHeight || x < m_gutterWidth) {
            return;
        }

        const double absoluteY = y - m_rowHeight + m_contentY;
        const int row = rowAtContentY(absoluteY);
        if (row < 0 || row >= m_engine->rowCount()) {
            return;
        }

        const int col = columnAtPosition(x);
        if (col != -1) {
            if (m_selectedRow != row || m_selectedCol != col) {
                m_selectedRow = row;
                m_selectedCol = col;
                update();
            }
            emit cellContextMenuRequested(row, col, x, y);
        }
        return;
    }

    // Check if header clicked
    if (y < m_rowHeight) {
        if (x < m_gutterWidth) return;

        const int col = columnAtPosition(x);
        if (col != -1) {
            const bool nextAscending = (m_sortedColumnIndex == col) ? !m_sortAscending : true;
            setSortedColumnIndex(col);
            setSortAscending(nextAscending);
            emit sortRequested(col, nextAscending);
            event->accept();
            return;
        }
        return;
    }

    // Calculate Row
    const double absoluteY = y - m_rowHeight + m_contentY;
    const int row = rowAtContentY(absoluteY);
    if (row < 0 || row >= m_engine->rowCount()) {
        if (m_selectedRow != -1) {
            m_selectedRow = -1;
            m_selectedCol = -1;
            update();
        }
        return;
    }

    const int col = columnAtPosition(x);
    if (col != -1) {
        if (m_selectedRow != row || m_selectedCol != col) {
            m_selectedRow = row;
            m_selectedCol = col;
            update();
        }
    }
}

void DataGridView::mouseMoveEvent(QMouseEvent* event)
{
    if (!m_engine) {
        QQuickPaintedItem::mouseMoveEvent(event);
        return;
    }

    const double x = event->position().x();
    const double y = event->position().y();

    if (m_resizingColumn != -1) {
        const int delta = static_cast<int>(std::round(x - m_resizeStartX));
        const int width = std::clamp(m_resizeInitialWidth + delta, m_minColumnWidth, m_maxColumnWidth);
        m_engine->setColumnDisplayWidth(m_resizingColumn, width);
        clampScrollOffsets();
        updateHoverState(x, y);
        event->accept();
        return;
    }

    if (m_resizingRowResizeHandle != kRowResizeHandleNone) {
        const double delta = y - m_rowResizeStartY;
        const double newHeight = std::clamp(m_rowResizeInitialHeight + delta, m_minRowHeight, m_maxRowHeight);

        if (m_resizingRowResizeHandle == kRowResizeHandleAll) {
            setRowHeight(newHeight);
        } else {
            setRowHeightForRow(m_resizingRowResizeHandle, newHeight);
        }

        updateHoverState(x, y);
        event->accept();
        return;
    }

    updateHoverState(x, y);
    QQuickPaintedItem::mouseMoveEvent(event);
}

void DataGridView::mouseReleaseEvent(QMouseEvent* event)
{
    if (event->button() == Qt::LeftButton) {
        if (m_resizingColumn != -1) {
            const int resizedColumn = m_resizingColumn;
            m_resizingColumn = -1;
            setKeepMouseGrab(false);
            clampScrollOffsets();
            updateHoverState(event->position().x(), event->position().y());
            emit columnResized(resizedColumn, m_engine ? m_engine->columnDisplayWidth(resizedColumn) : 0);
            event->accept();
            return;
        }

        if (m_resizingRowResizeHandle != kRowResizeHandleNone) {
            const int resizedHandle = m_resizingRowResizeHandle;
            m_resizingRowResizeHandle = kRowResizeHandleNone;
            setKeepMouseGrab(false);
            clampScrollOffsets();
            updateHoverState(event->position().x(), event->position().y());
            if (resizedHandle == kRowResizeHandleAll) {
                emit rowHeightResized(m_rowHeight);
            } else {
                emit rowResized(resizedHandle, rowHeightForRow(resizedHandle));
            }
            event->accept();
            return;
        }
    }

    QQuickPaintedItem::mouseReleaseEvent(event);
}

void DataGridView::mouseDoubleClickEvent(QMouseEvent* event)
{
    if (!m_engine || event->button() != Qt::LeftButton) {
        QQuickPaintedItem::mouseDoubleClickEvent(event);
        return;
    }

    const double x = event->position().x();
    const double y = event->position().y();

    const int rowHandle = rowResizeHandleAt(x, y);
    if (rowHandle != kRowResizeHandleNone) {
        if (rowHandle == kRowResizeHandleAll) {
            setRowHeight(m_defaultRowHeight);
            emit rowHeightResized(m_rowHeight);
        } else {
            // Reset this specific row to the global row height baseline.
            setRowHeightForRow(rowHandle, m_rowHeight);
            emit rowResized(rowHandle, rowHeightForRow(rowHandle));
        }
        clampScrollOffsets();
        updateHoverState(x, y);
        event->accept();
        return;
    }

    const int resizeColumn = columnResizeHandleAt(x, y);
    if (resizeColumn != -1) {
        const int width = autoFitColumnWidth(resizeColumn);
        m_engine->setColumnDisplayWidth(resizeColumn, width);
        clampScrollOffsets();
        updateHoverState(x, y);
        emit columnResized(resizeColumn, width);
        event->accept();
        return;
    }

    QQuickPaintedItem::mouseDoubleClickEvent(event);
}

void DataGridView::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    clampScrollOffsets();
    emit contentSizeChanged();
}

void DataGridView::setEngine(DataGridEngine* engine)
{
    if (m_engine == engine) return;

    if (m_engine) {
        disconnect(m_engine, nullptr, this, nullptr);
    }

    m_engine = engine;
    m_rowHeightOverrides.clear();
    m_hasRowOverrides = false;
    markRowLayoutDirty();

    if (m_engine) {
        connect(m_engine, &DataGridEngine::dataChanged, this, &DataGridView::onEngineUpdated);
        connect(m_engine, &DataGridEngine::layoutChanged, this, &DataGridView::onEngineUpdated);
    }

    emit engineChanged();
    onEngineUpdated();
}

void DataGridView::onEngineUpdated()
{
    if (!m_engine || m_sortedColumnIndex >= m_engine->columnCount()) {
        setSortedColumnIndex(-1);
    }
    syncRowOverridesWithEngine();
    clampScrollOffsets();
    emit contentSizeChanged();
    update();
}

void DataGridView::setContentY(double y)
{
    const double clampedY = std::clamp(y, 0.0, maxContentY());
    if (std::abs(m_contentY - clampedY) > 0.1) {
        m_contentY = clampedY;
        emit contentYChanged();
        update();
    }
}

void DataGridView::setContentX(double x)
{
    const double clampedX = std::clamp(x, 0.0, maxContentX());
    if (std::abs(m_contentX - clampedX) > 0.1) {
        m_contentX = clampedX;
        emit contentXChanged();
        update();
    }
}

void DataGridView::setRowHeight(double h)
{
    const double clampedHeight = std::clamp(h, m_minRowHeight, m_maxRowHeight);
    const bool baseHeightChanged = std::abs(m_rowHeight - clampedHeight) > 0.1;

    if (!baseHeightChanged && !m_hasRowOverrides) {
        return;
    }

    m_rowHeight = clampedHeight;

    if (m_hasRowOverrides && !m_rowHeightOverrides.empty()) {
        std::fill(m_rowHeightOverrides.begin(), m_rowHeightOverrides.end(), 0.0);
        m_hasRowOverrides = false;
    }

    markRowLayoutDirty();
    clampScrollOffsets();
    if (baseHeightChanged) {
        emit rowHeightChanged();
    }
    emit contentSizeChanged();
    update();
}

void DataGridView::setHeaderColor(const QColor& c)
{
    if (m_headerColor != c) {
        m_headerColor = c;
        emit headerColorChanged();
        update();
    }
}

void DataGridView::setAlternateRowColor(const QColor& c)
{
    if (m_alternateRowColor != c) {
        m_alternateRowColor = c;
        emit alternateRowColorChanged();
        update();
    }
}

void DataGridView::setSelectionColor(const QColor& c)
{
    if (m_selectionColor != c) {
        m_selectionColor = c;
        emit selectionColorChanged();
        update();
    }
}

void DataGridView::setGridLineColor(const QColor& c)
{
    if (m_lineColor != c) {
        m_lineColor = c;
        emit gridLineColorChanged();
        update();
    }
}

void DataGridView::setTextColor(const QColor& c)
{
    if (m_textColor != c) {
        m_textColor = c;
        emit textColorChanged();
        update();
    }
}

void DataGridView::setResizeGuideColor(const QColor& c)
{
    if (m_resizeGuideColor != c) {
        m_resizeGuideColor = c;
        emit resizeGuideColorChanged();
        update();
    }
}

void DataGridView::setSortedColumnIndex(int index)
{
    const int normalizedIndex = index < 0 ? -1 : index;
    if (m_sortedColumnIndex == normalizedIndex) {
        return;
    }
    m_sortedColumnIndex = normalizedIndex;
    emit sortedColumnIndexChanged();
    update();
}

void DataGridView::setSortAscending(bool ascending)
{
    if (m_sortAscending == ascending) {
        return;
    }
    m_sortAscending = ascending;
    emit sortAscendingChanged();
    update();
}

double DataGridView::totalHeight() const
{
    if (!m_engine) return 0;
    // Header + rows
    return m_rowHeight + rowTopContentY(m_engine->rowCount());
}

double DataGridView::totalWidth() const
{
    if (!m_engine) return 0;
    return m_engine->totalWidth() + m_gutterWidth;
}

void DataGridView::paint(QPainter* painter)
{
    if (!m_engine) return;

    // Geometry
    const double w = width();
    const double h = height();
    const int cols = m_engine->columnCount();
    const int rowCount = m_engine->rowCount();

    // Draw Data
    int startRow = rowAtContentY(m_contentY);
    if (startRow < 0) startRow = rowCount;
    double currentY = m_rowHeight + rowTopContentY(startRow) - m_contentY;

    painter->save();
    painter->setClipRect(m_gutterWidth, m_rowHeight, w - m_gutterWidth, h - m_rowHeight);

    QFont font = painter->font();
    font.setPixelSize(12);
    painter->setFont(font);

    for (int r = startRow; r < rowCount && currentY < h; ++r) {
        const double rowH = rowHeightForRow(r);
        double currentX = m_gutterWidth - m_contentX;

        for (int c = 0; c < cols; ++c) {
            const auto col = m_engine->getColumn(c);
            const double colW = std::max(1, col.displayWidth);

            if (currentX + colW > m_gutterWidth && currentX < w) {
                QRectF cellRect(currentX, currentY, colW, rowH);

                if (r != m_selectedRow || c != m_selectedCol) {
                    if (r % 2 == 0 && m_alternateRowColor.alpha() > 0) {
                        painter->fillRect(cellRect, m_alternateRowColor);
                    }
                }

                if (r == m_selectedRow && c == m_selectedCol) {
                    painter->save();
                    painter->setPen(Qt::NoPen);
                    painter->setBrush(m_selectionColor);
                    painter->drawRoundedRect(cellRect.adjusted(1, 1, -1, -1), 4, 4);
                    painter->restore();
                }

                painter->setPen(m_lineColor);
                painter->drawRect(cellRect);

                QVariant dataVal = m_engine->getData(r, c);
                bool isNull = dataVal.isNull();

                if (!isNull && dataVal.userType() == QMetaType::QString && dataVal.toString().isEmpty()) {
                    const auto cellColumn = m_engine->getColumn(c);
                    if (cellColumn.type != Sofa::Core::DataType::Text) {
                        isNull = true;
                    }
                }

                const QString text = isNull ? QStringLiteral("NULL") : dataVal.toString();
                QColor cellTextColor = m_textColor;

                if (r == m_selectedRow && c == m_selectedCol) {
                    cellTextColor = QColor("#000000");

                    QFont selectedFont = font;
                    selectedFont.setPixelSize(font.pixelSize() + 1);
                    painter->setFont(selectedFont);

                    if (isNull) {
                        cellTextColor.setAlphaF(0.5);
                    }
                } else {
                    cellTextColor.setAlphaF(isNull ? 0.5 : 0.9);
                    painter->setFont(font);
                }

                painter->setPen(cellTextColor);
                painter->drawText(cellRect.adjusted(8, 0, -5, 0), Qt::AlignLeft | Qt::AlignVCenter, text);
            }
            currentX += colW;
        }
        currentY += rowH;
    }

    painter->restore();

    // Draw Gutter (Row Numbers)
    painter->save();
    painter->setClipRect(0, m_rowHeight, m_gutterWidth, h - m_rowHeight);
    painter->fillRect(0, m_rowHeight, m_gutterWidth, h - m_rowHeight, m_headerColor);
    painter->setFont(font);

    currentY = m_rowHeight + rowTopContentY(startRow) - m_contentY;
    for (int r = startRow; r < rowCount && currentY < h; ++r) {
        const double rowH = rowHeightForRow(r);
        QRectF numRect(0, currentY, m_gutterWidth, rowH);

        painter->setPen(m_lineColor);
        painter->drawRect(numRect);

        painter->setPen(m_textColor);
        painter->drawText(numRect, Qt::AlignCenter, QString::number(r + 1));
        currentY += rowH;
    }
    painter->restore();

    // Draw Header (Sticky)
    painter->save();
    painter->setClipRect(m_gutterWidth, 0, w - m_gutterWidth, m_rowHeight);
    painter->fillRect(m_gutterWidth, 0, w - m_gutterWidth, m_rowHeight, m_headerColor);

    double currentX = m_gutterWidth - m_contentX;
    for (int c = 0; c < cols; ++c) {
        const auto col = m_engine->getColumn(c);
        const double colW = std::max(1, col.displayWidth);

        if (currentX + colW > m_gutterWidth && currentX < w) {
            QRectF cellRect(currentX, 0, colW, m_rowHeight);

            painter->setPen(m_lineColor);
            painter->drawRect(cellRect);

            QRectF textRect = cellRect.adjusted(8, 0, -5, 0);
            if (col.isPrimaryKey && m_primaryKeyIcon && m_primaryKeyIcon->isValid()) {
                const int pkIconSize = 11;
                const int pkPaddingLeft = 8;
                const int pkGap = 4;
                if (colW > pkIconSize + (pkPaddingLeft + pkGap + 10)) {
                    const double iconX = cellRect.left() + pkPaddingLeft;
                    const double iconY = 4.0;
                    QRectF pkIconRect(iconX, iconY, pkIconSize, pkIconSize);

                    QPixmap iconPixmap(pkIconSize, pkIconSize);
                    iconPixmap.fill(Qt::transparent);

                    QPainter iconPainter(&iconPixmap);
                    m_primaryKeyIcon->render(&iconPainter, QRectF(0, 0, pkIconSize, pkIconSize));
                    iconPainter.setCompositionMode(QPainter::CompositionMode_SourceIn);
                    QColor pkColor = m_resizeGuideColor;
                    pkColor.setAlphaF(0.7);
                    iconPainter.fillRect(iconPixmap.rect(), pkColor);
                    iconPainter.end();

                    painter->drawPixmap(pkIconRect.topLeft(), iconPixmap);
                    textRect.setLeft(pkIconRect.right() + pkGap);
                }
            }

            const bool isSortedColumn = m_sortedColumnIndex == c;
            const bool isHoveredHeader = m_hoveredHeaderRow && m_hoveredHeaderColumn == c;
            const bool showSortIndicator = isSortedColumn || isHoveredHeader;
            const bool ascendingForColumn = isSortedColumn ? m_sortAscending : true;
            QRectF sortRect;
            bool hasSortRect = false;
            if (showSortIndicator) {
                const int arrowSize = 8;
                const int arrowPaddingRight = 8;
                const int arrowGap = 6;
                if (colW > arrowSize + arrowPaddingRight + arrowGap + 20) {
                    const double arrowX = cellRect.right() - arrowPaddingRight - arrowSize;
                    const double arrowY = (m_rowHeight - arrowSize) / 2.0;
                    sortRect = QRectF(arrowX, arrowY, arrowSize, arrowSize);
                    textRect.setRight(sortRect.left() - arrowGap);
                    hasSortRect = true;
                }
            }

            QFont headerNameFont = font;
            headerNameFont.setBold(true);
            headerNameFont.setPixelSize(12);
            painter->setFont(headerNameFont);
            painter->setPen(m_textColor);

            QRectF nameRect = textRect;
            nameRect.setTop(cellRect.top() + 2);
            nameRect.setBottom(cellRect.top() + (m_rowHeight / 2.0) + 2);

            QFontMetrics nameMetrics(headerNameFont);
            const QString displayName = nameMetrics.elidedText(col.name, Qt::ElideRight, std::max(1, static_cast<int>(nameRect.width())));
            painter->drawText(nameRect, Qt::AlignLeft | Qt::AlignVCenter, displayName);

            QFont typeFont = font;
            typeFont.setBold(false);
            typeFont.setPixelSize(9);
            painter->setFont(typeFont);

            QColor typeColor = m_textColor;
            typeColor.setAlphaF(0.55);
            painter->setPen(typeColor);

            QRectF typeRect = textRect;
            typeRect.setTop(cellRect.top() + (m_rowHeight / 2.0) - 1);
            typeRect.setBottom(cellRect.bottom() - 2);

            QString typeText = col.rawType.trimmed();
            if (typeText.isEmpty()) {
                typeText = "unknown";
            }

            QFontMetrics typeMetrics(typeFont);
            const QString displayType = typeMetrics.elidedText(typeText, Qt::ElideRight, std::max(1, static_cast<int>(typeRect.width())));
            painter->drawText(typeRect, Qt::AlignLeft | Qt::AlignVCenter, displayType);

            if (hasSortRect) {
                qreal arrowOpacity = 0.45;
                if (isSortedColumn && isHoveredHeader) {
                    arrowOpacity = 1.0;
                } else if (isSortedColumn) {
                    arrowOpacity = 0.9;
                }

                QColor arrowColor = m_resizeGuideColor;
                arrowColor.setAlphaF(arrowOpacity);
                painter->setPen(Qt::NoPen);
                painter->setBrush(arrowColor);

                QPainterPath arrowPath;
                if (ascendingForColumn) {
                    arrowPath.moveTo(sortRect.center().x(), sortRect.top());
                    arrowPath.lineTo(sortRect.right(), sortRect.bottom());
                    arrowPath.lineTo(sortRect.left(), sortRect.bottom());
                } else {
                    arrowPath.moveTo(sortRect.left(), sortRect.top());
                    arrowPath.lineTo(sortRect.right(), sortRect.top());
                    arrowPath.lineTo(sortRect.center().x(), sortRect.bottom());
                }
                arrowPath.closeSubpath();
                painter->drawPath(arrowPath);
            }
        }
        currentX += colW;
    }
    painter->restore();

    // Draw Corner (Top-Left)
    const QRectF cornerRect(0, 0, m_gutterWidth, m_rowHeight);
    painter->fillRect(cornerRect, m_headerColor);
    painter->setPen(m_lineColor);
    painter->drawRect(cornerRect);

    // Row-height grip hint in the corner for discoverability.
    painter->save();
    QColor gripColor = m_textColor;
    gripColor.setAlphaF(
        m_hoveredRowResizeHandle != kRowResizeHandleNone
            || m_resizingRowResizeHandle != kRowResizeHandleNone
            ? 0.65
            : 0.25
    );
    painter->setPen(QPen(gripColor, 1));
    const double cx = m_gutterWidth / 2.0;
    const double y1 = m_rowHeight - 8;
    painter->drawLine(QPointF(cx - 6, y1), QPointF(cx + 6, y1));
    painter->drawLine(QPointF(cx - 4, y1 + 3), QPointF(cx + 4, y1 + 3));
    painter->restore();

    // Resize guides
    painter->save();
    QColor guideColor = m_resizeGuideColor;
    guideColor.setAlphaF(0.2);
    painter->setPen(QPen(guideColor, 1));

    int guideColumn = -1;
    if (m_resizingColumn != -1) {
        guideColumn = m_resizingColumn;
    } else if (m_hoveredResizeColumn != -1) {
        guideColumn = m_hoveredResizeColumn;
    } else if (m_hoveredHeaderColumn != -1) {
        guideColumn = m_hoveredHeaderColumn;
    }

    if (guideColumn != -1) {
        const double guideX = columnRightX(guideColumn);
        if (guideX >= m_gutterWidth && guideX <= w) {
            painter->drawLine(QPointF(guideX, 0), QPointF(guideX, h));
        }
    }

    const int rowResizeHandle = m_resizingRowResizeHandle != kRowResizeHandleNone
        ? m_resizingRowResizeHandle
        : m_hoveredRowResizeHandle;
    if (rowResizeHandle != kRowResizeHandleNone) {
        double guideY = m_rowHeight;
        if (rowResizeHandle >= 0) {
            guideY = m_rowHeight + rowTopContentY(rowResizeHandle + 1) - m_contentY;
        }

        if (guideY >= 0 && guideY <= h) {
            painter->drawLine(QPointF(0, guideY), QPointF(w, guideY));
        }
    }
    painter->restore();
}

}
