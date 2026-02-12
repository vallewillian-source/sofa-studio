#pragma once
#include <QString>
#include <QVariant>
#include <vector>
#include <map>

namespace Sofa::Core {

enum class DataType {
    Text,
    Integer,
    Real,
    Boolean,
    Date,
    DateTime,
    Blob,
    Unknown
};

struct Column {
    QString name;
    DataType type;
    QString rawType; // original db type name
    QString defaultValue;
    QString temporalInputGroup; // "", "date", "time", "datetime"
    QString temporalNowExpression; // integration-specific current temporal expression
    bool isPrimaryKey = false;
    bool isNullable = true;
    bool isNumeric = false; // integration-defined numeric semantic
    int displayWidth = 100;
};

struct TableSchema {
    QString schema;
    QString name;
    std::vector<Column> columns;
};

struct CatalogTable {
    QString name;
    bool hasPrimaryKey = false;
};

struct DatasetRequest {
    QString cursor; // specific implementation dependent
    int limit = 100;
    int offset = 0;
    bool hasSort = false;
    QString sortColumn;
    bool sortAscending = true;
    QString filter;
};

struct DatasetPage {
    std::vector<Column> columns; // Schema for this dataset
    std::vector<std::vector<QVariant>> rows;
    QString nextCursor;
    bool hasMore = false;
    QString warning; // warnings from DB
    long long executionTimeMs = 0;
};

}
