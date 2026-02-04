qt_add_library(SofaAddonPostgres STATIC
    SofaAddonPostgres.h
    SofaAddonPostgres.cpp
)

target_link_libraries(SofaAddonPostgres PUBLIC Qt6::Core SofaCore)

target_include_directories(SofaAddonPostgres PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
