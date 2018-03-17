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

public class Vls.ProjectManager : Object {
    public string root_uri { get; construct; }

    public signal void publish_diagnostics (LanguageServer.Types.PublishDiagnosticsParams diagnostics);

    private Gee.HashMap<string, Vala.SourceFile> files;
    private Gee.HashMap<string, int> versions;
    private Gee.HashSet<string> dependencies;

    private ProjectAnalyzer build_system;
    private Vala.CodeContext context;

    private CompileJob? current_compile_job = null;
    private CompileJob? next_compile_job = null;

    construct {
        debug ("Project manager initializing with %s", root_uri);
        files = new Gee.HashMap<string, Vala.SourceFile> ();
        versions = new Gee.HashMap<string, int> ();
        context = new Vala.CodeContext ();
        dependencies = new Gee.HashSet<string> ();
        dependencies.add ("glib-2.0");
        dependencies.add ("gobject-2.0");

        var analyzers = new Gee.ArrayList <ProjectAnalyzer> ();
        analyzers.add (new ValaProjectAnalyzer (root_uri));
        analyzers.add (new MesonAnalyzer (root_uri));
        analyzers.add (new CMakeAnalyzer (root_uri));

        foreach (var analyzer in analyzers) {
            if (analyzer.detected ()) {
                build_system = analyzer;
                build_system.dependencies_updated.connect (on_dependencies_updated);
                build_system.build_files_updated.connect (on_files_updated);
                break;
            }
        }
    }

    public ProjectManager (string root_uri) {
        Object (root_uri: root_uri);
    }

    public void add_document (LanguageServer.Types.TextDocumentItem item) {
        var adding_new = false;
        if (!versions.has_key (item.uri)) {
            adding_new = true;
        }

        if (!versions.has_key (item.uri) || item.number > versions[item.uri]) {
            if (item.languageId == "vala") {
                debug ("Adding new file %s", item.uri);
                versions[item.uri] = item.number;

                var file = new Vala.SourceFile (context, Vala.SourceFileType.SOURCE, item.uri, item.text);
                files[item.uri] = file;
            }
        }

        if (adding_new) {
            rebuild_context ();

            build_system.pivot_file = item.uri;
        }
    }

    public void handle_document_changes (LanguageServer.Types.DidChangeTextDocumentParams params) {
        debug ("client sent a change");

        var uri = params.textDocument.uri;
        if (!versions.has_key (uri) || params.textDocument.version > versions[uri]) {
            debug ("newer version");
            versions[uri] = params.textDocument.version;

            foreach (var change in params.contentChanges) {
                debug ("change in array");
                if (change.range == null) {
                    // The client has sent the full file
                    var file = new Vala.SourceFile (context, Vala.SourceFileType.SOURCE, uri, change.text);
                    files[uri] = file;
                } else {
                    debug ("thought this was incremental");
                    // TODO: Handle incremental changes
                }
            }

            rebuild_context ();

            build_system.pivot_file = uri;
        }
    }

    public void rebuild_context () {
        if (current_compile_job == null) {
            current_compile_job = new CompileJob (root_uri, files, dependencies);
            current_compile_job.execute.begin ((obj, res) => {
                var diags = current_compile_job.execute.end (res);
                handle_diagnostics (diags);
                handle_job_finished ();
            });
        } else {
            next_compile_job = new CompileJob (root_uri, files, dependencies);
            current_compile_job.cancel ();
        }
    }

    private void handle_job_finished () {
        current_compile_job = null;

        if (next_compile_job != null) {
            current_compile_job = next_compile_job;
            next_compile_job = null;
            current_compile_job.execute.begin ((obj, res) => {
                var diags = current_compile_job.execute.end (res);
                handle_diagnostics (diags);
                handle_job_finished ();
            });
        }
    }

    public void handle_diagnostics (Gee.HashMap<string, LanguageServer.Types.PublishDiagnosticsParams>? diagnostics) {
        if (diagnostics == null) {
            return;
        }

        foreach (var file in files.keys) {
            if (!diagnostics.has_key (file)) {
                clear_diagnostics (file);
            }
        }

        foreach (var diag in diagnostics.values) {
            publish_diagnostics (diag);
        }
    }

    private void clear_diagnostics (string file_uri) {
        var diagnostics = new LanguageServer.Types.PublishDiagnosticsParams () {
            uri = file_uri,
            diagnostics = new Gee.ArrayList<LanguageServer.Types.Diagnostic> ()
        };

        publish_diagnostics (diagnostics);
    }

    private void on_dependencies_updated (Gee.ArrayList<string> new_deps) {
        debug ("deps updated");

        dependencies.clear ();
        dependencies.add ("glib-2.0");
        dependencies.add ("gobject-2.0");

        foreach (var dep in new_deps) {
            dependencies.add (dep);
        }

        rebuild_context ();
    }

    private void on_files_updated (Gee.ArrayList<string> new_files) {
        debug ("files updated");

        var to_remove = new Gee.ArrayList<string> ();
        foreach (var file in files.keys) {
            if (!(file in new_files)) {
                to_remove.add (file);
            }
        }

        foreach (var file in to_remove) {
            files.unset (file);
            versions.unset (file);
        }

        foreach (var file in new_files) {
            if (!versions.has_key (file)) {
                debug ("adding %s", file);
                versions[file] = int.MIN;
                var new_file = File.new_for_uri (file);
                uint8[] contents;
                new_file.load_contents (null, out contents, null);

                var vala_file = new Vala.SourceFile (context, Vala.SourceFileType.SOURCE, file, (string)contents);
                files[file] = vala_file;
            }
        }

        rebuild_context ();
    }

    public Gee.ArrayList<LanguageServer.Types.TextEdit> format_document (string uri) {
        var changes = new Gee.ArrayList<LanguageServer.Types.TextEdit> ();

        if (files.has_key (uri)) {
            var file = files[uri];

            context = new Vala.CodeContext ();

            Vala.CodeContext.push (context);
            context.report = new Reporter ();
            context.profile = Vala.Profile.GOBJECT;
            context.vapi_comments = true;

            context.add_source_file (file);

            file.get_nodes ().clear ();

            var parser = new Vala.Parser ();
            parser.parse (context);

    		var genie_parser = new Vala.Genie.Parser ();
    		genie_parser.parse (context);

    		var gir_parser = new Vala.GirParser ();
            gir_parser.parse (context);

            var formatter = new ValaFormatter ();
            var output = formatter.format (context);

            Vala.CodeContext.pop ();

            var lines = Regex.split_simple ("""\R""", file.content);
            var line_count = lines.length;
            var char_count = lines[lines.length - 1].length;

            changes.add (new LanguageServer.Types.TextEdit () {
                range = new LanguageServer.Types.Range () {
                    start = new LanguageServer.Types.Position () {
                        line = 0,
                        character = 0
                    },
                    end = new LanguageServer.Types.Position () {
                        line = line_count - 1,
                        character = char_count + 1
                    }
                },
                newText = output
            });
        }

        return changes;
    }
}
