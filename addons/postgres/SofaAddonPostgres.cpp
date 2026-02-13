#include "SofaAddonPostgres.h"
#include <QUuid>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QSqlField>
#include <QDebug>
#include <QDateTime>
#include <QHash>
#include <QSet>

namespace Sofa::Addons::Postgres {
namespace {
QString temporalInputGroupFromPostgresType(const QString& rawType)
{
    const QString t = rawType.trimmed().toLower();
    if (t == "date") {
        return QStringLiteral("date");
    }
    if (t == "time" || t == "timetz") {
        return QStringLiteral("time");
    }
    if (t == "timestamp" || t == "timestamptz") {
        return QStringLiteral("datetime");
    }
    return QString();
}

QString temporalNowExpressionForGroup(const QString& group)
{
    if (group == "date") {
        return QStringLiteral("CURRENT_DATE");
    }
    if (group == "time") {
        return QStringLiteral("CURRENT_TIME");
    }
    if (group == "datetime") {
        return QStringLiteral("NOW()");
    }
    return QString();
}

bool isNumericPostgresType(const QString& rawType)
{
    const QString t = rawType.trimmed().toLower();
    return t == "int2"
        || t == "int4"
        || t == "int8"
        || t == "smallint"
        || t == "integer"
        || t == "bigint"
        || t == "float4"
        || t == "float8"
        || t == "real"
        || t == "double precision"
        || t == "numeric"
        || t == "decimal"
        || t == "money";
}

bool isMultilineInputPostgresType(const QString& rawType)
{
    const QString t = rawType.trimmed().toLower();
    return t == "text"
        || t == "json"
        || t == "jsonb"
        || t == "hstore"
        || t == "array"
        || t.endsWith("[]")
        || t.startsWith("_");
}
}

// --- PostgresConnection ---

PostgresConnection::PostgresConnection() {
}

PostgresConnection::~PostgresConnection() {
    close();
}

bool PostgresConnection::testConnection(const QString& host, int port, const QString& db, const QString& user, const QString& password) {
    QString testConnName = "postgres_test_" + QUuid::createUuid().toString();
    bool success = false;
    {
        QSqlDatabase database = QSqlDatabase::addDatabase("QPSQL", testConnName);
        database.setHostName(host);
        database.setPort(port);
        database.setDatabaseName(db);
        database.setUserName(user);
        database.setPassword(password);

        success = database.open();
        if (!success) {
            m_lastError = database.lastError().text();
        } else {
            database.close();
        }
    }
    QSqlDatabase::removeDatabase(testConnName);
    return success;
}

bool PostgresConnection::open(const QString& host, int port, const QString& db, const QString& user, const QString& password) {
    close(); // Close existing if any

    m_connectionName = "postgres_session_" + QUuid::createUuid().toString();
    bool success = false;
    {
        QSqlDatabase database = QSqlDatabase::addDatabase("QPSQL", m_connectionName);
        database.setHostName(host);
        database.setPort(port);
        database.setDatabaseName(db);
        database.setUserName(user);
        database.setPassword(password);

        success = database.open();
        if (!success) {
            m_lastError = database.lastError().text();
        }
    }

    if (!success) {
        QSqlDatabase::removeDatabase(m_connectionName);
        m_connectionName.clear();
        return false;
    }

    m_catalog = std::make_shared<PostgresCatalogProvider>(m_connectionName);
    m_query = std::make_shared<PostgresQueryProvider>(m_connectionName);
    
    return true;
}

void PostgresConnection::close() {
    if (!m_connectionName.isEmpty()) {
        {
            QSqlDatabase db = QSqlDatabase::database(m_connectionName);
            if (db.isOpen()) {
                db.close();
            }
        }
        QSqlDatabase::removeDatabase(m_connectionName);
        m_connectionName.clear();
        m_catalog.reset();
        m_query.reset();
    }
}

bool PostgresConnection::isOpen() const {
    if (m_connectionName.isEmpty()) return false;
    return QSqlDatabase::database(m_connectionName).isOpen();
}

QString PostgresConnection::lastError() const {
    return m_lastError;
}

std::shared_ptr<ICatalogProvider> PostgresConnection::catalog() {
    return m_catalog;
}

std::shared_ptr<IQueryProvider> PostgresConnection::query() {
    return m_query;
}

// --- PostgresCatalogProvider ---

PostgresCatalogProvider::PostgresCatalogProvider(const QString& connectionName) 
    : m_connectionName(connectionName) {}

std::vector<QString> PostgresCatalogProvider::listSchemas() {
    std::vector<QString> schemas;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) return schemas;

