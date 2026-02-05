set(CMAKE_AUTOMOC ON)
qt_policy(SET QTP0001 NEW)

qt_add_library(SofaUI STATIC)

target_link_libraries(SofaUI PUBLIC Qt6::Quick Qt6::Core SofaCore)
if (TARGET Qt6::Core5Compat)
    target_link_libraries(SofaUI PUBLIC Qt6::Core5Compat)
endif()

set_source_files_properties(Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(SofaUI
    URI sofa.ui
    VERSION 1.0
    QML_FILES
        Button.qml
        Theme.qml
        AppButton.qml
    AppTextField.qml
    AppHeader.qml
    AppSidebar.qml
    AppTabs.qml
    ConnectionDialog.qml
    ConnectionForm.qml
    DatabaseExplorer.qml
        DataGrid.qml
        SqlConsole.qml
        ViewEditor.qml
        ConnectionSelectorModal.qml
        ConnectionErrorModal.qml
    RESOURCES
        assets/table-list-solid-full.svg
        assets/table-cells-large-solid-full.svg
        assets/buffer-brands-solid-full.svg
        assets/database-solid-full.svg
        assets/eye-slash-solid-full.svg
        assets/gear-solid-full.svg
        assets/logo.svg
        assets/bookmark-solid-full.svg
        assets/folder-tree-solid-full.svg
        assets/plug-solid-full.svg
    )

target_include_directories(SofaUI PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
