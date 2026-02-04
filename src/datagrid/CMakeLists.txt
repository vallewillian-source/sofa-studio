qt_add_library(SofaDataGrid STATIC
    SofaDataGrid.h
    SofaDataGrid.cpp
)

target_link_libraries(SofaDataGrid PUBLIC Qt6::Quick Qt6::Core SofaCore)

target_include_directories(SofaDataGrid PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
