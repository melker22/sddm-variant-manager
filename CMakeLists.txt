cmake_minimum_required(VERSION 3.16)

project(sddm-variant-manager VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Multimedia Concurrent)
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
    src/themeinstaller.cpp
)

qt_add_resources(sddm-variant-manager "app_qml"
    PREFIX "/"
    FILES
        src/qml/Main.qml
        src/qml/AppColorScheme.qml
        src/qml/ThemeListItem.qml
        src/qml/qmldir
)

qt_add_resources(sddm-variant-manager "app_icons"
    PREFIX "/icons/hicolor/scalable/apps"
    FILES
        icons/hicolor/scalable/apps/org.github.melker.sddmvariantmanager.svg
        icons/hicolor/scalable/apps/org.github.melker.sddmvariantmanager-dark.svg
)

target_link_libraries(sddm-variant-manager PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
    Qt6::Concurrent
    KF6::CoreAddons
    KF6::I18n
    KF6::Kirigami
    KF6::KirigamiPlatform
)

# Kirigami QML plugins are loaded at runtime from the system QML path.
# Disable Qt's import scanner to avoid harmless "plugin will not be linked" warnings.
set_target_properties(sddm-variant-manager PROPERTIES
    QT_QML_MODULE_NO_IMPORT_SCAN TRUE
)

install(TARGETS sddm-variant-manager RUNTIME DESTINATION bin)
install(FILES org.github.melker.sddmvariantmanager.desktop DESTINATION share/applications)
install(FILES org.github.melker.sddmvariantmanager.appdata.xml DESTINATION share/metainfo)
install(DIRECTORY icons/hicolor/ DESTINATION share/icons/hicolor)
