#pragma once
#include <QQuickPaintedItem>
#include <QPainter>
#include "DataGridEngine.h"

namespace Sofa::DataGrid {

class DataGridView : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(Sofa::DataGrid::DataGridEngine* engine READ engine WRITE setEngine NOTIFY engineChanged)
    Q_PROPERTY(double contentY READ contentY WRITE setContentY NOTIFY contentYChanged)
    Q_PROPERTY(double contentX READ contentX WRITE setContentX NOTIFY contentXChanged)
    Q_PROPERTY(double totalHeight READ totalHeight NOTIFY contentSizeChanged)
    Q_PROPERTY(double rowHeight READ rowHeight WRITE setRowHeight NOTIFY rowHeightChanged)

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
    
    double totalHeight() const;
    double totalWidth() const;
    
    void paint(QPainter* painter) override;

protected:
    void mousePressEvent(QMouseEvent* event) override;

signals:
    void engineChanged();
    void contentYChanged();
    void contentXChanged();
    void rowHeightChanged();
    void contentSizeChanged();

private slots:
    void onEngineUpdated();

private:
    DataGridEngine* m_engine = nullptr;
    double m_contentY = 0;
    double m_contentX = 0;
    double m_rowHeight = 30;
    
    QColor m_lineColor;
    QColor m_headerColor;
    QColor m_textColor;
    
    // Selection
    int m_selectedRow = -1;
    int m_selectedCol = -1;
};

}
