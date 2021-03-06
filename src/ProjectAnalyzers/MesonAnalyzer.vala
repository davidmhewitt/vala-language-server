/*
* Copyright (c) 2018 David Hewitt (https://github.com/davidmhewitt)
*
* This file is part of Vala Language Server (VLS).
*
* VLS is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* VLS is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with VLS.  If not, see <http://www.gnu.org/licenses/>.
*/

public class Vls.MesonAnalyzer : Object, ProjectAnalyzer {

    public string root_uri { get; construct; }

    private string _pivot_file;
    public string pivot_file {
        get {
            return _pivot_file;
        }
        set {
            if (_pivot_file != value) {
                _pivot_file = value;
                introspect_target_files.begin ();
            }
        }
    }

    private string meson_build_root;
    private bool initialization_failed = false;

    public MesonAnalyzer (string root_uri) {
        Object (root_uri: root_uri);
    }

    public bool detected () {
        var dir = File.new_for_uri (root_uri);
        var meson = dir.get_child ("meson.build");

        if (meson.query_exists ()) {
            init_meson (meson);
            return true;
        }

        return false;
    }

    private void init_meson (File build_file) {
        var source_root = build_file.get_parent ().get_path ();
        var tmp_dir = Environment.get_tmp_dir ();
        meson_build_root = Path.build_filename (tmp_dir, "vls-build-" + new DateTime.now_local ().to_string ());
        var meson = new SubprocessLauncher (SubprocessFlags.STDOUT_SILENCE);
        meson.set_cwd (source_root);
        try {
            var meson_proc = meson.spawnv ({ "meson", meson_build_root });
            meson_proc.wait ();
        } catch (Error e) {
            initialization_failed = true;
            warning ("Meson initialization failed, build target analysis will not succeed: %s", e.message);
        }
    }

    private async void introspect_target_files () {
        if (initialization_failed) {
            return;
        }

        var meson = new SubprocessLauncher (SubprocessFlags.STDOUT_PIPE);
        meson.set_cwd (meson_build_root);

        Bytes output;

        try {
            var proc = meson.spawnv ({ "meson", "introspect", "--targets", "."});
            yield proc.communicate_async (null, null, out output, null);
        } catch (Error e) {
            warning ("Meson introspection failed, build target analysis will fail: %s", e.message);
            return;
        }

        var data = (string)output.get_data ();
        Json.Node targets;
        try {
            targets = Json.from_string (data);
        } catch (Error e) {
            warning ("Error parsing JSON from meson targets: %s", e.message);
            return;
        }

        var target_list = new Gee.ArrayList<string> ();
        targets.get_array ().foreach_element ((arr, i, element) => {
            var type = element.get_object ().get_string_member ("type");
            var id = element.get_object ().get_string_member ("id");
            if (type == "executable" || type.contains ("library")) {
                debug ("Found meson target %s", id);
                target_list.add (id);
            }
        });

        var root_path = File.new_for_uri (root_uri).get_path ();
        var current_file_list = new Gee.ArrayList<string> ();
        string? target_name = null;

        foreach (var target in target_list) {
            try {
                var proc = meson.spawnv ({ "meson", "introspect", "--target-files", target, "." });
                yield proc.communicate_async (null, null, out output, null);
            } catch (Error e) {
                warning ("Meson introspection failed, build target analysis may fail: %s", e.message);
                continue;
            }

            data = (string)output.get_data ();
            Json.Node files;

            try {
                files = Json.from_string (data);
                current_file_list.clear ();
            } catch (Error e) {
                warning ("Error parsing JSON from meson target files: %s", e.message);
                continue;
            }


            files.get_array ().foreach_element ((arr, i, element) => {
                var filename = element.get_string ();
                var abs_path = Path.build_filename (root_path, filename);
                var abs_file = File.new_for_path (abs_path);
                if (!abs_file.query_exists ()) {
                    abs_path = Path.build_filename (meson_build_root, filename);
                    abs_file = File.new_for_path (abs_path);
                }

                var abs_uri = File.new_for_path (abs_path).get_uri ();
                if (abs_uri == pivot_file) {
                    target_name = target;
                }

                current_file_list.add (abs_uri);
            });

            if (target_name != null) {
                break;
            }
        }

        if (target_name != null) {
            build_files_updated (current_file_list);

            Regex target_regex, dep_regex;
            try {
                target_regex = new Regex ("""valac.*--directory.*?\/(\S+)""");
                dep_regex = new Regex ("""--pkg (\S+)""");
            } catch (Error e) {
                warning ("Unable to create regexes for parsing compile_commands.json, bailing out: %s", e.message);
                return;
            }

            var commands_file = File.new_for_path (Path.build_filename (meson_build_root, "compile_commands.json"));

            if (commands_file.query_exists ()) {
                DataInputStream dis;
                try {
                    dis = new DataInputStream (commands_file.read ());
                } catch (Error e) {
                    warning ("Could not parse compile_commands.json, bailing out: %s", e.message);
                    return;
                }

                string line;
                bool target_found = false;
                try {
                    while ((line = dis.read_line (null)) != null) {
                        MatchInfo info;
                        if (target_regex.match (line, 0, out info)) {
                            if (info.fetch (1) == target_name) {
                                target_found = true;
                                break;
                            }
                        }
                    }
                } catch (Error e) {
                    warning ("Error reading compile_commands.json, bailing out: %s", e.message);
                    return;
                }

                if (target_found) {
                    Gee.ArrayList<string> deps = new Gee.ArrayList<string> ();
                    MatchInfo info;
                    if (dep_regex.match (line, 0, out info)) {
                        do {
                            debug (info.fetch (1));
                            deps.add (info.fetch (1));
                            try {
                                info.next ();
                            } catch (Error e) {
                                warning ("Error parsing dependencies, build may not work properly: %s", e.message);
                            }
                        } while (info.matches ());

                        dependencies_updated (deps);
                    }
                }
            }
        }
    }
}
