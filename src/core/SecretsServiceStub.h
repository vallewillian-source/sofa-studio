#pragma once
#include "ISecretsService.h"

namespace Sofa::Core {

class SecretsServiceStub : public ISecretsService {
public:
    QString getSecret(const QString& ref) override {
        // Stub implementation
        return "";
    }

    QString storeSecret(const QString& value) override {
        // Stub implementation: don't actually store sensitive data yet
        return "stub-ref"; 
    }
};

}
