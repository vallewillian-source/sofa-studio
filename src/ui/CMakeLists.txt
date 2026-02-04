set(CMAKE_AUTOMOC ON)
qt_policy(SET QTP0001 NEW)

qt_add_library(SofaUI STATIC)

target_link_libraries(SofaUI PUBLIC Qt6::Quick Qt6::Core SofaCore)

qt_add_qml_module(SofaUI
    URI sofa.ui
    VERSION 1.0
    QML_FILES
        Button.qml
)

target_include_directories(SofaUI PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
