#pragma once

#include <QObject>
#include <memory>
#include "ICommandService.h"
#include "ILogger.h"
#include "ILocalStoreService.h"
#include "ISecretsService.h"
#include "AddonHost.h"
#include <QVariantList>

namespace Sofa::Core {

class AppContext : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList connections READ connections NOTIFY connectionsChanged)
    Q_PROPERTY(QVariantList availableDrivers READ availableDrivers CONSTANT)
    Q_PROPERTY(int activeConnectionId READ activeConnectionId NOTIFY activeConnectionIdChanged)

public:
    explicit AppContext(std::shared_ptr<ICommandService> commandService,
                       std::shared_ptr<ILogger> logger,
                       std::shared_ptr<ILocalStoreService> localStore,
                       std::shared_ptr<ISecretsService> secrets,
                       std::shared_ptr<AddonHost> addonHost,
                       QObject* parent = nullptr);

    Q_INVOKABLE void executeCommand(const QString& id);
    
    // Connections API
    QVariantList connections() const;
    Q_INVOKABLE bool saveConnection(const QVariantMap& data);
    Q_INVOKABLE bool deleteConnection(int id);
    
    // Drivers/Addons API
    QVariantList availableDrivers() const;
    Q_INVOKABLE bool testConnection(const QVariantMap& data);

    // Active Session API
    int activeConnectionId() const { return m_currentConnectionId; }
    Q_INVOKABLE bool openConnection(int id);
    Q_INVOKABLE void closeConnection();
    Q_INVOKABLE QStringList getSchemas();
    Q_INVOKABLE QStringList getTables(const QString& schema);
    
    // Query API
    Q_INVOKABLE QVariantMap runQuery(const QString& queryText);
    Q_INVOKABLE QVariantList getQueryHistory(int connectionId);
    Q_INVOKABLE QVariantMap getDataset(const QString& schema, const QString& table, int limit = 100, int offset = 0);
    
    // Views API
    Q_INVOKABLE QVariantList getViews(const QString& schema, const QString& table);
    Q_INVOKABLE int saveView(const QVariantMap& viewData);
    Q_INVOKABLE bool deleteView(int id);

signals:
    void connectionsChanged();
    void activeConnectionIdChanged();
    void connectionOpened(int id);
    void connectionClosed();

private:
    std::shared_ptr<ICommandService> m_commandService;
    std::shared_ptr<ILogger> m_logger;
    std::shared_ptr<ILocalStoreService> m_localStore;
    std::shared_ptr<ISecretsService> m_secrets;
    std::shared_ptr<AddonHost> m_addonHost;
    
    std::shared_ptr<IConnectionProvider> m_currentConnection;
    int m_currentConnectionId = -1;
    
    void refreshConnections();
};

}
