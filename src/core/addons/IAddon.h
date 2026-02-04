#pragma once
#include <QString>
#include <memory>
#include <vector>
#include "udm/UDM.h"

namespace Sofa::Core {

// Forward declaration
class IConnectionProvider;

// Main interface for an Addon
class IAddon {
public:
    virtual ~IAddon() = default;
    virtual QString id() const = 0;
    virtual QString name() const = 0;
    virtual std::shared_ptr<IConnectionProvider> createConnection() = 0;
};

class ICatalogProvider {
public:
    virtual ~ICatalogProvider() = default;
    virtual std::vector<QString> listSchemas() = 0;
    virtual std::vector<QString> listTables(const QString& schema) = 0;
    virtual TableSchema getTableSchema(const QString& schema, const QString& table) = 0;
};

class IQueryProvider {
public:
    virtual ~IQueryProvider() = default;
    // Execute a raw query
    virtual DatasetPage execute(const QString& query, const DatasetRequest& request) = 0;
    virtual int backendPid() { return -1; }
};

class IConnectionProvider {
public:
    virtual ~IConnectionProvider() = default;
    
    // Connection lifecycle
    virtual bool testConnection(const QString& host, int port, const QString& db, const QString& user, const QString& password) = 0;
    virtual bool open(const QString& host, int port, const QString& db, const QString& user, const QString& password) = 0;
    virtual void close() = 0;
    virtual bool isOpen() const = 0;
    virtual QString lastError() const = 0;

    // Access to capabilities
    virtual std::shared_ptr<ICatalogProvider> catalog() = 0;
    virtual std::shared_ptr<IQueryProvider> query() = 0;
    virtual bool cancelQuery(int backendPid) { (void)backendPid; return false; }
};

}
