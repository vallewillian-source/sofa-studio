#pragma once

#include "ILogger.h"

namespace Sofa::Core {

class ConsoleLogger : public ILogger {
public:
    void info(const QString& message) override;
    void warning(const QString& message) override;
    void error(const QString& message) override;
};

}
