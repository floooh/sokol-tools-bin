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
    input: []const u8,
    output: []const u8,
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

// Zig 0.16.0 vs 0.17.0 compatibility helper
fn addRunFile(b: *Build, p: Build.LazyPath) *Build.Step.Run {
    if (builtin.zig_version.minor <= 16) {
        return b.addSystemCommand(&.{p.getPath(b)});
    } else {
        return b.addRunFile(p);
    }
}

pub fn compile(b: *Build, opts: Options) !Build.LazyPath {
    const shdc_lazy_path = try getShdcLazyPath(b, opts.shdc_dep, opts.shdc_dir);
    const run = addRunFile(b, shdc_lazy_path);
    try addOptionsAsArgs(b, run, opts);

    run.addArg("--input");
    run.addFileArg(b.path(opts.input));
    run.addArg("--output");
    return run.addOutputFileArg(opts.output);
}

pub fn createSourceFile(b: *Build, opts: Options) !*Build.Step {
    const output_path = try compile(b, opts);
    const copy_step = b.addUpdateSourceFiles();
    copy_step.addCopyFileToSource(output_path, opts.output);
    return &copy_step.step;
}

pub fn createModule(
    b: *Build,
    module_name: []const u8,
    sokol_module: *Build.Module,
    opts: Options,
) !*Build.Module {
    const output_path = try compile(b, opts);
    const shader_module = b.addModule(module_name, .{ .root_source_file = output_path });
    shader_module.addImport("sokol", sokol_module);
    return shader_module;
}

/// target shader languages
/// NOTE: make sure that field names match the cmdline arg string
pub const Slang = packed struct(u11) {
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
    spirv_vk: bool = false,
};

fn slangToString(slang: Slang, a: Allocator) ![]const u8 {
    var strings: [16][]const u8 = undefined;
    var num_strings: usize = 0;
    inline for (comptime std.meta.fieldNames(Slang)) |fieldName| {
        if (@field(slang, fieldName)) {
            strings[num_strings] = fieldName;
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
    sokol_c3,
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

    std.log.err("Unsupported platform: {s}-{s}", .{ @tagName(os), @tagName(arch) });
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
    std.log.err("Missing shdc compiler path. Provide either shdc_dep or shdc_dir in Options", .{});
    return error.ShdcMissingPath;
}

fn addOptionsAsArgs(b: *Build, step: *Build.Step.Run, opts: Options) !void {
    const a = b.allocator;
    step.addArgs(&.{ "-l", try slangToString(opts.slang, a) });
    step.addArgs(&.{ "-f", formatToString(opts.format) });
    if (opts.tmp_dir) |tmp_dir| {
        step.addArg("--tmpdir");
        step.addDirectoryArg(tmp_dir);
    }
    if (opts.defines) |defines| {
        step.addArgs(&.{ "--defines", try std.mem.join(a, ":", defines) });
    }
    if (opts.module) |module| {
        step.addArgs(&.{ "--module", b.dupe(module) });
    }
    if (opts.reflection) {
        step.addArg("--reflection");
    }
    if (opts.bytecode) {
        step.addArg("--bytecode");
    }
    if (opts.dump) {
        step.addArg("--dump");
    }
    if (opts.genver) |genver| {
        step.addArgs(&.{ "--genver", b.dupe(genver) });
    }
    if (opts.ifdef) {
        step.addArg("--ifdef");
    }
    if (opts.noifdef) {
        step.addArg("--noifdef");
    }
    if (opts.save_intermediate_spirv) {
        step.addArg("--save-intermediate-spirv");
    }
    if (opts.no_log_cmdline) {
        step.addArg("--no-log-cmdline");
    }
}

pub fn build(b: *Build) !void {
    const shader = try createSourceFile(b, .{
        .shdc_dir = "./",
        .input = "testdata/triangle.glsl",
        .output = "testdata/triangle.glsl.zig",
        .slang = .{ .glsl430 = true },
    });

    const test_step = b.step("test", "Test sokol-shdc compilation");
    test_step.dependOn(shader);
}
