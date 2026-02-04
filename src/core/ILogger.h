#pragma once

#include <QString>

namespace Sofa::Core {

class ILogger {
public:
    virtual ~ILogger() = default;
    virtual void info(const QString& message) = 0;
    virtual void warning(const QString& message) = 0;
    virtual void error(const QString& message) = 0;
};

}
