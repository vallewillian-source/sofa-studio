#include "DataGridEngine.h"
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QJsonValue>
#include <QDebug>
#include <algorithm>

namespace Sofa::DataGrid {
namespace {
QString fallbackTypeLabel(Sofa::Core::DataType type)
{
    switch (type) {
    case Sofa::Core::DataType::Text:
        return QStringLiteral("text");
    case Sofa::Core::DataType::Integer:
        return QStringLiteral("integer");
    case Sofa::Core::DataType::Real:
        return QStringLiteral("real");
    case Sofa::Core::DataType::Boolean:
        return QStringLiteral("boolean");
    case Sofa::Core::DataType::Date:
        return QStringLiteral("date");
    case Sofa::Core::DataType::DateTime:
        return QStringLiteral("datetime");
    case Sofa::Core::DataType::Blob:
        return QStringLiteral("blob");
    case Sofa::Core::DataType::Unknown:
    default:
        return QStringLiteral("unknown");
    }
}
}

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

int DataGridEngine::columnDisplayWidth(int index) const
{
    if (index >= 0 && index < m_schema.columns.size()) {
        return m_schema.columns[index].displayWidth;
    }
    return 0;
}

void DataGridEngine::setColumnDisplayWidth(int index, int width)
{
    if (index < 0 || index >= m_schema.columns.size()) {
        return;
    }

    const int clampedWidth = std::max(1, width);
    if (m_schema.columns[index].displayWidth == clampedWidth) {
        return;
    }

    m_schema.columns[index].displayWidth = clampedWidth;
    emit layoutChanged();
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

QString DataGridEngine::getColumnName(int index) const
{
    if (index >= 0 && index < m_schema.columns.size()) {
        return m_schema.columns[index].name;
    }
    return QString();
}

QString DataGridEngine::getColumnType(int index) const
{
    if (index >= 0 && index < m_schema.columns.size()) {
        const auto& column = m_schema.columns[index];
        const QString rawType = column.rawType.trimmed();
        if (!rawType.isEmpty()) {
            return rawType;
        }
        return fallbackTypeLabel(column.type);
    }
    return QString();
}

QVariantList DataGridEngine::getRow(int row) const
{
    QVariantList list;
    if (row >= 0 && row < m_rows.size()) {
        const auto& r = m_rows[row];
        for (const auto& val : r) {
            list.append(val);
        }
    }
    return list;
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
        col.isPrimaryKey = map["isPrimaryKey"].toBool();
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
    QVariantList nulls = data["nulls"].toList();
    qInfo() << "\x1b[35m🧪 DataGrid rows payload\x1b[0m total:" << rows.size();
    std::vector<std::vector<QVariant>> newRows;
    int rowIndex = 0;
    for (const auto& r : rows) {
        QVariantList rowList = r.toList();
        QVariantList nullRowList;
        if (rowIndex < nulls.size()) {
            nullRowList = nulls[rowIndex].toList();
        }
        std::vector<QVariant> newRow;
        int colIndex = 0;
        for (const auto& val : rowList) {
            QVariant finalVal = val;
            if (colIndex < nullRowList.size() && nullRowList[colIndex].toBool()) {
                finalVal = QVariant();
            } else if (val.userType() == QMetaType::QJsonValue) {
                QJsonValue jv = val.toJsonValue();
                if (jv.isNull() || jv.isUndefined()) {
                    finalVal = QVariant();
                } else {
                    finalVal = jv.toVariant();
                }
            }
            newRow.push_back(finalVal);
            colIndex++;
        }
        newRows.push_back(newRow);
        
        if (rowIndex < 3) {
            QStringList debugVals;
            for (const auto& v : newRow) {
                QString valStr = v.toString();
                QString display;
                if (v.isNull()) display = "NULL";
                else if (valStr.isEmpty()) display = "EMPTY";
                else if (v.userType() == QMetaType::QString && valStr.trimmed().isEmpty()) display = "WHITESPACE";
                else display = valStr;
                QString suffix;
                if (v.userType() == QMetaType::QString) {
                    suffix = " len=" + QString::number(valStr.size());
                }
                debugVals << (QString(v.typeName()) + "(" + (v.isNull() ? "null" : "valid") + "):" + display + suffix);
            }
            qInfo() << "\x1b[35m🧪 DataGrid row\x1b[0m" << rowIndex << "cols:" << rowList.size() << debugVals.join(" | ");
        }
        rowIndex++;
    }
    setData(newRows);
    qInfo() << "\x1b[32m✅ DataGrid\x1b[0m colunas:" << columns.size() << "linhas:" << rows.size() << "rowsStored:" << newRows.size();
}
}