    QSqlQuery q(db);
    if (q.exec("SELECT schema_name FROM information_schema.schemata ORDER BY schema_name")) {
        while (q.next()) {
            schemas.push_back(q.value(0).toString());
        }
    }
    return schemas;
}

std::vector<QString> PostgresCatalogProvider::listHiddenSchemas() {
    return { "information_schema", "pg_catalog", "pg_toast" };
}

std::vector<CatalogTable> PostgresCatalogProvider::listTables(const QString& schema) {
    std::vector<CatalogTable> tables;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) return tables;

    QSqlQuery q(db);
    q.prepare(
        "SELECT t.table_name, "
        "       EXISTS ("
        "           SELECT 1"
        "           FROM information_schema.table_constraints tc"
        "           WHERE tc.table_schema = t.table_schema"
        "             AND tc.table_name = t.table_name"
        "             AND tc.constraint_type = 'PRIMARY KEY'"
        "       ) AS has_primary_key "
        "FROM information_schema.tables t "
        "WHERE t.table_schema = :schema "
        "ORDER BY t.table_name"
    );
    q.bindValue(":schema", schema);
    if (q.exec()) {
        while (q.next()) {
            CatalogTable table;
            table.name = q.value(0).toString();
            table.hasPrimaryKey = q.value(1).toBool();
            tables.push_back(table);
        }
    }
    return tables;
}

TableSchema PostgresCatalogProvider::getTableSchema(const QString& schema, const QString& table) {
    TableSchema ts;
    ts.name = table;
    ts.schema = schema;

    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) return ts;

    QSqlQuery columnsQuery(db);
    columnsQuery.prepare(
        "SELECT column_name, udt_name, is_nullable, column_default "
        "FROM information_schema.columns "
        "WHERE table_schema = :schema AND table_name = :table "
        "ORDER BY ordinal_position"
    );
    columnsQuery.bindValue(":schema", schema);
    columnsQuery.bindValue(":table", table);

    if (columnsQuery.exec()) {
        while (columnsQuery.next()) {
            Column col;
            col.name = columnsQuery.value(0).toString();
            col.rawType = columnsQuery.value(1).toString();
            const QString nullableRaw = columnsQuery.value(2).toString().trimmed().toUpper();
            col.isNullable = (nullableRaw == "YES");
            col.defaultValue = columnsQuery.value(3).toString();

            const QString typeStr = col.rawType.trimmed().toLower();
            if (typeStr.contains("int")) col.type = DataType::Integer;
            else if (typeStr.contains("float") || typeStr.contains("double") || typeStr == "numeric" || typeStr == "decimal") col.type = DataType::Real;
            else if (typeStr.contains("bool")) col.type = DataType::Boolean;
            else col.type = DataType::Text;

            col.isNumeric = isNumericPostgresType(col.rawType);
            col.isMultilineInput = isMultilineInputPostgresType(col.rawType);
            col.temporalInputGroup = temporalInputGroupFromPostgresType(col.rawType);
            col.temporalNowExpression = temporalNowExpressionForGroup(col.temporalInputGroup);

            ts.columns.push_back(col);
        }
    }

    QSqlQuery pkQuery(db);
    pkQuery.prepare(
        "SELECT tc.constraint_name, kcu.column_name "
        "FROM information_schema.table_constraints tc "
        "JOIN information_schema.key_column_usage kcu "
        "  ON tc.constraint_name = kcu.constraint_name "
        " AND tc.table_schema = kcu.table_schema "
        " AND tc.table_name = kcu.table_name "
        "WHERE tc.constraint_type = 'PRIMARY KEY' "
        "  AND tc.table_schema = :schema "
        "  AND tc.table_name = :table "
        "ORDER BY kcu.ordinal_position"
    );
    pkQuery.bindValue(":schema", schema);
    pkQuery.bindValue(":table", table);

    QSet<QString> primaryKeyColumns;
    if (pkQuery.exec()) {
        while (pkQuery.next()) {
            if (ts.primaryKeyConstraintName.isEmpty()) {
                ts.primaryKeyConstraintName = pkQuery.value(0).toString();
            }
            primaryKeyColumns.insert(pkQuery.value(1).toString());
        }
    }

    for (auto& col : ts.columns) {
        col.isPrimaryKey = primaryKeyColumns.contains(col.name);
    }
    return ts;
}

