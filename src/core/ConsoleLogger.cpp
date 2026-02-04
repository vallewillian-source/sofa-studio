#include "ConsoleLogger.h"
#include <QDebug>
#include <iostream>

namespace Sofa::Core {

void ConsoleLogger::info(const QString& message) {
    qInfo() << "[INFO]" << message;
}

void ConsoleLogger::warning(const QString& message) {
    qWarning() << "[WARN]" << message;
}

void ConsoleLogger::error(const QString& message) {
    qCritical() << "[ERROR]" << message;
}

}
