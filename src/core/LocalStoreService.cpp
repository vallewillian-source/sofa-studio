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

    bool hasColorColumn = false;
    QSqlQuery columnQuery(db);
    if (columnQuery.exec("PRAGMA table_info(connections)")) {
        while (columnQuery.next()) {
            if (columnQuery.value(1).toString() == "color") {
                hasColorColumn = true;
                break;
            }
        }
    }
    if (!hasColorColumn) {
        QSqlQuery alterQuery(db);
        if (!alterQuery.exec("ALTER TABLE connections ADD COLUMN color TEXT DEFAULT '#FFA507'")) {
            m_logger->error("Failed to add color column to connections table: " + alterQuery.lastError().text());
        }
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
    
    QString createSettingsTable = R"(
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    )";

    if (!query.exec(createSettingsTable)) {
        m_logger->error("Failed to create settings table: " + query.lastError().text());
    }
}

void LocalStoreService::saveSetting(const QString& key, const QVariant& value)
{
    auto db = getDatabase();
    if (!db.isOpen() && !db.open()) return;

    QSqlQuery query(db);
    query.prepare("INSERT OR REPLACE INTO settings (key, value) VALUES (:key, :value)");
    query.bindValue(":key", key);
    
    // Serialize complex types to JSON string if needed, or rely on QVariant string conversion
    // For simple persistence, string is safest in SQLite
    if (value.typeId() == QMetaType::QVariantList || value.typeId() == QMetaType::QVariantMap) {
         // TODO: Use QJsonDocument if we had it included, but for now let's assume simple types or manual serialization
         // Actually, let's include QJsonDocument to be safe
    }
    query.bindValue(":value", value.toString()); // Basic string conversion

    if (!query.exec()) {
        m_logger->error("Failed to save setting " + key + ": " + query.lastError().text());
    }
}

QVariant LocalStoreService::getSetting(const QString& key, const QVariant& defaultValue)
{
    auto db = getDatabase();
    if (!db.isOpen() && !db.open()) return defaultValue;

    QSqlQuery query(db);
    query.prepare("SELECT value FROM settings WHERE key = :key");
    query.bindValue(":key", key);

    if (query.exec() && query.next()) {
        return query.value(0);
    }
    return defaultValue;
}

std::vector<ConnectionData> LocalStoreService::getAllConnections()
{
    std::vector<ConnectionData> results;
    auto db = getDatabase();
    if (!db.open()) return results;

    QSqlQuery query(db);
    if (query.exec("SELECT id, name, host, port, database, user, color, secret_ref, created_at, updated_at FROM connections ORDER BY name ASC")) {
        while (query.next()) {
            ConnectionData data;
            data.id = query.value(0).toInt();
            data.name = query.value(1).toString();
            data.host = query.value(2).toString();
            data.port = query.value(3).toInt();
            data.database = query.value(4).toString();
            data.user = query.value(5).toString();
            data.color = query.value(6).toString();
            data.secretRef = query.value(7).toString();
            data.createdAt = query.value(8).toDateTime();
            data.updatedAt = query.value(9).toDateTime();
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
    
    QString color = data.color;
    if (color.isEmpty()) {
        color = "#FFA507";
    }

    QSqlQuery query(db);
    if (data.id == -1) {
        query.prepare("INSERT INTO connections (name, host, port, database, user, color, secret_ref, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
        query.addBindValue(data.name);
        query.addBindValue(data.host);
        query.addBindValue(data.port);
        query.addBindValue(data.database);
        query.addBindValue(data.user);
        query.addBindValue(color);
        query.addBindValue(data.secretRef);
        query.addBindValue(QDateTime::currentDateTime());
        query.addBindValue(QDateTime::currentDateTime());
    } else {
        query.prepare("UPDATE connections SET name=?, host=?, port=?, database=?, user=?, color=?, secret_ref=?, updated_at=? WHERE id=?");
        query.addBindValue(data.name);
        query.addBindValue(data.host);
        query.addBindValue(data.port);
        query.addBindValue(data.database);
        query.addBindValue(data.user);
        query.addBindValue(color);
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

}
