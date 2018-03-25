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

public class Vls.CompileJob {

    private Gee.HashMap<string, Vala.SourceFile> files;
    private Gee.HashSet<string> dependencies;
    private string root_uri;

    private Cancellable cancellable;

    public CompileJob (string root_uri, Gee.HashMap<string, Vala.SourceFile> files, Gee.HashSet<string> dependencies) {
        cancellable = new Cancellable ();

        this.root_uri = root_uri;
        this.files = files;
        this.dependencies = dependencies;
    }

    public void cancel () {
        debug ("attempting to cancel current compilation");
        cancellable.cancel ();
    }

    public async Gee.HashMap<string, LanguageServer.Types.PublishDiagnosticsParams>? execute () {
        SourceFunc callback = execute.callback;
        Gee.HashMap<string, LanguageServer.Types.PublishDiagnosticsParams>? output = null;

        ThreadFunc<bool> run = () => {
            var context = new Vala.CodeContext ();

            Vala.CodeContext.push (context);
            var reporter = new Reporter ();
            context.report = reporter;
            context.profile = Vala.Profile.GOBJECT;

            foreach (var dep in dependencies) {
                debug ("adding dep %s", dep);
                context.add_external_package (dep);
            }

            for (int i = 2; i <= 40; i += 2) {
    			context.add_define ("VALA_0_%d".printf (i));
    		}

    		context.target_glib_major = 2;
    		context.target_glib_minor = 40;

    		for (int i = 16; i <= 40; i += 2) {
    			context.add_define ("GLIB_2_%d".printf (i));
            }

            context.nostdpkg = false;

            foreach (var file in files.values) {
                if (cancellable.is_cancelled ()) {
                    debug ("dropping compile");
                    output = null;
                    Idle.add ((owned) callback);
                    return true;
                }

                debug ("building with %s", file.filename);
                file.context = context;

                var ns_ref = new Vala.UsingDirective (new Vala.UnresolvedSymbol (null, "GLib", null));
                Vala.UsingDirective? glib_dep = null;

                foreach (var using in file.current_using_directives) {
                    if (using.namespace_symbol.name == "GLib") {
                        glib_dep = using;
                        break;
                    }
                }

                if (glib_dep != null) {
                    file.current_using_directives.remove (glib_dep);
                    glib_dep = null;
                }

                if (glib_dep == null) {
                    file.add_using_directive (ns_ref);
                    context.root.add_using_directive (ns_ref);
                }

                context.add_source_file (file);

                // clear all code nodes from file
                file.get_nodes ().clear ();
            }

            if (context.report.get_errors () > 0) {
                Vala.CodeContext.pop ();
                output = generate_diagnostics (reporter);
                Idle.add((owned) callback);
                return true;
            }

            if (cancellable.is_cancelled ()) {
                debug ("dropping compile");
                output = null;
                Idle.add ((owned) callback);
                return true;
            }

            debug ("No initial errors, parsing");
            var parser = new Vala.Parser ();
            parser.parse (context);

    		var genie_parser = new Vala.Genie.Parser ();
    		genie_parser.parse (context);

    		var gir_parser = new Vala.GirParser ();
            gir_parser.parse (context);

            if (context.report.get_errors () > 0) {
                debug ("errors in parse");
                Vala.CodeContext.pop ();
                output = generate_diagnostics (reporter);
                Idle.add((owned) callback);
                return true;
            }

            if (cancellable.is_cancelled ()) {
                debug ("dropping compile");
                output = null;
                Idle.add ((owned) callback);
                return true;
            }

            context.check ();

            output = generate_diagnostics (reporter);

            Vala.CodeContext.pop ();

            Idle.add((owned) callback);
            return true;
        };

        new Thread<bool> ("rebuild-vala-context", run);

        yield;
        return output;
    }

    private Gee.HashMap<string, LanguageServer.Types.PublishDiagnosticsParams> generate_diagnostics (Reporter report) {
        var diagnostics = new Gee.HashMap<string, LanguageServer.Types.PublishDiagnosticsParams> ();

        report.error_list.foreach (err => {
            debug ("adding error");
            add_error_to_map (ref diagnostics, err, LanguageServer.Types.DiagnosticSeverity.Error);
            return true;
        });

        report.warning_list.foreach (err => {
            debug ("adding warning");
            add_error_to_map (ref diagnostics, err, LanguageServer.Types.DiagnosticSeverity.Warning);
            return true;
        });

        return diagnostics;
    }

    private void add_error_to_map (ref Gee.HashMap<string, LanguageServer.Types.PublishDiagnosticsParams> diagnostics,
                                   SourceError err,
                                   LanguageServer.Types.DiagnosticSeverity severity) {

        if (!(root_uri in err.location.file.filename)) {
            return;
        }

        if (!diagnostics.has_key (err.location.file.filename)) {
            diagnostics[err.location.file.filename] = new LanguageServer.Types.PublishDiagnosticsParams () {
                uri = err.location.file.filename,
                diagnostics = new Gee.ArrayList<LanguageServer.Types.Diagnostic> ()
            };
        }

        var diagnostic = new LanguageServer.Types.Diagnostic () {
            severity = severity,
            source = "VLS",
            message = err.message,
            range = Utils.vala_ref_to_lsp_range (err.location)
        };

        diagnostics[err.location.file.filename].diagnostics.add (diagnostic);
    }
}
