#include "AppContext.h"
#include <QVariantMap>

namespace Sofa::Core {

AppContext::AppContext(std::shared_ptr<ICommandService> commandService,
                       std::shared_ptr<ILogger> logger,
                       std::shared_ptr<ILocalStoreService> localStore,
                       std::shared_ptr<ISecretsService> secrets,
                       QObject* parent)
    : QObject(parent)
    , m_commandService(std::move(commandService))
    , m_logger(std::move(logger))
    , m_localStore(std::move(localStore))
    , m_secrets(std::move(secrets))
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

}
