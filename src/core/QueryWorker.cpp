#include "QueryWorker.h"
#include <QString>

namespace Sofa::Core {

QueryWorker::QueryWorker(std::shared_ptr<AddonHost> addonHost, QObject* parent)
    : QObject(parent)
    , m_addonHost(std::move(addonHost))
{
}

QVariantMap QueryWorker::datasetToVariant(const DatasetPage& page)
{
    QVariantMap result;
    if (!page.warning.isEmpty()) {
        result["warning"] = page.warning;
    }
    result["executionTime"] = (double)page.executionTimeMs;
    result["hasMore"] = page.hasMore;

    QVariantList columns;
    for (const auto& col : page.columns) {
        QVariantMap colMap;
        colMap["name"] = col.name;
        colMap["type"] = col.rawType;
        colMap["defaultValue"] = col.defaultValue;
        colMap["temporalInputGroup"] = col.temporalInputGroup;
        colMap["temporalNowExpression"] = col.temporalNowExpression;
        colMap["isPrimaryKey"] = col.isPrimaryKey;
        colMap["isNullable"] = col.isNullable;
        colMap["isNumeric"] = col.isNumeric;
        colMap["isMultilineInput"] = col.isMultilineInput;
        columns.append(colMap);
    }
    result["columns"] = columns;

    QVariantList rows;
    QVariantList nulls;
    for (const auto& row : page.rows) {
        QVariantList rowList;
        QVariantList nullRow;
        for (const auto& val : row) {
            rowList.append(val);
            nullRow.append(val.isNull());
        }
        rows.append(QVariant(rowList));
        nulls.append(QVariant(nullRow));
    }
    result["rows"] = rows;
    result["nulls"] = nulls;

    return result;
}

QVariantMap QueryWorker::tableSchemaToVariant(const TableSchema& schema)
{
    QVariantMap result;
    result["schema"] = schema.schema;
    result["table"] = schema.name;
    result["primaryKeyConstraintName"] = schema.primaryKeyConstraintName;

    QVariantList columns;
    for (const auto& col : schema.columns) {
        QVariantMap colMap;
        colMap["name"] = col.name;
        colMap["type"] = col.rawType;
        colMap["defaultValue"] = col.defaultValue;
        colMap["temporalInputGroup"] = col.temporalInputGroup;
        colMap["temporalNowExpression"] = col.temporalNowExpression;
        colMap["isPrimaryKey"] = col.isPrimaryKey;
        colMap["isNullable"] = col.isNullable;
        colMap["isNumeric"] = col.isNumeric;
        colMap["isMultilineInput"] = col.isMultilineInput;
        columns.append(colMap);
    }
    result["columns"] = columns;
    return result;
}

void QueryWorker::runSql(const QVariantMap& connectionInfo, const QString& queryText, const QString& requestTag)
{
    if (!m_addonHost) {
        emit sqlError(requestTag, "AddonHost indisponível.");
        return;
    }
    QString driverId = connectionInfo.value("driverId").toString();
    if (!m_addonHost->hasAddon(driverId)) {
        emit sqlError(requestTag, "Driver indisponível: " + driverId);
        return;
    }
    auto addon = m_addonHost->getAddon(driverId);
    auto connection = addon->createConnection();

    QString host = connectionInfo.value("host").toString();
    int port = connectionInfo.value("port", 5432).toInt();
    QString database = connectionInfo.value("database").toString();
    QString user = connectionInfo.value("user").toString();
    QString password = connectionInfo.value("password").toString();

    if (!connection->open(host, port, database, user, password)) {
        emit sqlError(requestTag, connection->lastError());
        return;
    }
    auto queryProvider = connection->query();
    if (!queryProvider) {
        emit sqlError(requestTag, "Connection does not support queries");
        return;
    }

    int backendPid = queryProvider->backendPid();
    emit sqlStarted(requestTag, backendPid);

    DatasetRequest request;
    DatasetPage page = queryProvider->execute(queryText, request);
    if (!page.warning.isEmpty() && page.columns.empty()) {
        emit sqlError(requestTag, page.warning);
        return;
    }

    QVariantMap result = datasetToVariant(page);
    emit sqlFinished(requestTag, result);
}

void QueryWorker::runDataset(const QVariantMap& connectionInfo, const QString& schema, const QString& table, int limit, int offset, const QString& sortColumn, bool sortAscending, const QString& requestTag, const QString& filterClause)
{
    if (!m_addonHost) {
        emit datasetError(requestTag, "AddonHost indisponível.");
        return;
    }
    QString driverId = connectionInfo.value("driverId").toString();
    if (!m_addonHost->hasAddon(driverId)) {
        emit datasetError(requestTag, "Driver indisponível: " + driverId);
        return;
    }
    auto addon = m_addonHost->getAddon(driverId);
    auto connection = addon->createConnection();

    QString host = connectionInfo.value("host").toString();
    int port = connectionInfo.value("port", 5432).toInt();
    QString database = connectionInfo.value("database").toString();
    QString user = connectionInfo.value("user").toString();
    QString password = connectionInfo.value("password").toString();

    if (!connection->open(host, port, database, user, password)) {
        emit datasetError(requestTag, connection->lastError());
        return;
    }
    auto queryProvider = connection->query();
    if (!queryProvider) {
        emit datasetError(requestTag, "Query provider indisponível.");
        return;
    }

    int backendPid = queryProvider->backendPid();
    emit datasetStarted(requestTag, backendPid);

    DatasetRequest request;
    request.limit = limit;
    request.offset = offset;
    request.hasSort = !sortColumn.isEmpty();
    request.sortColumn = sortColumn;
    request.sortAscending = sortAscending;
    request.filter = filterClause;
    DatasetPage page = queryProvider->getDataset(schema, table, request);
    if (!page.warning.isEmpty() && page.columns.empty()) {
        emit datasetError(requestTag, page.warning);
        return;
    }

    QVariantMap result = datasetToVariant(page);
    emit datasetFinished(requestTag, result);
}

void QueryWorker::runTableSchema(const QVariantMap& connectionInfo, const QString& schema, const QString& table, const QString& requestTag)
{
    if (!m_addonHost) {
        emit tableSchemaError(requestTag, "AddonHost indisponível.");
        return;
    }
    QString driverId = connectionInfo.value("driverId").toString();
    if (!m_addonHost->hasAddon(driverId)) {
        emit tableSchemaError(requestTag, "Driver indisponível: " + driverId);
        return;
    }
    auto addon = m_addonHost->getAddon(driverId);
    auto connection = addon->createConnection();

    QString host = connectionInfo.value("host").toString();
    int port = connectionInfo.value("port", 5432).toInt();
    QString database = connectionInfo.value("database").toString();
    QString user = connectionInfo.value("user").toString();
    QString password = connectionInfo.value("password").toString();

    if (!connection->open(host, port, database, user, password)) {
        emit tableSchemaError(requestTag, connection->lastError());
        return;
    }

    int backendPid = -1;
    if (auto queryProvider = connection->query()) {
        backendPid = queryProvider->backendPid();
    }
    emit tableSchemaStarted(requestTag, backendPid);

    auto catalog = connection->catalog();
    if (!catalog) {
        emit tableSchemaError(requestTag, "Catalog provider indisponível.");
        return;
    }

    TableSchema ts = catalog->getTableSchema(schema, table);
    QVariantMap result = tableSchemaToVariant(ts);
    emit tableSchemaFinished(requestTag, result);
}

void QueryWorker::runCount(const QVariantMap& connectionInfo, const QString& schema, const QString& table, const QString& requestTag) {
    if (!m_addonHost) {
        // Silent error or emit error if needed, but count is often auxiliary
        return;
    }
    QString driverId = connectionInfo.value("driverId").toString();
    if (!m_addonHost->hasAddon(driverId)) {
        return;
    }
    auto addon = m_addonHost->getAddon(driverId);
    auto connection = addon->createConnection();

    QString host = connectionInfo.value("host").toString();
    int port = connectionInfo.value("port", 5432).toInt();
    QString database = connectionInfo.value("database").toString();
    QString user = connectionInfo.value("user").toString();
    QString password = connectionInfo.value("password").toString();

    if (!connection->open(host, port, database, user, password)) {
        return;
    }
    auto queryProvider = connection->query();
    if (!queryProvider) {
        return;
    }

    int total = queryProvider->count(schema, table);
    if (total != -1) {
        emit countFinished(requestTag, total);
    }
}

}
