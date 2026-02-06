#include "DataGridEngine.h"
#include <QString>
#include <QStringList>
#include <QVariantList>

namespace Sofa::DataGrid {

DataGridEngine::DataGridEngine(QObject* parent) : QObject(parent)
{
}

void DataGridEngine::setSchema(const Sofa::Core::TableSchema& schema)
{
    m_schema = schema;
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
        QString raw = col.rawType.toLower();
        
        // Heuristic for column width based on type and name
        if (raw.contains("int") || raw.contains("serial") || raw.contains("number")) {
            col.type = Sofa::Core::DataType::Integer;
            col.displayWidth = 100;
        }
        else if (raw.contains("bool")) {
            col.type = Sofa::Core::DataType::Boolean;
            col.displayWidth = 80;
        }
        else if (raw.contains("date") || raw.contains("time") || raw.contains("timestamp")) {
            col.type = Sofa::Core::DataType::DateTime;
            col.displayWidth = 180;
        }
        else if (raw.contains("json") || raw.contains("xml") || raw.contains("text")) {
             col.type = Sofa::Core::DataType::Text;
             col.displayWidth = 300; // Long text
        }
        else {
            col.type = Sofa::Core::DataType::Text;
            col.displayWidth = 150; // Default text
        }
        
        // ID/UUID special case
        if (col.name.toLower() == "id" || col.name.toLower().contains("_id")) {
             if (col.displayWidth > 120) col.displayWidth = 120; // IDs usually compact unless UUID
        }
        if (col.name.toLower() == "uuid") {
             col.displayWidth = 280;
        }
        
        schema.columns.push_back(col);
    }
    setSchema(schema);
    
    qInfo() << "\x1b[36m📏 DataGrid Layout\x1b[0m Cols:" << schema.columns.size() << "TotalWidth:" << totalWidth();
    
    QVariantList rows = data["rows"].toList();
    qInfo() << "\x1b[35m🧪 DataGrid rows payload\x1b[0m total:" << rows.size();
    std::vector<std::vector<QVariant>> newRows;
    int rowIndex = 0;
    for (const auto& r : rows) {
        QVariantList rowList = r.toList();
        std::vector<QVariant> newRow;
        for (const auto& val : rowList) {
            newRow.push_back(val);
        }
        newRows.push_back(newRow);
        
        if (rowIndex < 3) {
            QStringList debugVals;
            for (const auto& v : newRow) {
                debugVals << (QString(v.typeName()) + ":" + v.toString());
            }
            qInfo() << "\x1b[35m🧪 DataGrid row\x1b[0m" << rowIndex << "cols:" << rowList.size() << debugVals.join("|");
        }
        rowIndex++;
    }
    setData(newRows);
    qInfo() << "\x1b[32m✅ DataGrid\x1b[0m colunas:" << columns.size() << "linhas:" << rows.size() << "rowsStored:" << newRows.size();
}
}
