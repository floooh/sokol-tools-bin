//! Helper code to invoke sokol-shdc from the Zig build system.
//! See https://github.com/floooh/sokol-zig for an example
//! of how to use sokol-tools-bin as a lazy dependency and
//! compile shaders (search for `shdc.compile` in the sokol-zig build.zig)
const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Build = std.Build;

pub const Options = struct {
    dep_shdc: *Build.Dependency,
    input: Build.LazyPath,
    output: Build.LazyPath,
    slang: Slang,
    format: Format = .sokol_zig,
    tmp_dir: ?Build.LazyPath = null,
    defines: ?[][]const u8 = null,
    module: ?[]const u8 = null,
    reflection: bool = false,
    bytecode: bool = false,
    dump: bool = false,
    genver: ?[]const u8 = null,
    ifdef: bool = false,
    noifdef: bool = false,
    save_intermediate_spirv: bool = false,
    no_log_cmdline: bool = true,
};

pub fn compile(b: *Build, opts: Options) !*Build.Step.Run {
    const shdc_path = try getShdcLazyPath(opts.dep_shdc);
    const args = try optsToArgs(opts, b, shdc_path);
    var step = b.addSystemCommand(args);
    step.addFileArg(opts.input);
    return step;
}

/// target shader languages
/// NOTE: make sure that field names match the cmdline arg string
pub const Slang = packed struct(u10) {
    glsl410: bool = false,
    glsl430: bool = false,
    glsl300es: bool = false,
    glsl310es: bool = false,
    hlsl4: bool = false,
    hlsl5: bool = false,
    metal_macos: bool = false,
    metal_ios: bool = false,
    metal_sim: bool = false,
    wgsl: bool = false,
};

fn slangToString(slang: Slang, a: Allocator) ![]const u8 {
    var strings: [16][]const u8 = undefined;
    var num_strings: usize = 0;
    inline for (std.meta.fields(Slang)) |field| {
        if (@field(slang, field.name)) {
            strings[num_strings] = field.name;
            num_strings += 1;
        }
    }
    return std.mem.join(a, ":", strings[0..num_strings]);
}

/// the code-generation target language
/// NOTE: make sure that the item names match the cmdline arg string
pub const Format = enum {
    sokol,
    sokol_impl,
    sokol_zig,
    sokol_nim,
    sokol_odin,
    sokol_rust,
    sokol_d,
    sokol_jai,
};

fn formatToString(f: Format) []const u8 {
    return @tagName(f);
}

fn getShdcLazyPath(dep_shdc: *Build.Dependency) !Build.LazyPath {
    const intel = builtin.cpu.arch.isX86();
    const opt_sub_path: ?[]const u8 = switch (builtin.os.tag) {
        .windows => "bin/win32/sokol-shdc.exe",
        .linux => if (intel) "bin/linux/sokol-shdc" else "bin/linux_arm64/sokol-shdc",
        .macos => if (intel) "bin/osx/sokol-shdc" else "bin/osx_arm64/sokol-shdc",
        else => null,
    };
    if (opt_sub_path) |sub_path| {
        return dep_shdc.path(sub_path);
    } else {
        return error.ShdcUnsupportedPlatform;
    }
}

fn optsToArgs(opts: Options, b: *Build, tool_path: Build.LazyPath) ![]const []const u8 {
    const a = b.allocator;
    var arr: std.ArrayListUnmanaged([]const u8) = .empty;
    try arr.append(a, tool_path.getPath(b));
    try arr.appendSlice(a, &.{ "-o", opts.output.getPath(b) });
    try arr.appendSlice(a, &.{ "-l", try slangToString(opts.slang, a) });
    try arr.appendSlice(a, &.{ "-f", formatToString(opts.format) });
    if (opts.tmp_dir) |tmp_dir| {
        try arr.appendSlice(a, &.{ "--tmpdir", tmp_dir.getPath(b) });
    }
    if (opts.defines) |defines| {
        try arr.appendSlice(a, &.{ "--defines", try std.mem.join(a, ":", defines) });
    }
    if (opts.module) |module| {
        try arr.appendSlice(a, &.{ "--module", b.dupe(module) });
    }
    if (opts.reflection) {
        try arr.append(a, "--reflection");
    }
    if (opts.bytecode) {
        try arr.append(a, "--bytecode");
    }
    if (opts.dump) {
        try arr.append(a, "--dump");
    }
    if (opts.genver) |genver| {
        try arr.appendSlice(a, &.{ "--genver", b.dupe(genver) });
    }
    if (opts.ifdef) {
        try arr.append(a, "--ifdef");
    }
    if (opts.noifdef) {
        try arr.append(a, "--noifdef");
    }
    if (opts.save_intermediate_spirv) {
        try arr.append(a, "--save-intermediate-spirv");
    }
    if (opts.no_log_cmdline) {
        try arr.append(a, "--no-log-cmdline");
    }
    // important: keep this last
    try arr.append(a, "-i");
    return arr.toOwnedSlice(a);
}

pub fn build(b: *Build) void {
    _ = b;
}
