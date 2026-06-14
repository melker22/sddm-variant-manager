cmake_minimum_required(VERSION 3.16)

project(sddm-variant-manager VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Multimedia)
find_package(KF6Kirigami 6.0 REQUIRED)
find_package(KF6KirigamiPlatform 6.0 REQUIRED)
find_package(KF6CoreAddons 6.0 REQUIRED)
find_package(KF6I18n 6.0 REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(sddm-variant-manager
    src/main.cpp
    src/themescanner.cpp
    src/themeapplier.cpp
    src/greeterpreview.cpp
)

qt_add_qml_module(sddm-variant-manager
    URI org.github.melker.sddmvariantmanager
    VERSION 1.0
    QML_FILES
        src/qml/Main.qml
)

target_link_libraries(sddm-variant-manager PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
    KF6::CoreAddons
    KF6::I18n
    KF6::Kirigami
    KF6::KirigamiPlatform
)

qt_import_qml_plugins(sddm-variant-manager)

install(TARGETS sddm-variant-manager RUNTIME DESTINATION bin)
install(FILES org.github.melker.sddmvariantmanager.desktop DESTINATION share/applications)
install(FILES org.github.melker.sddmvariantmanager.appdata.xml DESTINATION share/metainfo)
