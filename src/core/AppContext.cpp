#include "AppContext.h"
#include <QVariantMap>

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
}

void AppContext::executeCommand(const QString& id)
{
    if (m_commandService) {
        m_commandService->execute(id);
    } else if (m_logger) {
        m_logger->error("CommandService is not available");
    }
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
        map["createdAt"] = conn.createdAt;
        map["updatedAt"] = conn.updatedAt;
        list.append(map);
    }
    return list;
}

bool AppContext::saveConnection(const QVariantMap& data)
{
    if (!m_localStore) return false;

    ConnectionData conn;
    conn.id = data.value("id", -1).toInt();
    conn.name = data.value("name").toString();
    conn.host = data.value("host").toString();
    conn.port = data.value("port", 5432).toInt();
    conn.database = data.value("database").toString();
    conn.user = data.value("user").toString();
    
    // Handle secret if present (simple pass-through for now)
    QString password = data.value("password").toString();
    if (!password.isEmpty() && m_secrets) {
        conn.secretRef = m_secrets->storeSecret(password);
    }

    int id = m_localStore->saveConnection(conn);
    if (id != -1) {
        emit connectionsChanged();
        m_logger->info("Saved connection: " + conn.name);
        return true;
    }
    
    return false;
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
    } else {
        m_logger->error("Connection test failed: " + connection->lastError());
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
    
    // Retrieve password if secretRef exists (Mock: pass empty or anything)
    QString password = ""; // TODO: fetch from SecretsService
    
    bool success = m_currentConnection->open(targetConn.host, targetConn.port, targetConn.database, targetConn.user, password);
    
    if (success) {
        m_currentConnectionId = id;
        m_logger->info("Opened connection: " + targetConn.name);
        emit connectionOpened(id);
        emit activeConnectionIdChanged();
    } else {
        m_logger->error("Failed to open connection: " + m_currentConnection->lastError());
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
    emit connectionClosed();
    emit activeConnectionIdChanged();
}

QStringList AppContext::getSchemas()
{
    QStringList list;
    if (!m_currentConnection || !m_currentConnection->isOpen()) return list;
    
    auto catalog = m_currentConnection->catalog();
    if (catalog) {
        auto schemas = catalog->listSchemas();
        for (const auto& s : schemas) {
            list.append(s);
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

}
