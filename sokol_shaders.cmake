function(_sokol_shader_get_binary result_var)
    set(shdc_root "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/bin")

    # sokol-shdc is executed during the build, so select it for the host
    # running CMake, not for the target platform (for example, iOS).
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(AMD64|amd64|x86_64)$")
            set(bin_path "${shdc_root}/win32/sokol-shdc.exe")
        elseif(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(ARM64|arm64|aarch64)$")
            message(FATAL_ERROR "Windows ARM64 is not supported by sokol-shdc")
        elseif(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(x86|X86|i[3-6]86)$")
            message(FATAL_ERROR "32-bit Windows is not supported by sokol-shdc")
        else()
            message(FATAL_ERROR
                "Unsupported Windows host architecture: ${CMAKE_HOST_SYSTEM_PROCESSOR}"
            )
        endif()
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
            set(bin_path "${shdc_root}/osx_arm64/sokol-shdc")
        elseif(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64)$")
            set(bin_path "${shdc_root}/osx/sokol-shdc")
        else()
            message(FATAL_ERROR
                "Unsupported macOS host architecture: ${CMAKE_HOST_SYSTEM_PROCESSOR}"
            )
        endif()
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")
        if(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
            set(bin_path "${shdc_root}/linux_arm64/sokol-shdc")
        elseif(CMAKE_HOST_SYSTEM_PROCESSOR MATCHES "^(x86_64|amd64)$")
            set(bin_path "${shdc_root}/linux/sokol-shdc")
        else()
            message(FATAL_ERROR
                "Unsupported Linux host architecture: ${CMAKE_HOST_SYSTEM_PROCESSOR}"
            )
        endif()
    else()
        message(FATAL_ERROR
            "Unsupported host platform: ${CMAKE_HOST_SYSTEM_NAME}-${CMAKE_HOST_SYSTEM_PROCESSOR}"
        )
    endif()

    if(NOT EXISTS "${bin_path}")
        message(FATAL_ERROR "sokol-shdc binary not found: ${bin_path}")
    endif()

    set("${result_var}" "${bin_path}" PARENT_SCOPE)
endfunction()

function(_sokol_shader_add_command shd slang)
    set(options DEBUGGABLE REFLECTION)
    set(one_value_args MODULE DEFINES)
    cmake_parse_arguments(SHADER "${options}" "${one_value_args}" "" ${ARGN})

    _sokol_shader_get_binary(bin_path)

    if(CMAKE_C_COMPILER_ID STREQUAL "MSVC")
        set(errfmt msvc)
    else()
        set(errfmt gcc)
    endif()

    set(input_path "${CMAKE_CURRENT_SOURCE_DIR}/${shd}")
    if(DEFINED SHADER_MODULE)
        set(output_path
            "${CMAKE_CURRENT_BINARY_DIR}/compile_shaders/${shd}.${SHADER_MODULE}.h"
        )
    else()
        set(output_path "${CMAKE_CURRENT_BINARY_DIR}/compile_shaders/${shd}.h")
    endif()
    get_filename_component(output_dir "${output_path}" DIRECTORY)

    set(shdc_args
        --input "${input_path}"
        --output "${output_path}"
        --slang "${slang}"
        --genver 5
        --errfmt "${errfmt}"
        --format sokol
    )

    if(DEFINED SHADER_DEFINES)
        list(APPEND shdc_args --defines "${SHADER_DEFINES}")
    endif()

    if(DEFINED SHADER_MODULE)
        list(APPEND shdc_args --module "${SHADER_MODULE}")
    endif()

    if(SHADER_REFLECTION)
        list(APPEND shdc_args --reflection)
    endif()

    if(NOT SHADER_DEBUGGABLE)
        list(APPEND shdc_args --bytecode)
    endif()

    add_custom_command(
        OUTPUT "${output_path}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${output_dir}"
        COMMAND "${bin_path}" ${shdc_args}
        DEPENDS
            "${input_path}"
            "${bin_path}"
        COMMENT "Compile shader: ${shd}"
        VERBATIM
    )
endfunction()

function(sokol_shader shd slang)
    _sokol_shader_add_command("${shd}" "${slang}")
endfunction()

function(sokol_shader_debuggable shd slang)
    _sokol_shader_add_command("${shd}" "${slang}" DEBUGGABLE)
endfunction()

function(sokol_shader_variant shd slang module defines)
    _sokol_shader_add_command(
        "${shd}"
        "${slang}"
        MODULE "${module}"
        DEFINES "${defines}"
    )
endfunction()

function(sokol_shader_with_reflection shd slang)
    _sokol_shader_add_command("${shd}" "${slang}" REFLECTION)
endfunction()

function(sokol_shader_variant_with_reflection shd slang module defines)
    _sokol_shader_add_command(
        "${shd}"
        "${slang}"
        MODULE "${module}"
        DEFINES "${defines}"
        REFLECTION
    )
endfunction()
