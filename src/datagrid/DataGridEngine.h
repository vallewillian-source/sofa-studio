#pragma once
#include <QObject>
#include <vector>
#include <memory>
#include <QVariantMap>
#include <QVariantList>
#include <QString>
#include "udm/UDM.h"

namespace Sofa::DataGrid {

class DataGridEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(int rowCount READ rowCount NOTIFY dataChanged)
    Q_PROPERTY(int columnCount READ columnCount NOTIFY layoutChanged)
    
public:
    explicit DataGridEngine(QObject* parent = nullptr);
    
    // Data Management
    Q_INVOKABLE void loadFromVariant(const QVariantMap& data);
    void setSchema(const Sofa::Core::TableSchema& schema);
    void setData(const std::vector<std::vector<QVariant>>& rows);
    Q_INVOKABLE void clear();
    
    // Accessors
    int rowCount() const;
    int columnCount() const;
    Sofa::Core::Column getColumn(int index) const;
    int columnDisplayWidth(int index) const;
    void setColumnDisplayWidth(int index, int width);
    Q_INVOKABLE QVariant getData(int row, int col) const;
    Q_INVOKABLE QString getColumnName(int index) const;
    Q_INVOKABLE QString getColumnType(int index) const;
    Q_INVOKABLE QString getColumnDefaultValue(int index) const;
    Q_INVOKABLE QString getColumnTemporalInputGroup(int index) const;
    Q_INVOKABLE QString getColumnTemporalNowExpression(int index) const;
    Q_INVOKABLE bool getColumnIsNullable(int index) const;
    Q_INVOKABLE bool getColumnIsPrimaryKey(int index) const;
    Q_INVOKABLE QVariantList getRow(int row) const;
    
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
