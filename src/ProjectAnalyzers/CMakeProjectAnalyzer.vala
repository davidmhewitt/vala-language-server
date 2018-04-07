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

public class Vls.CMakeAnalyzer : Object, ProjectAnalyzer {

    public string root_uri { get; construct; }

    private string _pivot_file;
    public string pivot_file {
        get {
            return _pivot_file;
        }
        set {
            if (_pivot_file != value) {
                _pivot_file = value;
                scan_cmake_files.begin ();
            }
        }
    }

    private string cmake_build_root;
    private bool initialization_failed = false;

    public CMakeAnalyzer (string root_uri) {
        Object (root_uri: root_uri);
    }

    public bool detected () {
        var dir = File.new_for_uri (root_uri);
        var cmake = dir.get_child ("CMakeLists.txt");

        if (cmake.query_exists ()) {
            init_cmake (cmake);
            return true;
        }

        return false;
    }

    private void init_cmake (File build_file) {
        var source_root = build_file.get_parent ().get_path ();
        var tmp_dir = Environment.get_tmp_dir ();
        cmake_build_root = Path.build_filename (tmp_dir, "vls-build-" + new DateTime.now_local ().to_string ());
        var folder = File.new_for_path (cmake_build_root);
        try {
            folder.make_directory ();
        } catch (Error e) {
            initialization_failed = true;
            warning ("Failed to create temporary directory for CMake, build target analysis will fail: %s", e.message);
            return;
        }

        var cmake = new SubprocessLauncher (SubprocessFlags.STDOUT_SILENCE);
        cmake.set_cwd (cmake_build_root);
        try {
            var cmake_proc = cmake.spawnv ({ "cmake", source_root });
            cmake_proc.wait ();
        } catch (Error e) {
            initialization_failed = true;
            critical ("Failed to initialize CMake, build target analysis will fail: %s", e.message);
        }
    }

    private async void scan_cmake_files () {
        if (initialization_failed) {
            return;
        }

        var directory = File.new_for_path (cmake_build_root);
        yield find_cmake_build_file (directory, true);
    }

    private async void find_cmake_build_file (File directory, bool toplevel = false) {
        try {
            var enumerator = directory.enumerate_children ("standard::*", 0);

            FileInfo file_info;
            while ((file_info = enumerator.next_file ()) != null) {
                debug (directory.resolve_relative_path (file_info.get_name ()).get_path ());

                if (toplevel && file_info.get_name () == "CMakeFiles") {
                    continue;
                }

                if (file_info.get_file_type () == FileType.DIRECTORY) {
                    yield find_cmake_build_file (directory.resolve_relative_path (file_info.get_name ()));
                }

                if (file_info.get_name () == "build.make") {
                    var file = directory.resolve_relative_path (file_info.get_name ());
                    parse_build_file (file);
                }
            }
        } catch (Error e) {
            warning ("Error: %s\n", e.message);
        }
    }

    private void parse_build_file (File build_file) {
        DataInputStream dis;

        try {
            dis = new DataInputStream (build_file.read ());
        } catch (Error e) {
            warning ("Unable to read build.make file, build analysis will probably fail: %s", e.message);
            return;
        }

        string line;

        bool all_source_files_parsed = false;
        bool pivot_file_found = false;

        var deps = new Gee.ArrayList<string> ();
        var build_files = new Gee.ArrayList<string> ();

        Regex package_regex;
        try {
            package_regex = new Regex ("""--pkg=(.+?)(?:$| |>|<)""");
        } catch (Error e) {
            warning ("Error creating regex to parse build.make, build analysis will probably fail: %s", e.message);
            return;
        }

        try {
            while ((line = dis.read_line (null)) != null) {
                if (line.contains ("valac ")) {
                    string[] parts = line.split (" ");
                    for (int i = parts.length - 1; i > 0; i--) {
                        if (parts[i] == null) {
                            continue;
                        }

                        if (parts[i].has_prefix ("-")) {
                            MatchInfo info;
                            if (package_regex.match (parts[i], 0, out info)) {
                                deps.add (info.fetch (1));
                            }

                            all_source_files_parsed = true;
                        }

                        if (!all_source_files_parsed) {
                            var source_file = File.new_for_path (parts[i]);
                            var uri = source_file.get_uri ();
                            if (source_file.query_exists ()) {
                                build_files.add (uri);
                            }

                            if (uri == pivot_file) {
                                pivot_file_found = true;
                            }
                        }
                    }
                }
            }

            if (pivot_file_found) {
                dependencies_updated (deps);
                build_files_updated (build_files);
            }
        } catch (Error e) {
            warning ("Error parsing build.make file: %s", e.message);
        }
    }
}
