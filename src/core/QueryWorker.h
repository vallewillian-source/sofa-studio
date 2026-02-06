#pragma once

#include <QObject>
#include <QVariantMap>
#include <memory>
#include "AddonHost.h"
#include "addons/IAddon.h"

namespace Sofa::Core {

class QueryWorker : public QObject {
    Q_OBJECT
public:
    explicit QueryWorker(std::shared_ptr<AddonHost> addonHost, QObject* parent = nullptr);

public slots:
    void runSql(const QVariantMap& connectionInfo, const QString& queryText, const QString& requestTag);
    void runDataset(const QVariantMap& connectionInfo, const QString& schema, const QString& table, int limit, int offset, const QString& requestTag);
    void runCount(const QVariantMap& connectionInfo, const QString& schema, const QString& table, const QString& requestTag);

signals:
    void sqlStarted(const QString& requestTag, int backendPid);
    void sqlFinished(const QString& requestTag, const QVariantMap& result);
    void sqlError(const QString& requestTag, const QString& error);
    void datasetStarted(const QString& requestTag, int backendPid);
    void datasetFinished(const QString& requestTag, const QVariantMap& result);
    void datasetError(const QString& requestTag, const QString& error);
    void countFinished(const QString& requestTag, int total);

private:
    QVariantMap datasetToVariant(const DatasetPage& page);

    std::shared_ptr<AddonHost> m_addonHost;
};

}
