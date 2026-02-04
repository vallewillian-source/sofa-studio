#pragma once
#include <QObject>
#include <vector>
#include <memory>
#include "udm/UDM.h"

namespace Sofa::DataGrid {

class DataGridEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(int rowCount READ rowCount NOTIFY dataChanged)
    Q_PROPERTY(int columnCount READ columnCount NOTIFY layoutChanged)
    
public:
    explicit DataGridEngine(QObject* parent = nullptr);
    
    // Data Management
    Q_INVOKABLE void loadMockData(); // Helper for Etapa 7
    void setSchema(const Sofa::Core::TableSchema& schema);
    void setData(const std::vector<std::vector<QVariant>>& rows);
    void clear();
    
    // Accessors
    int rowCount() const;
    int columnCount() const;
    Sofa::Core::Column getColumn(int index) const;
    QVariant getData(int row, int col) const;
    
    // For View
    double totalWidth() const;
    
signals:
    void dataChanged();
    void layoutChanged();
    
private:
    Sofa::Core::TableSchema m_schema;
    std::vector<std::vector<QVariant>> m_rows;
};

}
