#include "SimpleSecretsService.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>
#include <QDebug>

namespace Sofa::Core {

SimpleSecretsService::SimpleSecretsService(QObject* parent)
    : ISecretsService() // ISecretsService is pure virtual, no constructor to call usually, but good practice if it had one
{
    loadSecrets();
}

SimpleSecretsService::~SimpleSecretsService()
{
}

QString SimpleSecretsService::getSecretsFilePath() const
{
    QString dataLocation = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir(dataLocation);
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    return dir.filePath("secrets.json");
}

void SimpleSecretsService::loadSecrets()
{
    QMutexLocker locker(&m_mutex);
    QFile file(getSecretsFilePath());
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }

    QByteArray data = file.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject obj = doc.object();

    m_secrets.clear();
    for (auto it = obj.begin(); it != obj.end(); ++it) {
        m_secrets.insert(it.key(), it.value().toString());
    }
}

void SimpleSecretsService::saveSecrets()
{
    // Ensure mutex is locked by caller or lock here. 
    // Since this is private and called by public methods which lock, we assume lock is held or we don't lock recursively if QMutex is not recursive.
    // Let's rely on public methods locking. Actually, to be safe, let's not call this with lock held if we lock inside.
    // Simplest pattern: Public methods lock, modify memory, then call save (which does IO). 
    // But IO under lock is bad for performance, but for this simple app it's fine for data integrity.
    
    QFile file(getSecretsFilePath());
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to open secrets file for writing:" << getSecretsFilePath();
        return;
    }

    QJsonObject obj;
    for (auto it = m_secrets.begin(); it != m_secrets.end(); ++it) {
        obj.insert(it.key(), it.value());
    }

    QJsonDocument doc(obj);
    file.write(doc.toJson());
}

QString SimpleSecretsService::getSecret(const QString& ref)
{
    QMutexLocker locker(&m_mutex);
    return m_secrets.value(ref);
}

QString SimpleSecretsService::storeSecret(const QString& value)
{
    QMutexLocker locker(&m_mutex);
    
    // Check if value already exists to reuse ref? No, security wise better to generate new.
    // Or check if we are updating? The interface is simple store.
    
    QString ref = QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_secrets.insert(ref, value);
    
    // Save to disk immediately
    saveSecrets();
    
    return ref;
}

} // namespace Sofa::Core
