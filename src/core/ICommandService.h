#pragma once

#include <QString>
#include <functional>

namespace Sofa::Core {

using CommandCallback = std::function<void()>;

class ICommandService {
public:
    virtual ~ICommandService() = default;
    virtual void registerCommand(const QString& id, const QString& title, CommandCallback callback) = 0;
    virtual void execute(const QString& id) = 0;
};

}
