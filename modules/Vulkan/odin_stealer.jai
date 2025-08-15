// This is not an ideal way to generate binding, and possibly a very
// filthy way. But it just works as the syntax of Odin is so similar
// to Jai.

// This is located at vendor/vulkan/procefure.odin from Odin.
INPUT_FILENAME :: "procedures.odin";

OUTPUT_FILENAME :: "functions.jai";

#run {
    set_build_options_dc(.{do_output=false});

    parse();
}

start_pfn_string :: "// Loader Procedures";

ready_pfn_string :: "// Device Procedures";

// Anything contains the following is omitted.
OMIT_LIST :: string.[
"Win32",
"Winrt",
"Metal",
"IOS",
"MacOS",
"Wayland",
"Xcb",
"Xlib",
"FullScreenExclusiveModeEXT",
"SurfacePresentModes2EXT",
];

parse :: () {
    full_text, ok := read_entire_file("procedures.odin");
    if !ok {
        compiler_set_workspace_status(.FAILED);
    }

    lines := split(full_text, "\n");

    new_lines: [..]string;

    sb: String_Builder;
    init_string_builder(*sb);

    pfn_started := false;
    ready_pfn_end := false;
    pfn_ended := false;

    begin_func := false;

    for line: lines {

        if line == start_pfn_string {
            pfn_started = true;
            array_add(*new_lines, line);
            continue;
        }

        if pfn_started && !pfn_ended {
            if contains_any_string(line, ..OMIT_LIST) {
                continue;
            }

            if line == ready_pfn_string {
                ready_pfn_end = true;
                array_add(*new_lines, line);
                continue;
            }

            if begins_with(line, "/") {
                array_add(*new_lines, line);
                continue;
            }

            if line.count == 0 {
                array_add(*new_lines, "");
                if ready_pfn_end {
                    pfn_ended = true;
                }
                continue;
            }

            s := parse_pfn_line(*sb, line);

            array_add(*new_lines, s);
            continue;
        }

        if begins_with(line, "load_proc_addresses_global ::") {
            begin_func = true;
            array_add(*new_lines, "vk_load_proc_addresses_global :: (vk_get_instance_proc_addr: *void) {");
            continue;
        }

        if begins_with(line, "load_proc_addresses_instance ::") {
            begin_func = true;
            array_add(*new_lines, "vk_load_proc_addresses_instance :: (instance: VkInstance) {");
            continue;
        }

        if begins_with(line, "load_proc_addresses_device ::") {
            begin_func = true;
            array_add(*new_lines, "vk_load_proc_addresses_device :: (device: VkDevice) {");
            continue;
        }

        if begin_func {
            if begins_with(line, "}") {
                begin_func = false;
                array_add(*new_lines, "}");
                array_add(*new_lines, "");
                continue;
            }

            if contains_any_string(line, ..OMIT_LIST) {
                continue;
            }

            if line.count == 0 {
                array_add(*new_lines, "");
                continue;
            }

            if begins_with(trim_left(line), "/") {
                array_add(*new_lines, line);
                continue;
            }

            s := sprint("    vk%;", trim_left(line));

            s = replace(s, "auto_cast", "xx");
            s = replace(s, "GetInstanceProcAddr(", "vkGetInstanceProcAddr(");
            s = replace(s, "GetDeviceProcAddr(", "vkGetDeviceProcAddr(");
            s = replace(s, "nil", "null");

            array_add(*new_lines, s);
        }
    }

    ofile := file_open(OUTPUT_FILENAME, true);

    for line: new_lines {
        file_write(*ofile, line);
        file_write(*ofile, "\n");
    }
}

parse_pfn_line :: (sb: *String_Builder, line: string) -> string {
    append(sb, "vk");
    append(sb, line);
    append(sb, ";");

    s := builder_to_string(sb);
    s = replace(s, " Proc", " PFN_vk");

    return s;
}

#import "File";
#import "Compiler";
#import "Basic";
#import "String";
