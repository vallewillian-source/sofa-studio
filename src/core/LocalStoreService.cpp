#include "LocalStoreService.h"
#include <QStandardPaths>
#include <QDir>
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>
#include <QDateTime>

namespace Sofa::Core {

LocalStoreService::LocalStoreService(std::shared_ptr<ILogger> logger)
    : m_logger(logger)
{
    QString dataLocation = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir(dataLocation);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    m_dbPath = dir.filePath("sofa.db");
    m_logger->info("LocalStore DB path: " + m_dbPath);
}

LocalStoreService::~LocalStoreService()
{
    // Close connection if needed, though QSqlDatabase handles it typically via name
}

QSqlDatabase LocalStoreService::getDatabase()
{
    QString connectionName = "sofa_local_store";
    if (QSqlDatabase::contains(connectionName)) {
        return QSqlDatabase::database(connectionName);
    }
    
    QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connectionName);
    db.setDatabaseName(m_dbPath);
    return db;
}

void LocalStoreService::init()
{
    auto db = getDatabase();
    if (!db.open()) {
        m_logger->error("Failed to open local database: " + db.lastError().text());
        return;
    }

    QSqlQuery query(db);
    QString createTable = R"(
        CREATE TABLE IF NOT EXISTS connections (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            host TEXT NOT NULL,
            port INTEGER DEFAULT 5432,
            database TEXT NOT NULL,
            user TEXT NOT NULL,
            secret_ref TEXT,
            created_at DATETIME,
            updated_at DATETIME
        )
    )";

    if (!query.exec(createTable)) {
        m_logger->error("Failed to create connections table: " + query.lastError().text());
    } else {
        m_logger->info("LocalStore initialized successfully");
    }
}

std::vector<ConnectionData> LocalStoreService::getAllConnections()
{
    std::vector<ConnectionData> results;
    auto db = getDatabase();
    if (!db.open()) return results;

    QSqlQuery query(db);
    if (query.exec("SELECT id, name, host, port, database, user, secret_ref, created_at, updated_at FROM connections ORDER BY name ASC")) {
        while (query.next()) {
            ConnectionData data;
            data.id = query.value(0).toInt();
            data.name = query.value(1).toString();
            data.host = query.value(2).toString();
            data.port = query.value(3).toInt();
            data.database = query.value(4).toString();
            data.user = query.value(5).toString();
            data.secretRef = query.value(6).toString();
            data.createdAt = query.value(7).toDateTime();
            data.updatedAt = query.value(8).toDateTime();
            results.push_back(data);
        }
    } else {
        m_logger->error("Failed to fetch connections: " + query.lastError().text());
    }
    return results;
}

int LocalStoreService::saveConnection(const ConnectionData& data)
{
    auto db = getDatabase();
    if (!db.open()) return -1;

    QSqlQuery query(db);
    bool isUpdate = (data.id > 0);
    
    if (isUpdate) {
        query.prepare(R"(
            UPDATE connections 
            SET name = ?, host = ?, port = ?, database = ?, user = ?, secret_ref = ?, updated_at = ?
            WHERE id = ?
        )");
        query.addBindValue(data.name);
        query.addBindValue(data.host);
        query.addBindValue(data.port);
        query.addBindValue(data.database);
        query.addBindValue(data.user);
        query.addBindValue(data.secretRef);
        query.addBindValue(QDateTime::currentDateTime());
        query.addBindValue(data.id);
    } else {
        query.prepare(R"(
            INSERT INTO connections (name, host, port, database, user, secret_ref, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        )");
        query.addBindValue(data.name);
        query.addBindValue(data.host);
        query.addBindValue(data.port);
        query.addBindValue(data.database);
        query.addBindValue(data.user);
        query.addBindValue(data.secretRef);
        query.addBindValue(QDateTime::currentDateTime());
        query.addBindValue(QDateTime::currentDateTime());
    }

    if (!query.exec()) {
        m_logger->error("Failed to save connection: " + query.lastError().text());
        return -1;
    }

    if (isUpdate) return data.id;
    return query.lastInsertId().toInt();
}

void LocalStoreService::deleteConnection(int id)
{
    auto db = getDatabase();
    if (!db.open()) return;

    QSqlQuery query(db);
    query.prepare("DELETE FROM connections WHERE id = ?");
    query.addBindValue(id);
    
    if (!query.exec()) {
        m_logger->error("Failed to delete connection: " + query.lastError().text());
    }
}

}
