macro(sokol_shader shd slang)
    # FIXME: debug shaders
    set(args "{slang: '${slang}', compiler: '${CMAKE_C_COMPILER_ID}' }")
    fips_generate(TYPE SokolShader FROM ${shd} HEADER ${shd}.h OUT_OF_SOURCE ARGS ${args})
endmacro()