// --- PostgresQueryProvider ---

PostgresQueryProvider::PostgresQueryProvider(const QString& connectionName)
    : m_connectionName(connectionName) {}

DatasetPage PostgresQueryProvider::execute(const QString& queryStr, const DatasetRequest& request) {
    DatasetPage page;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    
    if (!db.isOpen()) {
        qWarning() << "\x1b[31m❌ PG\x1b[0m conexão não está aberta";
        page.warning = "Connection is not open";
        return page;
    }

    qint64 startTime = QDateTime::currentMSecsSinceEpoch();

    QSqlQuery q(db);
    // Note: ForwardOnly is default and more efficient.
    qInfo() << "\x1b[36m🔎 PG\x1b[0m query:" << queryStr;
    
    bool success = q.exec(queryStr);
    
    if (!success) {
        qWarning() << "\x1b[31m❌ PG\x1b[0m erro ao executar query:" << q.lastError().text();
        page.warning = q.lastError().text();
        return page;
    }

    // Read headers
    QSqlRecord record = q.record();
    for (int i = 0; i < record.count(); i++) {
        Column col;
        col.name = record.fieldName(i);
        QMetaType::Type type = static_cast<QMetaType::Type>(record.field(i).metaType().id());
        
        // Simple mapping from QMetaType
        if (type == QMetaType::Int || type == QMetaType::LongLong) col.type = DataType::Integer;
        else if (type == QMetaType::Double || type == QMetaType::Float) col.type = DataType::Real;
        else if (type == QMetaType::Bool) col.type = DataType::Boolean;
        else col.type = DataType::Text;
        col.isNumeric = (type == QMetaType::Int
                         || type == QMetaType::UInt
                         || type == QMetaType::LongLong
                         || type == QMetaType::ULongLong
                         || type == QMetaType::Double
                         || type == QMetaType::Float);
        
        col.rawType = record.field(i).metaType().name();
        page.columns.push_back(col);
    }

    // Read rows with limit
    int count = 0;
    // request.limit default is 100
    int limit = request.limit > 0 ? request.limit : 100;
    
    while (q.next()) {
        if (count >= limit) {
            page.hasMore = true;
            break;
        }
        
        std::vector<QVariant> row;
        QStringList debugVals;
        for (int i = 0; i < record.count(); i++) {
            QVariant v = q.value(i);
            row.push_back(v);
            if (count < 3) {
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
        }
        if (count < 3) {
            qInfo() << "\x1b[35m🧪 PG row\x1b[0m" << count << "cols:" << record.count() << debugVals.join(" | ");
        }
        page.rows.push_back(row);
        count++;
    }

    page.executionTimeMs = QDateTime::currentMSecsSinceEpoch() - startTime;
    qInfo() << "\x1b[32m✅ PG\x1b[0m colunas:" << page.columns.size() << "linhas:" << page.rows.size() << "ms:" << page.executionTimeMs;
    return page;
}

DatasetPage PostgresQueryProvider::getDataset(const QString& schema, const QString& table, const DatasetRequest& request) {
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) {
        DatasetPage page;
        page.warning = "Connection is not open";
        return page;
    }

    DatasetRequest req = request;
    int limit = req.limit > 0 ? req.limit : 100;
    int offset = req.offset > 0 ? req.offset : 0;
    int sqlLimit = limit + 1;
    req.limit = limit;

    QSqlQuery typeQuery(db);
    typeQuery.prepare(
        "SELECT column_name, udt_name, is_nullable, column_default "
        "FROM information_schema.columns "
        "WHERE table_schema = :schema "
        "  AND table_name = :table"
    );
    typeQuery.bindValue(":schema", schema);
    typeQuery.bindValue(":table", table);

    QHash<QString, QString> sqlTypeByColumn;
    QHash<QString, bool> isNullableByColumn;
    QHash<QString, QString> defaultValueByColumn;
    if (typeQuery.exec()) {
        while (typeQuery.next()) {
            sqlTypeByColumn.insert(typeQuery.value(0).toString(), typeQuery.value(1).toString());
            const QString nullableRaw = typeQuery.value(2).toString().trimmed().toUpper();
            isNullableByColumn.insert(typeQuery.value(0).toString(), nullableRaw == "YES");
            defaultValueByColumn.insert(typeQuery.value(0).toString(), typeQuery.value(3).toString());
        }
    }

    auto quoteIdentifier = [](const QString& identifier) {
        return QString("\"%1\"").arg(QString(identifier).replace("\"", "\"\""));
    };

    QString sql = QString("SELECT * FROM %1.%2")
                      .arg(quoteIdentifier(schema), quoteIdentifier(table));

    const QString filterClause = req.filter.trimmed();
    if (!filterClause.isEmpty()) {
        sql += QString(" WHERE %1").arg(filterClause);
    }

    if (req.hasSort && !req.sortColumn.isEmpty() && sqlTypeByColumn.contains(req.sortColumn)) {
        sql += QString(" ORDER BY %1 %2")
            .arg(quoteIdentifier(req.sortColumn), req.sortAscending ? "ASC" : "DESC");
    }

    sql += QString(" LIMIT %1 OFFSET %2").arg(sqlLimit).arg(offset);
    DatasetPage page = execute(sql, req);

    if (page.columns.empty()) {
        return page;
    }

    QSqlQuery pkQuery(db);
    pkQuery.prepare(
        "SELECT kcu.column_name "
        "FROM information_schema.table_constraints tc "
        "JOIN information_schema.key_column_usage kcu "
        "  ON tc.constraint_name = kcu.constraint_name "
        " AND tc.table_schema = kcu.table_schema "
        " AND tc.table_name = kcu.table_name "
        "WHERE tc.constraint_type = 'PRIMARY KEY' "
        "  AND tc.table_schema = :schema "
        "  AND tc.table_name = :table"
    );
    pkQuery.bindValue(":schema", schema);
    pkQuery.bindValue(":table", table);

    QSet<QString> primaryKeyColumns;
    if (pkQuery.exec()) {
        while (pkQuery.next()) {
            primaryKeyColumns.insert(pkQuery.value(0).toString());
        }
    }

    for (auto& col : page.columns) {
        col.isPrimaryKey = primaryKeyColumns.contains(col.name);
        const QString sqlType = sqlTypeByColumn.value(col.name);
        if (!sqlType.isEmpty()) {
            col.rawType = sqlType;
        }
        if (isNullableByColumn.contains(col.name)) {
            col.isNullable = isNullableByColumn.value(col.name);
        }
        if (defaultValueByColumn.contains(col.name)) {
            col.defaultValue = defaultValueByColumn.value(col.name);
        }
        col.isNumeric = isNumericPostgresType(col.rawType);
        col.isMultilineInput = isMultilineInputPostgresType(col.rawType);
        col.temporalInputGroup = temporalInputGroupFromPostgresType(col.rawType);
        col.temporalNowExpression = temporalNowExpressionForGroup(col.temporalInputGroup);
    }

    return page;
}

