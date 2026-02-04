#include "AppContext.h"

namespace Sofa::Core {

AppContext::AppContext(std::shared_ptr<ICommandService> commandService,
                       std::shared_ptr<ILogger> logger,
                       QObject* parent)
    : QObject(parent)
    , m_commandService(std::move(commandService))
    , m_logger(std::move(logger))
{
}

void AppContext::executeCommand(const QString& id)
{
    if (m_commandService) {
        m_commandService->execute(id);
    } else if (m_logger) {
        m_logger->error("CommandService is not available");
    }
}

}
