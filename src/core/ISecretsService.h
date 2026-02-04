#pragma once
#include <QString>

namespace Sofa::Core {

class ISecretsService {
public:
    virtual ~ISecretsService() = default;
    
    virtual QString getSecret(const QString& ref) = 0;
    virtual QString storeSecret(const QString& value) = 0;
};

}
