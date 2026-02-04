#pragma once

#include "ISecretsService.h"
#include <QObject>
#include <QMap>
#include <QString>
#include <QMutex>

namespace Sofa::Core {

class SimpleSecretsService : public ISecretsService {
public:
    explicit SimpleSecretsService(QObject* parent = nullptr);
    ~SimpleSecretsService() override;

    QString getSecret(const QString& ref) override;
    QString storeSecret(const QString& value) override;

private:
    void loadSecrets();
    void saveSecrets();
    QString getSecretsFilePath() const;

    QMap<QString, QString> m_secrets;
    QMutex m_mutex;
};

} // namespace Sofa::Core
