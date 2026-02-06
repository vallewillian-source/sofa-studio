#pragma once

#include <QObject>
#include <memory>
#include "ICommandService.h"
#include "ILogger.h"
#include "ILocalStoreService.h"
#include "ISecretsService.h"
#include "AddonHost.h"
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <QString>
#include <QThread>
#include "QueryWorker.h"

namespace Sofa::Core {

class AppContext : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList connections READ connections NOTIFY connectionsChanged)
    Q_PROPERTY(QVariantList availableDrivers READ availableDrivers CONSTANT)
    Q_PROPERTY(int activeConnectionId READ activeConnectionId NOTIFY activeConnectionIdChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool queryRunning READ queryRunning NOTIFY queryRunningChanged)

public:
    explicit AppContext(std::shared_ptr<ICommandService> commandService,
                       std::shared_ptr<ILogger> logger,
                       std::shared_ptr<ILocalStoreService> localStore,
                       std::shared_ptr<ISecretsService> secrets,
                       std::shared_ptr<AddonHost> addonHost,
                       QObject* parent = nullptr);
    ~AppContext() override;

    Q_INVOKABLE void executeCommand(const QString& id);
    
    // Connections API
    QVariantList connections() const;
    Q_INVOKABLE int saveConnection(const QVariantMap& data);
    Q_INVOKABLE bool deleteConnection(int id);
    
    // Drivers/Addons API
    QVariantList availableDrivers() const;
    Q_INVOKABLE bool testConnection(const QVariantMap& data);
    Q_INVOKABLE void clearLastError();
    QString lastError() const { return m_lastError; }
    bool queryRunning() const { return m_queryRunning; }

    // Active Session API
    int activeConnectionId() const { return m_currentConnectionId; }
    Q_INVOKABLE bool openConnection(int id);
    Q_INVOKABLE void closeConnection();
    Q_INVOKABLE QStringList getSchemas();
    Q_INVOKABLE QStringList getHiddenSchemas();
    Q_INVOKABLE QStringList getTables(const QString& schema);
    
    // Query API
    Q_INVOKABLE QVariantMap runQuery(const QString& queryText);
    Q_INVOKABLE QVariantList getQueryHistory(int connectionId);
    Q_INVOKABLE QVariantMap getDataset(const QString& schema, const QString& table, int limit = 100, int offset = 0);
    Q_INVOKABLE bool runQueryAsync(const QString& queryText, const QString& requestTag = "sql");
    Q_INVOKABLE bool getDatasetAsync(const QString& schema, const QString& table, int limit = 100, int offset = 0, const QString& requestTag = "table");
    Q_INVOKABLE void getCount(const QString& schema, const QString& table, const QString& requestTag);
    Q_INVOKABLE bool cancelActiveQuery();
    
    // App State API
    Q_INVOKABLE void saveAppState(const QVariantMap& state);
    Q_INVOKABLE QVariantMap loadAppState();

signals:
    void connectionsChanged();
    void activeConnectionIdChanged();
    void connectionOpened(int id);
    void connectionClosed();
    void lastErrorChanged();
    void queryRunningChanged();
    void sqlStarted(const QString& requestTag);
    void sqlFinished(const QString& requestTag, const QVariantMap& result);
    void sqlError(const QString& requestTag, const QString& error);
    void sqlCanceled(const QString& requestTag);
    void datasetStarted(const QString& requestTag);
    void datasetFinished(const QString& requestTag, const QVariantMap& result);
    void datasetError(const QString& requestTag, const QString& error);
    void datasetCanceled(const QString& requestTag);
    void countFinished(const QString& requestTag, int total);
    void countError(const QString& requestTag, const QString& error);

private:
    std::shared_ptr<ICommandService> m_commandService;
    std::shared_ptr<ILogger> m_logger;
    std::shared_ptr<ILocalStoreService> m_localStore;
    std::shared_ptr<ISecretsService> m_secrets;
    std::shared_ptr<AddonHost> m_addonHost;
    
    std::shared_ptr<IConnectionProvider> m_currentConnection;
    int m_currentConnectionId = -1;
    QString m_lastError;
    bool m_queryRunning = false;
    int m_activeBackendPid = -1;
    QString m_activeRequestTag;
    QString m_activeRequestType;
    QVariantMap m_activeConnectionInfo;
    QueryWorker* m_worker = nullptr;
    QThread m_workerThread;
    
    void refreshConnections();
    void setLastError(const QString& error);

private slots:
    void handleSqlStarted(const QString& requestTag, int backendPid);
    void handleSqlFinished(const QString& requestTag, const QVariantMap& result);
    void handleSqlError(const QString& requestTag, const QString& error);
    void handleDatasetStarted(const QString& requestTag, int backendPid);
    void handleDatasetFinished(const QString& requestTag, const QVariantMap& result);
    void handleDatasetError(const QString& requestTag, const QString& error);
    void handleCountFinished(const QString& requestTag, int total);

};

}
