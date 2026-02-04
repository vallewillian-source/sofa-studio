#include "DataGridEngine.h"
#include <QString>
#include <QVariantList>
#include <QDebug>

namespace Sofa::DataGrid {

DataGridEngine::DataGridEngine(QObject* parent) : QObject(parent)
{
}

void DataGridEngine::loadMockData()
{
    qInfo() << "\x1b[33m🧪 DataGrid\x1b[0m carregando dados mock";
    Sofa::Core::TableSchema schema;
    schema.name = "mock_table";
    
    Sofa::Core::Column idCol;
    idCol.name = "id";
    idCol.type = Sofa::Core::DataType::Integer;
    idCol.displayWidth = 80;
    schema.columns.push_back(idCol);

    Sofa::Core::Column nameCol;
    nameCol.name = "name";
    nameCol.type = Sofa::Core::DataType::Text;
    nameCol.displayWidth = 200;
    schema.columns.push_back(nameCol);

    Sofa::Core::Column emailCol;
    emailCol.name = "email";
    emailCol.type = Sofa::Core::DataType::Text;
    emailCol.displayWidth = 250;
    schema.columns.push_back(emailCol);
    
    setSchema(schema);

    std::vector<std::vector<QVariant>> rows;
    for (int i = 0; i < 100; ++i) {
        std::vector<QVariant> row;
        row.push_back(i + 1);
        row.push_back(QString("User %1").arg(i + 1));
        row.push_back(QString("user%1@example.com").arg(i + 1));
        rows.push_back(row);
    }
    setData(rows);
}

void DataGridEngine::setSchema(const Sofa::Core::TableSchema& schema)
{
    m_schema = schema;
    // Default widths if not set
    for (auto& col : m_schema.columns) {
        if (col.displayWidth <= 0) col.displayWidth = 150;
    }
    emit layoutChanged();
}

void DataGridEngine::setData(const std::vector<std::vector<QVariant>>& rows)
{
    m_rows = rows;
    emit dataChanged();
}

void DataGridEngine::clear()
{
    m_rows.clear();
    m_schema.columns.clear();
    emit dataChanged();
    emit layoutChanged();
}

int DataGridEngine::rowCount() const
{
    return static_cast<int>(m_rows.size());
}

int DataGridEngine::columnCount() const
{
    return static_cast<int>(m_schema.columns.size());
}

Sofa::Core::Column DataGridEngine::getColumn(int index) const
{
    if (index >= 0 && index < m_schema.columns.size()) {
        return m_schema.columns[index];
    }
    return Sofa::Core::Column();
}

QVariant DataGridEngine::getData(int row, int col) const
{
    if (row >= 0 && row < m_rows.size()) {
        const auto& r = m_rows[row];
        if (col >= 0 && col < r.size()) {
            return r[col];
        }
    }
    return QVariant();
}

double DataGridEngine::totalWidth() const
{
    double w = 0;
    for (const auto& col : m_schema.columns) {
        w += col.displayWidth;
    }
    return w;
}

void DataGridEngine::loadFromVariant(const QVariantMap& data)
{
    clear();
    
    QVariantList columns = data["columns"].toList();
    Sofa::Core::TableSchema schema;
    
    for (const auto& c : columns) {
        QVariantMap map = c.toMap();
        Sofa::Core::Column col;
        col.name = map["name"].toString();
        col.rawType = map["type"].toString();
        col.type = Sofa::Core::DataType::Text; // Simplified
        col.displayWidth = 150;
        schema.columns.push_back(col);
    }
    setSchema(schema);
    
    QVariantList rows = data["rows"].toList();
    std::vector<std::vector<QVariant>> newRows;
    for (const auto& r : rows) {
        QVariantList rowList = r.toList();
        std::vector<QVariant> newRow;
        for (const auto& val : rowList) {
            newRow.push_back(val);
        }
        newRows.push_back(newRow);
    }
    setData(newRows);
    qInfo() << "\x1b[32m✅ DataGrid\x1b[0m colunas:" << columns.size() << "linhas:" << rows.size();
}

}
