cmake_minimum_required(VERSION 3.16)

project(SofaStudio VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find Qt6
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Svg)
find_package(Qt6 OPTIONAL_COMPONENTS ShaderTools QuickEffects Core5Compat)

# Add subdirectories
add_subdirectory(src/core)
add_subdirectory(src/datagrid)
add_subdirectory(src/ui)
add_subdirectory(addons/postgres)
add_subdirectory(apps/desktop)
