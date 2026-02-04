#pragma once

#include "ICommandService.h"
#include "ILogger.h"
#include <QMap>
#include <memory>

namespace Sofa::Core {

class CommandService : public ICommandService {
public:
    explicit CommandService(std::shared_ptr<ILogger> logger);
    
    void registerCommand(const QString& id, const QString& title, CommandCallback callback) override;
    void execute(const QString& id) override;

private:
    struct Command {
        QString id;
        QString title;
        CommandCallback callback;
    };

    std::shared_ptr<ILogger> m_logger;
    QMap<QString, Command> m_commands;
};

}