int PostgresQueryProvider::count(const QString& schema, const QString& table) {
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) {
        return -1;
    }
    
    QString sql = QString("SELECT COUNT(*) FROM \"%1\".\"%2\"").arg(schema).arg(table);
    QSqlQuery q(db);
    if (q.exec(sql) && q.next()) {
        return q.value(0).toInt();
    }
    
    qWarning() << "Count failed:" << q.lastError().text();
    return -1;
}

int PostgresQueryProvider::backendPid() {
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) {
        return -1;
    }
    QSqlQuery q(db);
    if (q.exec("SELECT pg_backend_pid()") && q.next()) {
        return q.value(0).toInt();
    }
    return -1;
}

bool PostgresConnection::cancelQuery(int backendPid) {
    if (backendPid <= 0) return false;
    if (m_connectionName.isEmpty()) return false;
    QSqlDatabase db = QSqlDatabase::database(m_connectionName);
    if (!db.isOpen()) return false;
    QSqlQuery q(db);
    q.prepare("SELECT pg_cancel_backend(:pid)");
    q.bindValue(":pid", backendPid);
    if (!q.exec()) {
        m_lastError = q.lastError().text();
        return false;
    }
    if (q.next()) {
        return q.value(0).toBool();
    }
    return false;
}

// --- PostgresAddon ---

std::shared_ptr<IConnectionProvider> PostgresAddon::createConnection() {
    return std::make_shared<PostgresConnection>();
}

}
