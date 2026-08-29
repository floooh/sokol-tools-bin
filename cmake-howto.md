# CMake usage

Include `sokol_shaders.cmake` in your project and add the generated headers to
the target sources. This makes CMake run `sokol-shdc` before compiling the
application.

Example project layout:

```text
my-project/
├── CMakeLists.txt
├── main.c
├── shaders/
│   └── triangle.glsl
└── third_party/
    └── sokol-tools-bin/
        ├── sokol_shaders.cmake
        └── bin/
```

Minimal `CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.17)

project(SimpleApp LANGUAGES C)

include("${CMAKE_CURRENT_LIST_DIR}/third_party/sokol-tools-bin/sokol_shaders.cmake")

set(SHADER "shaders/triangle.glsl")

# The second argument selects shader target languages for the backends:
#   glsl410       - desktop OpenGL 4.1
#   glsl430       - OpenGL
#   metal_macos   - Metal on macOS
#   metal_ios     - Metal on iOS devices
#   metal_sim     - Metal on the iOS Simulator
#   glsl300es     - OpenGL ES 3 / WebGL 2
#   glsl310es     - GLES3.1 (currently not supported by sokol_gfx.h)
#   hlsl4         - Direct3D 11 with HLSL 4
#   hlsl5         - Direct3D 11 on Windows
#   wgsl          - WebGPU
#   spirv_vk      - Vulkan/SPIR-V
# Choose only one of glsl410/glsl430 and one of hlsl4/hlsl5.
# Multiple backends can be specified with a colon, for example:
#   "glsl430:metal_macos:metal_ios:metal_sim:glsl300es:glsl310es:hlsl5:wgsl:spirv_vk"
sokol_shader(
    "${SHADER}"
    "glsl430:metal_macos:metal_ios:metal_sim:glsl300es:glsl310es:hlsl5:wgsl:spirv_vk"
)

set(SHADER_HEADER
    "${CMAKE_CURRENT_BINARY_DIR}/compile_shaders/${SHADER}.h"
)

add_executable(SimpleApp
    main.c
    "${SHADER_HEADER}"
)

target_include_directories(SimpleApp PRIVATE
    "${CMAKE_CURRENT_BINARY_DIR}/compile_shaders"
)
```

For the complete `sokol-shdc` documentation, see the [official documentation](https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md).

The generated header can then be included from `main.c`:

```c
#include "shaders/triangle.glsl.h"
```

### Shader functions

The CMake functions correspond to the Fips shader helpers:

```cmake
# Regular shader: generates bytecode.
sokol_shader("shaders/triangle.glsl" "glsl430")

# Debuggable shader: does not generate Metal/HLSL bytecode.
sokol_shader_debuggable("shaders/triangle.glsl" "glsl430")

# Shader variant with preprocessor defines and a module name.
sokol_shader_variant(
    "shaders/triangle.glsl"
    "glsl430"
    "mobile"
    "USE_MOBILE:USE_FOG"
)

# Regular shader with runtime reflection data.
sokol_shader_with_reflection("shaders/triangle.glsl" "glsl430")

# Variant with both defines/module and runtime reflection data.
sokol_shader_variant_with_reflection(
    "shaders/triangle.glsl"
    "glsl430"
    "mobile_reflection"
    "USE_MOBILE:USE_FOG"
)
```

For a variant, the generated header is named after the module, for example:

```text
compile_shaders/shaders/triangle.glsl.mobile.h
```

Add every generated header used by the application to `target_sources()`:

```cmake
set(SHADER_VARIANT_HEADER
    "${CMAKE_CURRENT_BINARY_DIR}/compile_shaders/shaders/triangle.glsl.mobile.h"
)

target_sources(SimpleApp PRIVATE
    "${SHADER_VARIANT_HEADER}"
)
```

Do not generate two variants with the same input and module/output name in one
directory. The regular, debuggable, and reflection helpers intentionally use
the same output name, so choose one for a given shader or place different
configurations in separate build directories.

The compiler is selected for the host running CMake, which also supports
cross-compilation targets such as iOS. Windows ARM64 and 32-bit Windows are
not supported because this repository contains only a Windows x86-64 binary.
