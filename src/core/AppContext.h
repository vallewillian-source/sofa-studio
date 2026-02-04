#pragma once

#include <QObject>
#include <memory>
#include "ICommandService.h"
#include "ILogger.h"

namespace Sofa::Core {

class AppContext : public QObject {
    Q_OBJECT
public:
    explicit AppContext(std::shared_ptr<ICommandService> commandService,
                       std::shared_ptr<ILogger> logger,
                       QObject* parent = nullptr);

    Q_INVOKABLE void executeCommand(const QString& id);

private:
    std::shared_ptr<ICommandService> m_commandService;
    std::shared_ptr<ILogger> m_logger;
};

}
