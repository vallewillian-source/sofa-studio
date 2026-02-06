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
    bool isPrimaryKey = false;
    bool isNullable = true;
    int displayWidth = 100;
};

struct TableSchema {
    QString schema;
    QString name;
    std::vector<Column> columns;
};

struct DatasetRequest {
    QString cursor; // specific implementation dependent
    int limit = 100;
    // Simple sort for now: "column ASC" or "column DESC"
    QString sort;
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
