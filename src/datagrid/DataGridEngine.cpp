#include "DataGridEngine.h"
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>

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
        if (raw.contains("int")) col.type = Sofa::Core::DataType::Integer;
        else if (raw.contains("bool")) col.type = Sofa::Core::DataType::Boolean;
        else col.type = Sofa::Core::DataType::Text;
        
        col.displayWidth = 150;
        schema.columns.push_back(col);
    }
    setSchema(schema);
    
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

void DataGridEngine::applyView(const QString& viewJson)
{
    if (viewJson.isEmpty()) {
        // Reset visibility/labels
        for (auto& col : m_schema.columns) {
            col.label = "";
            col.visible = true;
        }
        emit layoutChanged();
        return;
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(viewJson.toUtf8());
    if (!doc.isArray()) return;
    
    QJsonArray arr = doc.array();
    std::map<QString, QJsonObject> defMap;
    for (const auto& val : arr) {
        QJsonObject obj = val.toObject();
        defMap[obj["name"].toString()] = obj;
    }
    
    for (auto& col : m_schema.columns) {
        if (defMap.count(col.name)) {
            QJsonObject def = defMap[col.name];
            if (def.contains("label")) col.label = def["label"].toString();
            if (def.contains("visible")) col.visible = def["visible"].toBool(true);
        } else {
            // Reset to default
            col.label = "";
            col.visible = true;
        }
    }
    emit layoutChanged();
}


}
