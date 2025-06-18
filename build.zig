//! Helper code to invoke sokol-shdc from the Zig build system.
//! See https://github.com/floooh/sokol-zig for an example
//! of how to use sokol-tools-bin as dependency and
//! compile shaders (search for `shdc.compile` in the sokol-zig build.zig)
const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const Build = std.Build;

pub const Options = struct {
    shdc_dep: ?*Build.Dependency = null,
    shdc_dir: ?[]const u8 = null,
    input: Build.LazyPath,
    output: []const u8,
    slang: Slang,
    format: Format = .sokol_zig,
    tmp_dir: ?Build.LazyPath = null,
    defines: ?[][]const u8 = null,
    module: ?[]const u8 = null,
    reflection: bool = false,
    insource: bool = true,
    bytecode: bool = false,
    dump: bool = false,
    genver: ?[]const u8 = null,
    ifdef: bool = false,
    noifdef: bool = false,
    save_intermediate_spirv: bool = false,
    no_log_cmdline: bool = true,
};

pub const Result = struct {
    run: *Build.Step.Run,
    output: Build.LazyPath,
};

pub fn compile(b: *Build, opts: Options) !Result {
    const shdc_lazy_path = try getShdcLazyPath(b, opts.shdc_dep, opts.shdc_dir);
    const args = try optsToArgs(opts, b, shdc_lazy_path);
    var run = b.addSystemCommand(args);
    run.addArgs(&.{"--input"});
    run.addFileArg(opts.input);
    run.addArgs(&.{"--output"});
    const output = run.addOutputFileArg(opts.output);

    if (opts.insource) {
        const update_step = b.addUpdateSourceFiles();
        update_step.addCopyFileToSource(output, opts.output);
        update_step.step.dependOn(&run.step);
    }

    return .{
        .run = run,
        .output = output,
    };
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

pub fn getShdcSubPath() error{ShdcUnsupportedPlatform}![]const u8 {
    const os = builtin.os.tag;
    const arch = builtin.cpu.arch;

    if (os == .macos and arch == .x86_64) return "bin/osx/sokol-shdc";
    if (os == .macos and arch == .aarch64) return "bin/osx_arm64/sokol-shdc";
    if (os == .linux and arch == .x86_64) return "bin/linux/sokol-shdc";
    if (os == .linux and arch == .aarch64) return "bin/linux_arm64/sokol-shdc";
    if (os == .windows and arch == .x86_64) return "bin/win32/sokol-shdc.exe";

    std.log.err("Unsupported platform: {s}-{s}", .{
        @tagName(os),
        @tagName(arch),
    });
    return error.ShdcUnsupportedPlatform;
}

fn getShdcLazyPath(
    b: *Build,
    opt_shdc_dep: ?*Build.Dependency,
    opt_shdc_dir: ?[]const u8,
) error{ ShdcUnsupportedPlatform, ShdcMissingPath }!Build.LazyPath {
    const sub_path = try getShdcSubPath();
    if (opt_shdc_dep) |shdc_dep| {
        return shdc_dep.path(sub_path);
    }
    if (opt_shdc_dir) |shdc_dir| {
        return b.path(b.pathJoin(&.{ shdc_dir, sub_path }));
    }
    std.log.err("Missing Sokol shader compiler path. Provide either shdc_dep or shdc_dir in Options struct", .{});
    return error.ShdcMissingPath;
}

fn optsToArgs(opts: Options, b: *Build, tool_path: Build.LazyPath) ![]const []const u8 {
    const a = b.allocator;
    var arr: std.ArrayListUnmanaged([]const u8) = .empty;
    try arr.append(a, tool_path.getPath(b));
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
    return arr.toOwnedSlice(a);
}

pub fn build(b: *Build) !void {
    const input_path = "testdata/triangle.glsl";
    const output_path = "testdata/triangle.glsl.zig";

    const result = try compile(b, .{
        .shdc_dir = "./",
        .input = b.path(input_path),
        .output = output_path,
        .slang = .{
            .glsl430 = true,
            .glsl310es = true,
            .metal_macos = true,
            .hlsl5 = true,
            .wgsl = true,
        },
        .reflection = true,
    });

    const test_step = b.step("test", "Test sokol-shdc compilation");
    test_step.dependOn(&result.run.step);
}
