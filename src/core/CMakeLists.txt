set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Sql)

qt_add_library(SofaCore STATIC
    SofaCore.h
    SofaCore.cpp
    ILogger.h
    ConsoleLogger.h
    ConsoleLogger.cpp
    ICommandService.h
    CommandService.h
    CommandService.cpp
    AppContext.h
    AppContext.cpp
    ILocalStoreService.h
    LocalStoreService.h
    LocalStoreService.cpp
    ISecretsService.h
    SecretsServiceStub.h
    SimpleSecretsService.h
    SimpleSecretsService.cpp
    udm/UDM.h
    addons/IAddon.h
    AddonHost.h
    AddonHost.cpp
)

target_link_libraries(SofaCore PUBLIC Qt6::Core Qt6::Sql)

target_include_directories(SofaCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
