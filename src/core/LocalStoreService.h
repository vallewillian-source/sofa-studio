#pragma once
#include "ILocalStoreService.h"
#include "ILogger.h"
#include <memory>
#include <QSqlDatabase>

namespace Sofa::Core {

class LocalStoreService : public ILocalStoreService {
public:
    explicit LocalStoreService(std::shared_ptr<ILogger> logger);
    ~LocalStoreService() override;

    void init() override;
    std::vector<ConnectionData> getAllConnections() override;
    int saveConnection(const ConnectionData& data) override;
    void deleteConnection(int id) override;

    void saveQueryHistory(const QueryHistoryItem& item) override;
    std::vector<QueryHistoryItem> getQueryHistory(int connectionId) override;

    int saveView(const ViewData& data) override;
    std::vector<ViewData> getViews(int connectionId, const QString& sourceRef) override;
    void deleteView(int id) override;

private:
    std::shared_ptr<ILogger> m_logger;
    QString m_dbPath;
    
    QSqlDatabase getDatabase();
};

}
