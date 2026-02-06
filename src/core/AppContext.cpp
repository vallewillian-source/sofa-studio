#include "AppContext.h"
#include <QVariantMap>
#include <QStringList>
#include <QJsonDocument>
#include <QSet>
#include "addons/IAddon.h"
#include "udm/UDM.h"

namespace Sofa::Core {

AppContext::AppContext(std::shared_ptr<ICommandService> commandService,
                       std::shared_ptr<ILogger> logger,
                       std::shared_ptr<ILocalStoreService> localStore,
                       std::shared_ptr<ISecretsService> secrets,
                       std::shared_ptr<AddonHost> addonHost,
                       QObject* parent)
    : QObject(parent)
    , m_commandService(std::move(commandService))
    , m_logger(std::move(logger))
    , m_localStore(std::move(localStore))
    , m_secrets(std::move(secrets))
    , m_addonHost(std::move(addonHost))
{
    if (m_localStore) {
        m_localStore->init();
    }

    m_worker = new QueryWorker(m_addonHost);
    m_worker->moveToThread(&m_workerThread);
    connect(&m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(m_worker, &QueryWorker::sqlStarted, this, &AppContext::handleSqlStarted);
    connect(m_worker, &QueryWorker::sqlFinished, this, &AppContext::handleSqlFinished);
    connect(m_worker, &QueryWorker::sqlError, this, &AppContext::handleSqlError);
    connect(m_worker, &QueryWorker::datasetStarted, this, &AppContext::handleDatasetStarted);
    connect(m_worker, &QueryWorker::datasetFinished, this, &AppContext::handleDatasetFinished);
    connect(m_worker, &QueryWorker::datasetError, this, &AppContext::handleDatasetError);
    connect(m_worker, &QueryWorker::countFinished, this, &AppContext::handleCountFinished);
    
    m_workerThread.start();
}

AppContext::~AppContext()
{
    if (m_workerThread.isRunning()) {
        m_workerThread.quit();
        m_workerThread.wait();
    }
}

void AppContext::executeCommand(const QString& id)
{
    if (m_commandService) {
        m_commandService->execute(id);
    } else if (m_logger) {
        m_logger->error("CommandService is not available");
    }
}

void AppContext::clearLastError()
{
    setLastError("");
}

void AppContext::setLastError(const QString& error)
{
    if (m_lastError == error) return;
    m_lastError = error;
    emit lastErrorChanged();
}

QVariantList AppContext::connections() const
{
    QVariantList list;
    if (!m_localStore) return list;

    auto connections = m_localStore->getAllConnections();
    for (const auto& conn : connections) {
        QVariantMap map;
        map["id"] = conn.id;
        map["name"] = conn.name;
        map["host"] = conn.host;
        map["port"] = conn.port;
        map["database"] = conn.database;
        map["user"] = conn.user;
        map["color"] = conn.color;
        map["createdAt"] = conn.createdAt;
        map["updatedAt"] = conn.updatedAt;
        list.append(map);
    }
    return list;
}

int AppContext::saveConnection(const QVariantMap& data)
{
    if (!m_localStore) return false;

    ConnectionData conn;
    conn.id = data.value("id", -1).toInt();
    conn.name = data.value("name").toString();
    conn.host = data.value("host").toString();
    conn.port = data.value("port", 5432).toInt();
    conn.database = data.value("database").toString();
    conn.user = data.value("user").toString();
    conn.color = data.value("color").toString();
    
    // Handle secret if present (simple pass-through for now)
    QString password = data.value("password").toString();
    if (!password.isEmpty() && m_secrets) {
        conn.secretRef = m_secrets->storeSecret(password);
    }

    int id = m_localStore->saveConnection(conn);
    if (id != -1) {
        emit connectionsChanged();
        m_logger->info("Saved connection: " + conn.name);
        return id;
    }
    
    return -1;
}

bool AppContext::deleteConnection(int id)
{
    if (!m_localStore) return false;
    
    m_localStore->deleteConnection(id);
    emit connectionsChanged();
    m_logger->info("Deleted connection ID: " + QString::number(id));
    return true;
}

void AppContext::refreshConnections()
{
    emit connectionsChanged();
}

void AppContext::saveAppState(const QVariantMap& state)
{
    if (!m_localStore) return;
    
    // Convert to JSON string for storage
    QJsonDocument doc = QJsonDocument::fromVariant(state);
    m_localStore->saveSetting("app_state", doc.toJson(QJsonDocument::Compact));
}

QVariantMap AppContext::loadAppState()
{
    if (!m_localStore) return {};
    
    QVariant val = m_localStore->getSetting("app_state");
    if (val.isValid()) {
        QJsonDocument doc = QJsonDocument::fromJson(val.toString().toUtf8());
        return doc.toVariant().toMap();
    }
    return {};
}

QVariantList AppContext::availableDrivers() const
{
    QVariantList list;
    // For MVP, we only have Postgres. 
    // In future, AddonHost should expose a method to list all registered addons.
    // Since AddonHost only has getAddon/hasAddon/registerAddon, we can't iterate easily 
    // unless we modify AddonHost or just hardcode for now if we know what we registered.
    // Wait, AddonHost has a map. But no method to list keys.
    // I should probably add a method to AddonHost to list registered addons.
    // For now, I will just return the "postgres" one if it exists.
    
    if (m_addonHost && m_addonHost->hasAddon("postgres")) {
        auto addon = m_addonHost->getAddon("postgres");
        QVariantMap map;
        map["id"] = addon->id();
        map["name"] = addon->name();
        list.append(map);
    }
    
    return list;
}

bool AppContext::testConnection(const QVariantMap& data)
{
    if (!m_addonHost) return false;
    
    // Determine driver from data or default to postgres for now
    // Ideally data should contain "driver" or "type"
    QString driverId = "postgres"; // Default for MVP
    
    if (!m_addonHost->hasAddon(driverId)) {
        m_logger->error("Driver not found: " + driverId);
        return false;
    }
    
    auto addon = m_addonHost->getAddon(driverId);
    auto connection = addon->createConnection();
    
    QString host = data.value("host").toString();
    int port = data.value("port", 5432).toInt();
    QString db = data.value("database").toString();
    QString user = data.value("user").toString();
    QString password = data.value("password").toString();
    
    bool success = connection->testConnection(host, port, db, user, password);
    
    if (success) {
        m_logger->info("Connection test successful for " + host);
        setLastError("");
    } else {
        m_logger->error("Connection test failed: " + connection->lastError());
        setLastError(connection->lastError());
    }
    
    return success;
}

bool AppContext::openConnection(int id)
{
    if (!m_localStore || !m_addonHost) return false;
    
    // 1. Find connection data
    auto connections = m_localStore->getAllConnections();
    ConnectionData targetConn;
    bool found = false;
    for (const auto& conn : connections) {
        if (conn.id == id) {
            targetConn = conn;
            found = true;
            break;
        }
    }
    
    if (!found) {
        m_logger->error("Connection ID not found: " + QString::number(id));
        return false;
    }
    
    // 2. Get driver (hardcoded postgres for now)
    QString driverId = "postgres";
    if (!m_addonHost->hasAddon(driverId)) {
        m_logger->error("Driver not found: " + driverId);
        return false;
    }
    
    auto addon = m_addonHost->getAddon(driverId);
    
    // 3. Create and open connection
    if (m_currentConnection && m_currentConnection->isOpen()) {
        closeConnection();
    }
    
    m_currentConnection = addon->createConnection();
    
    // Retrieve password if secretRef exists
    QString password = "";
    if (m_secrets && !targetConn.secretRef.isEmpty()) {
        password = m_secrets->getSecret(targetConn.secretRef);
    }
    
    bool success = m_currentConnection->open(targetConn.host, targetConn.port, targetConn.database, targetConn.user, password);
    
    if (success) {
        m_currentConnectionId = id;
        m_activeConnectionInfo.clear();
        m_activeConnectionInfo["driverId"] = driverId;
        m_activeConnectionInfo["host"] = targetConn.host;
        m_activeConnectionInfo["port"] = targetConn.port;
        m_activeConnectionInfo["database"] = targetConn.database;
        m_activeConnectionInfo["user"] = targetConn.user;
        m_activeConnectionInfo["password"] = password;
        m_logger->info("Opened connection: " + targetConn.name);
        setLastError("");
        emit connectionOpened(id);
        emit activeConnectionIdChanged();
    } else {
        m_logger->error("Failed to open connection: " + m_currentConnection->lastError());
        setLastError(m_currentConnection->lastError());
        m_currentConnection.reset();
        m_currentConnectionId = -1;
        emit activeConnectionIdChanged();
    }
    
    return success;
}

void AppContext::closeConnection()
{
    if (m_currentConnection && m_currentConnection->isOpen()) {
        m_currentConnection->close();
    }
    m_currentConnection.reset();
    m_currentConnectionId = -1;
    m_activeConnectionInfo.clear();
    emit connectionClosed();
    emit activeConnectionIdChanged();
}

QStringList AppContext::getSchemas()
{
    QStringList list;
    if (!m_currentConnection || !m_currentConnection->isOpen()) return list;
    
    auto catalog = m_currentConnection->catalog();
    if (catalog) {
        QSet<QString> hiddenSet;
        auto hiddenSchemas = catalog->listHiddenSchemas();
        for (const auto& s : hiddenSchemas) {
            hiddenSet.insert(s);
        }
        auto schemas = catalog->listSchemas();
        bool publicFound = false;
        for (const auto& s : schemas) {
            if (!hiddenSet.contains(s)) {
                if (s == "public") {
                    publicFound = true;
                } else {
                    list.append(s);
                }
            }
        }
        if (publicFound) {
            list.prepend("public");
        }
    }
    return list;
}

QStringList AppContext::getHiddenSchemas()
{
    QStringList list;
    if (!m_currentConnection || !m_currentConnection->isOpen()) return list;
    
    auto catalog = m_currentConnection->catalog();
    if (catalog) {
        auto schemas = catalog->listHiddenSchemas();
        bool publicFound = false;
        for (const auto& s : schemas) {
            if (s == "public") {
                publicFound = true;
            } else {
                list.append(s);
            }
        }
        if (publicFound) {
            list.prepend("public");
        }
    }
    return list;
}

QStringList AppContext::getTables(const QString& schema)
{
    QStringList list;
    if (!m_currentConnection || !m_currentConnection->isOpen()) return list;
    
    auto catalog = m_currentConnection->catalog();
    if (catalog) {
        auto tables = catalog->listTables(schema);
        for (const auto& t : tables) {
            list.append(t);
        }
    }
    return list;
}

QVariantMap AppContext::runQuery(const QString& queryText)
{
    QVariantMap result;
    if (!m_currentConnection) {
        result["error"] = "No active connection";
        setLastError(result["error"].toString());
        return result;
    }
    
    auto queryProvider = m_currentConnection->query();
    if (!queryProvider) {
        result["error"] = "Connection does not support queries";
        setLastError(result["error"].toString());
        return result;
    }
    
    // Save history
    if (m_localStore && m_currentConnectionId != -1) {
        QueryHistoryItem item;
        item.connectionId = m_currentConnectionId;
        item.query = queryText;
        m_localStore->saveQueryHistory(item);
    }
    
    DatasetRequest request; // default
    DatasetPage page = queryProvider->execute(queryText, request);
    
    if (!page.warning.isEmpty()) {
        result["warning"] = page.warning;
    }
    if (!page.warning.isEmpty() && page.columns.empty()) {
        result["error"] = page.warning;
        setLastError(page.warning);
        return result;
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
    
    setLastError("");
    return result;
}

bool AppContext::runQueryAsync(const QString& queryText, const QString& requestTag)
{
    if (!m_currentConnection || !m_currentConnection->isOpen()) {
        setLastError("Connection is not open.");
        emit sqlError(requestTag, m_lastError);
        return false;
    }
    if (m_queryRunning) {
        setLastError("A query is already running.");
        emit sqlError(requestTag, m_lastError);
        return false;
    }
    if (!m_worker) {
        setLastError("Worker unavailable.");
        emit sqlError(requestTag, m_lastError);
        return false;
    }
    if (!m_activeConnectionInfo.contains("driverId")) {
        setLastError("Connection configuration unavailable.");
        emit sqlError(requestTag, m_lastError);
        return false;
    }
    m_queryRunning = true;
    emit queryRunningChanged();
    m_activeRequestTag = requestTag;
    m_activeRequestType = "sql";
    m_activeBackendPid = -1;
    QMetaObject::invokeMethod(m_worker, "runSql", Qt::QueuedConnection,
                              Q_ARG(QVariantMap, m_activeConnectionInfo),
                              Q_ARG(QString, queryText),
                              Q_ARG(QString, requestTag));
    return true;
}

QVariantList AppContext::getQueryHistory(int connectionId)
{
    QVariantList list;
    if (!m_localStore) return list;
    
    auto history = m_localStore->getQueryHistory(connectionId);
    for (const auto& item : history) {
        QVariantMap map;
        map["id"] = item.id;
        map["query"] = item.query;
        map["createdAt"] = item.createdAt;
        list.append(map);
    }
    return list;
}

QVariantMap AppContext::getDataset(const QString& schema, const QString& table, int limit, int offset)
{
    QVariantMap result;
    if (!m_currentConnection || !m_currentConnection->isOpen()) {
        result["error"] = "Conexão não está aberta.";
        setLastError(result["error"].toString());
        if (m_logger) {
            m_logger->error("\x1b[31m❌ Dataset\x1b[0m conexão não está aberta");
        }
        return result;
    }
    
    if (m_logger) {
        m_logger->info("\x1b[36m🧭 Dataset\x1b[0m schema=" + schema + " tabela=" + table + " limit=" + QString::number(limit) + " offset=" + QString::number(offset));
    }
    
    DatasetRequest request;
    request.limit = limit;
    request.offset = offset;
    
    auto queryProvider = m_currentConnection->query();
    if (!queryProvider) {
        result["error"] = "Query provider indisponível.";
        setLastError(result["error"].toString());
        if (m_logger) {
            m_logger->error("\x1b[31m❌ Dataset\x1b[0m query provider indisponível");
        }
        return result;
    }
    
    auto page = queryProvider->getDataset(schema, table, request);
    if (m_logger && !page.warning.isEmpty()) {
        m_logger->warning("\x1b[33m⚠️ Dataset\x1b[0m " + page.warning);
    }
    if (!page.warning.isEmpty()) {
        result["error"] = page.warning;
        setLastError(page.warning);
    }
    
    QVariantList columns;
    for (const auto& col : page.columns) {
        QVariantMap c;
        c["name"] = col.name;
        c["type"] = col.rawType;
        columns.append(c);
    }
    result["columns"] = columns;
    if (page.columns.empty() && !result.contains("error")) {
        result["error"] = "Falha ao carregar colunas da tabela.";
        setLastError(result["error"].toString());
        if (m_logger) {
            m_logger->error("\x1b[31m❌ Dataset\x1b[0m colunas vazias para " + schema + "." + table);
        }
    }
    
    QVariantList rows;
    for (const auto& row : page.rows) {
        QVariantList r;
        for (const auto& val : row) {
            r.append(val);
        }
        rows.append(QVariant(r));
    }
    result["rows"] = rows;
    result["hasMore"] = page.hasMore;
    
    if (m_logger) {
        m_logger->info("\x1b[35m🧪 Dataset rows payload\x1b[0m total=" + QString::number(rows.size()) +
                       " firstRowSize=" + (rows.isEmpty() ? QString("0") : QString::number(rows.first().toList().size())));
        if (!rows.isEmpty()) {
            QStringList debugVals;
            for (const auto& v : rows.first().toList()) debugVals << v.toString();
            m_logger->info("\x1b[35m🧪 Dataset first row values\x1b[0m " + debugVals.join("|"));
        }
    }
    
    if (m_logger) {
        m_logger->info("\x1b[32m✅ Dataset\x1b[0m colunas=" + QString::number(page.columns.size()) + " linhas=" + QString::number(page.rows.size()) + " hasMore=" + (page.hasMore ? "true" : "false"));
    }
    if (m_logger && !rows.isEmpty()) {
        QStringList debugVals;
        for (const auto& v : rows.first().toList()) {
            debugVals << (QString(v.typeName()) + ":" + v.toString());
        }
        m_logger->info("\x1b[35m🧪 Dataset first row typed\x1b[0m " + debugVals.join("|"));
    }
    
    if (!result.contains("error")) {
        setLastError("");
    }
    return result;
}

bool AppContext::getDatasetAsync(const QString& schema, const QString& table, int limit, int offset, const QString& requestTag)
{
    if (!m_currentConnection || !m_currentConnection->isOpen()) {
        setLastError("Connection is not open.");
        emit datasetError(requestTag, m_lastError);
        return false;
    }
    if (m_queryRunning) {
        setLastError("A query is already running.");
        emit datasetError(requestTag, m_lastError);
        return false;
    }
    if (!m_worker) {
        setLastError("Worker unavailable.");
        emit datasetError(requestTag, m_lastError);
        return false;
    }
    if (!m_activeConnectionInfo.contains("driverId")) {
        setLastError("Connection configuration unavailable.");
        emit datasetError(requestTag, m_lastError);
        return false;
    }
    m_queryRunning = true;
    emit queryRunningChanged();
    m_activeRequestTag = requestTag;
    m_activeRequestType = "dataset";
    m_activeBackendPid = -1;
    QMetaObject::invokeMethod(m_worker, "runDataset", Qt::QueuedConnection,
                              Q_ARG(QVariantMap, m_activeConnectionInfo),
                              Q_ARG(QString, schema),
                              Q_ARG(QString, table),
                              Q_ARG(int, limit),
                              Q_ARG(int, offset),
                              Q_ARG(QString, requestTag));
    return true;
}

void AppContext::getCount(const QString& schema, const QString& table, const QString& requestTag)
{
    if (!m_currentConnection || !m_currentConnection->isOpen()) {
        if (m_logger) m_logger->error("\x1b[31m❌ Count\x1b[0m conexão não está aberta");
        return;
    }
    
    QMetaObject::invokeMethod(m_worker, "runCount", Qt::QueuedConnection,
                              Q_ARG(QVariantMap, m_activeConnectionInfo),
                              Q_ARG(QString, schema),
                              Q_ARG(QString, table),
                              Q_ARG(QString, requestTag));
}

bool AppContext::cancelActiveQuery()
{
    if (!m_queryRunning || !m_currentConnection) {
        return false;
    }
    bool canceled = m_currentConnection->cancelQuery(m_activeBackendPid);
    if (canceled) {
        QString tag = m_activeRequestTag;
        QString type = m_activeRequestType;
        m_queryRunning = false;
        emit queryRunningChanged();
        m_activeBackendPid = -1;
        m_activeRequestTag.clear();
        m_activeRequestType.clear();
        setLastError("");
        if (type == "sql") {
            emit sqlCanceled(tag);
        } else if (type == "dataset") {
            emit datasetCanceled(tag);
        }
    } else {
        setLastError("Cancelamento não suportado pelo driver.");
    }
    return canceled;
}

void AppContext::handleSqlStarted(const QString& requestTag, int backendPid)
{
    m_activeBackendPid = backendPid;
    if (requestTag == m_activeRequestTag) {
        emit sqlStarted(requestTag);
    }
}

void AppContext::handleSqlFinished(const QString& requestTag, const QVariantMap& result)
{
    if (requestTag != m_activeRequestTag) return;
    m_queryRunning = false;
    emit queryRunningChanged();
    setLastError("");
    m_activeBackendPid = -1;
    m_activeRequestTag.clear();
    m_activeRequestType.clear();
    emit sqlFinished(requestTag, result);
}

void AppContext::handleSqlError(const QString& requestTag, const QString& error)
{
    if (requestTag != m_activeRequestTag && !m_activeRequestTag.isEmpty()) return;
    m_queryRunning = false;
    emit queryRunningChanged();
    setLastError(error);
    m_activeBackendPid = -1;
    m_activeRequestTag.clear();
    m_activeRequestType.clear();
    emit sqlError(requestTag, error);
}

void AppContext::handleDatasetStarted(const QString& requestTag, int backendPid)
{
    m_activeBackendPid = backendPid;
    if (requestTag == m_activeRequestTag) {
        emit datasetStarted(requestTag);
    }
}

void AppContext::handleDatasetFinished(const QString& requestTag, const QVariantMap& result)
{
    if (requestTag != m_activeRequestTag) return;
    m_queryRunning = false;
    emit queryRunningChanged();
    setLastError("");
    m_activeBackendPid = -1;
    m_activeRequestTag.clear();
    m_activeRequestType.clear();
    emit datasetFinished(requestTag, result);
}

void AppContext::handleDatasetError(const QString& requestTag, const QString& error)
{
    if (requestTag != m_activeRequestTag && !m_activeRequestTag.isEmpty()) return;
    m_queryRunning = false;
    emit queryRunningChanged();
    setLastError(error);
    m_activeBackendPid = -1;
    m_activeRequestTag.clear();
    m_activeRequestType.clear();
    emit datasetError(requestTag, error);
}

void AppContext::handleCountFinished(const QString& requestTag, int total)
{
    emit countFinished(requestTag, total);
}

}
