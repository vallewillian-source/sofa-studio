set(CMAKE_AUTOMOC ON)

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
)

target_link_libraries(SofaCore PUBLIC Qt6::Core)

target_include_directories(SofaCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
