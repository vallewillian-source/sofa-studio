qt_add_library(SofaCore STATIC
    SofaCore.h
    SofaCore.cpp
)

target_link_libraries(SofaCore PUBLIC Qt6::Core)

target_include_directories(SofaCore PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
