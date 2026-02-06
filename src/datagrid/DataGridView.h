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
    Q_PROPERTY(double totalWidth READ totalWidth NOTIFY contentSizeChanged)
    Q_PROPERTY(double rowHeight READ rowHeight WRITE setRowHeight NOTIFY rowHeightChanged)
    Q_PROPERTY(QColor headerColor READ headerColor WRITE setHeaderColor NOTIFY headerColorChanged)
    Q_PROPERTY(QColor alternateRowColor READ alternateRowColor WRITE setAlternateRowColor NOTIFY alternateRowColorChanged)
    Q_PROPERTY(QColor gridLineColor READ gridLineColor WRITE setGridLineColor NOTIFY gridLineColorChanged)
    Q_PROPERTY(QColor textColor READ textColor WRITE setTextColor NOTIFY textColorChanged)

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

    QColor gridLineColor() const { return m_lineColor; }
    void setGridLineColor(const QColor& c);

    QColor textColor() const { return m_textColor; }
    void setTextColor(const QColor& c);
    
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
    void headerColorChanged();
    void alternateRowColorChanged();
    void gridLineColorChanged();
    void textColorChanged();

private slots:
    void onEngineUpdated();

private:
    DataGridEngine* m_engine = nullptr;
    double m_contentY = 0;
    double m_contentX = 0;
    double m_rowHeight = 30;
    
    QColor m_lineColor;
    QColor m_headerColor;
    QColor m_alternateRowColor;
    QColor m_textColor;
    
    // Selection
    int m_selectedRow = -1;
    int m_selectedCol = -1;
};

}
