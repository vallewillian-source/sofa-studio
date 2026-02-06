#pragma once
#include "addons/IAddon.h"
#include <QString>
#include <vector>
#include <QSqlDatabase>
#include <QSqlError>

namespace Sofa::Addons::Postgres {

using namespace Sofa::Core;

class PostgresQueryProvider : public IQueryProvider {
public:
    explicit PostgresQueryProvider(const QString& connectionName);
    DatasetPage execute(const QString& query, const DatasetRequest& request) override;
    int count(const QString& schema, const QString& table) override;
    int backendPid() override;

private:
    QString m_connectionName;
};

class PostgresCatalogProvider : public ICatalogProvider {
public:
    explicit PostgresCatalogProvider(const QString& connectionName);
    std::vector<QString> listSchemas() override;
    std::vector<QString> listHiddenSchemas() override;
    std::vector<QString> listTables(const QString& schema) override;
    TableSchema getTableSchema(const QString& schema, const QString& table) override;

private:
    QString m_connectionName;
};

class PostgresConnection : public IConnectionProvider {
public:
    PostgresConnection();
    ~PostgresConnection();

    bool testConnection(const QString& host, int port, const QString& db, const QString& user, const QString& password) override;
    bool open(const QString& host, int port, const QString& db, const QString& user, const QString& password) override;
    void close() override;
    bool isOpen() const override;
    QString lastError() const override;

    std::shared_ptr<ICatalogProvider> catalog() override;
    std::shared_ptr<IQueryProvider> query() override;
    bool cancelQuery(int backendPid) override;

private:
    QString m_connectionName;
    QString m_lastError;
    std::shared_ptr<PostgresCatalogProvider> m_catalog;
    std::shared_ptr<PostgresQueryProvider> m_query;
};

class PostgresAddon : public IAddon {
public:
    QString id() const override { return "postgres"; }
    QString name() const override { return "PostgreSQL"; }
    std::shared_ptr<IConnectionProvider> createConnection() override;
};

}
