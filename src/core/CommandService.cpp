#include "CommandService.h"

namespace Sofa::Core {

CommandService::CommandService(std::shared_ptr<ILogger> logger)
    : m_logger(std::move(logger))
{
}

void CommandService::registerCommand(const QString& id, const QString& title, CommandCallback callback)
{
    if (m_commands.contains(id)) {
        if (m_logger) {
            m_logger->warning("Overwriting command with ID: " + id);
        }
    }

    m_commands.insert(id, {id, title, std::move(callback)});
    if (m_logger) {
        m_logger->info("Command registered: " + id);
    }
}

void CommandService::execute(const QString& id)
{
    if (!m_commands.contains(id)) {
        if (m_logger) {
            m_logger->error("Command not found: " + id);
        }
        return;
    }

    const auto& cmd = m_commands[id];
    if (m_logger) {
        m_logger->info("Executing command: " + id);
    }
    
    if (cmd.callback) {
        cmd.callback();
    }
}

}
