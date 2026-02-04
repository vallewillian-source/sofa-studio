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

    QString createHistoryTable = R"(
        CREATE TABLE IF NOT EXISTS query_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            connection_id INTEGER,
            query_text TEXT,
            created_at DATETIME
        )
    )";

    if (!query.exec(createHistoryTable)) {
        m_logger->error("Failed to create query_history table: " + query.lastError().text());
    }
    
    QString createViewsTable = R"(
        CREATE TABLE IF NOT EXISTS views (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            connection_id INTEGER,
            source_ref TEXT NOT NULL,
            name TEXT NOT NULL,
            definition_json TEXT,
            created_at DATETIME
        )
    )";
    
    if (!query.exec(createViewsTable)) {
        m_logger->error("Failed to create views table: " + query.lastError().text());
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
    if (data.id == -1) {
        query.prepare("INSERT INTO connections (name, host, port, database, user, secret_ref, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
        query.addBindValue(data.name);
        query.addBindValue(data.host);
        query.addBindValue(data.port);
        query.addBindValue(data.database);
        query.addBindValue(data.user);
        query.addBindValue(data.secretRef);
        query.addBindValue(QDateTime::currentDateTime());
        query.addBindValue(QDateTime::currentDateTime());
    } else {
        query.prepare("UPDATE connections SET name=?, host=?, port=?, database=?, user=?, secret_ref=?, updated_at=? WHERE id=?");
        query.addBindValue(data.name);
        query.addBindValue(data.host);
        query.addBindValue(data.port);
        query.addBindValue(data.database);
        query.addBindValue(data.user);
        query.addBindValue(data.secretRef);
        query.addBindValue(QDateTime::currentDateTime());
        query.addBindValue(data.id);
    }
    
    if (query.exec()) {
        if (data.id == -1) {
            return query.lastInsertId().toInt();
        }
        return data.id;
    } else {
        m_logger->error("Failed to save connection: " + query.lastError().text());
        return -1;
    }
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

void LocalStoreService::saveQueryHistory(const QueryHistoryItem& item)
{
    auto db = getDatabase();
    if (!db.open()) return;

    QSqlQuery query(db);
    query.prepare("INSERT INTO query_history (connection_id, query_text, created_at) VALUES (?, ?, ?)");
    query.addBindValue(item.connectionId);
    query.addBindValue(item.query);
    query.addBindValue(QDateTime::currentDateTime());

    if (!query.exec()) {
        m_logger->error("Failed to save query history: " + query.lastError().text());
    }
}

std::vector<QueryHistoryItem> LocalStoreService::getQueryHistory(int connectionId)
{
    std::vector<QueryHistoryItem> results;
    auto db = getDatabase();
    if (!db.open()) return results;

    QSqlQuery query(db);
    query.prepare("SELECT id, connection_id, query_text, created_at FROM query_history WHERE connection_id = ? ORDER BY created_at DESC LIMIT 50");
    query.addBindValue(connectionId);

    if (query.exec()) {
        while (query.next()) {
            QueryHistoryItem item;
            item.id = query.value(0).toInt();
            item.connectionId = query.value(1).toInt();
            item.query = query.value(2).toString();
            item.createdAt = query.value(3).toDateTime();
            results.push_back(item);
        }
    } else {
        m_logger->error("Failed to fetch query history: " + query.lastError().text());
    }
    return results;
}

int LocalStoreService::saveView(const ViewData& data)
{
    auto db = getDatabase();
    if (!db.open()) return -1;
    
    QSqlQuery query(db);
    if (data.id == -1) {
        query.prepare("INSERT INTO views (connection_id, source_ref, name, definition_json, created_at) VALUES (?, ?, ?, ?, ?)");
        query.addBindValue(data.connectionId);
        query.addBindValue(data.sourceRef);
        query.addBindValue(data.name);
        query.addBindValue(data.definitionJson);
        query.addBindValue(QDateTime::currentDateTime());
    } else {
        query.prepare("UPDATE views SET connection_id=?, source_ref=?, name=?, definition_json=? WHERE id=?");
        query.addBindValue(data.connectionId);
        query.addBindValue(data.sourceRef);
        query.addBindValue(data.name);
        query.addBindValue(data.definitionJson);
        query.addBindValue(data.id);
    }
    
    if (query.exec()) {
        if (data.id == -1) {
            return query.lastInsertId().toInt();
        }
        return data.id;
    } else {
        m_logger->error("Failed to save view: " + query.lastError().text());
        return -1;
    }
}

std::vector<ViewData> LocalStoreService::getViews(int connectionId, const QString& sourceRef)
{
    std::vector<ViewData> results;
    auto db = getDatabase();
    if (!db.open()) return results;
    
    QSqlQuery query(db);
    query.prepare("SELECT id, connection_id, source_ref, name, definition_json, created_at FROM views WHERE connection_id = ? AND source_ref = ? ORDER BY name ASC");
    query.addBindValue(connectionId);
    query.addBindValue(sourceRef);
    
    if (query.exec()) {
        while (query.next()) {
            ViewData item;
            item.id = query.value(0).toInt();
            item.connectionId = query.value(1).toInt();
            item.sourceRef = query.value(2).toString();
            item.name = query.value(3).toString();
            item.definitionJson = query.value(4).toString();
            item.createdAt = query.value(5).toDateTime();
            results.push_back(item);
        }
    } else {
        m_logger->error("Failed to fetch views: " + query.lastError().text());
    }
    return results;
}

void LocalStoreService::deleteView(int id)
{
    auto db = getDatabase();
    if (!db.open()) return;
    
    QSqlQuery query(db);
    query.prepare("DELETE FROM views WHERE id = ?");
    query.addBindValue(id);
    
    if (!query.exec()) {
        m_logger->error("Failed to delete view: " + query.lastError().text());
    }
}

}
