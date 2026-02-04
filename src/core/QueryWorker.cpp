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

    QVariantList columns;
    for (const auto& col : page.columns) {
        QVariantMap colMap;
        colMap["name"] = col.name;
        colMap["type"] = col.rawType;
        columns.append(colMap);
    }
    result["columns"] = columns;

    QVariantList rows;
    for (const auto& row : page.rows) {
        QVariantList rowList;
        for (const auto& val : row) {
            rowList.append(val);
        }
        rows.append(QVariant(rowList));
    }
    result["rows"] = rows;

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

void QueryWorker::runDataset(const QVariantMap& connectionInfo, const QString& schema, const QString& table, int limit, int offset, const QString& requestTag)
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

    QString sql = QString("SELECT * FROM \"%1\".\"%2\" LIMIT %3 OFFSET %4")
                      .arg(schema).arg(table).arg(limit).arg(offset);

    DatasetRequest request;
    request.limit = limit;
    DatasetPage page = queryProvider->execute(sql, request);
    if (!page.warning.isEmpty() && page.columns.empty()) {
        emit datasetError(requestTag, page.warning);
        return;
    }

    QVariantMap result = datasetToVariant(page);
    emit datasetFinished(requestTag, result);
}

}
