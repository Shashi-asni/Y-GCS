# Keep the bundled application runtime private while exposing freedesktop
# metadata and a launcher in their standard system locations.
#
# This script runs in CPack's script context, where the project variables are
# not defined. CPACK_PACKAGE_NAME carries the application name (e.g. "Y-GCS"),
# so every path below is derived from it instead of hard-coding a product name.

set(_qgc_app_name "${CPACK_PACKAGE_NAME}")
if(NOT _qgc_app_name)
    message(FATAL_ERROR "QGC: CPACK_PACKAGE_NAME is unavailable")
endif()

set(_qgc_app_prefix "opt/${_qgc_app_name}")

if(DEFINED QGC_NATIVE_PACKAGE_ROOT AND NOT QGC_NATIVE_PACKAGE_ROOT STREQUAL "")
    set(_qgc_package_roots "${QGC_NATIVE_PACKAGE_ROOT}")
elseif(DEFINED CPACK_TEMPORARY_DIRECTORY AND IS_DIRECTORY "${CPACK_TEMPORARY_DIRECTORY}")
    file(
        GLOB_RECURSE _qgc_staged_entries
        LIST_DIRECTORIES false
        "${CPACK_TEMPORARY_DIRECTORY}/*"
    )
    set(_qgc_package_roots "")
    foreach(qgc_entry IN LISTS _qgc_staged_entries)
        if(qgc_entry MATCHES "/${_qgc_app_prefix}/bin/${_qgc_app_name}$")
            string(REGEX REPLACE "/${_qgc_app_prefix}/bin/${_qgc_app_name}$" "" _qgc_root "${qgc_entry}")
            list(APPEND _qgc_package_roots "${_qgc_root}")
        endif()
    endforeach()
    list(REMOVE_DUPLICATES _qgc_package_roots)
else()
    message(FATAL_ERROR "QGC: native package root is unavailable")
endif()

if(NOT _qgc_package_roots)
    message(FATAL_ERROR "QGC: no staged /${_qgc_app_prefix}/bin/${_qgc_app_name} executable found")
endif()

foreach(qgc_root IN LISTS _qgc_package_roots)
    set(_qgc_private_root "${qgc_root}/${_qgc_app_prefix}")
    if(NOT EXISTS "${_qgc_private_root}/bin/${_qgc_app_name}")
        message(FATAL_ERROR "QGC: incomplete private runtime at ${_qgc_private_root}")
    endif()

    file(GLOB _qgc_qt_core "${_qgc_private_root}/lib/libQt6Core.so*" "${_qgc_private_root}/lib64/libQt6Core.so*")
    if(NOT _qgc_qt_core)
        message(
            FATAL_ERROR "QGC: bundled Qt Core is missing under ${_qgc_private_root}/lib or ${_qgc_private_root}/lib64"
        )
    endif()

    set(_qgc_launcher "${qgc_root}/usr/bin/${_qgc_app_name}")
    if(EXISTS "${_qgc_launcher}" OR IS_SYMLINK "${_qgc_launcher}")
        message(FATAL_ERROR "QGC: native package launcher already exists: ${_qgc_launcher}")
    endif()

    file(MAKE_DIRECTORY "${qgc_root}/usr/share")
    foreach(qgc_data_dir IN ITEMS applications icons metainfo)
        set(_qgc_source "${_qgc_private_root}/share/${qgc_data_dir}")
        set(_qgc_destination "${qgc_root}/usr/share/${qgc_data_dir}")
        if(NOT EXISTS "${_qgc_source}")
            message(FATAL_ERROR "QGC: required native package metadata is missing: ${_qgc_source}")
        endif()
        if(EXISTS "${_qgc_destination}")
            message(FATAL_ERROR "QGC: native package destination already exists: ${_qgc_destination}")
        endif()
        file(RENAME "${_qgc_source}" "${_qgc_destination}")
    endforeach()

    file(GLOB _qgc_desktop_files "${qgc_root}/usr/share/applications/*.desktop")
    if(NOT _qgc_desktop_files)
        message(FATAL_ERROR "QGC: desktop entry is missing from the native package payload")
    endif()

    file(GLOB _qgc_appdata_files "${qgc_root}/usr/share/metainfo/*.appdata.xml")
    if(NOT _qgc_appdata_files)
        message(FATAL_ERROR "QGC: AppStream metadata is missing from the native package payload")
    endif()

    file(GLOB _qgc_icon_256 "${qgc_root}/usr/share/icons/hicolor/256x256/apps/${_qgc_app_name}.png")
    file(GLOB _qgc_icon_svg "${qgc_root}/usr/share/icons/hicolor/scalable/apps/${_qgc_app_name}.svg")
    if(NOT _qgc_icon_256 OR NOT _qgc_icon_svg)
        message(FATAL_ERROR "QGC: application icons are missing from the native package payload")
    endif()

    file(
        GLOB _qgc_remaining_share_entries
        LIST_DIRECTORIES true
        "${_qgc_private_root}/share/*"
    )
    if(NOT _qgc_remaining_share_entries)
        file(REMOVE_RECURSE "${_qgc_private_root}/share")
    endif()

    file(MAKE_DIRECTORY "${qgc_root}/usr/bin")
    file(CREATE_LINK "../../${_qgc_app_prefix}/bin/${_qgc_app_name}" "${_qgc_launcher}" SYMBOLIC RESULT _qgc_link_result)
    if(NOT _qgc_link_result STREQUAL "0")
        message(FATAL_ERROR "QGC: failed to create native package launcher: ${_qgc_link_result}")
    endif()

    message(STATUS "QGC: finalized private native runtime under /${_qgc_app_prefix}")
endforeach()
