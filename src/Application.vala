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

public class Vls.Application : Object {
    private MainLoop loop;
    private int exit_code = 0;
    private Server server;

    public int run (string[] args) {
        bool test_mode = false;
        bool debug = false;

        OptionEntry[] options = new OptionEntry[2];
        options[0] = { "test-mode", 0, 0, OptionArg.NONE, ref test_mode, "Use files in /tmp for JSONRPC  instead of stdin/stdout", null };
        options[1] = { "debug", 0, 0, OptionArg.NONE, ref debug, "Extra logging", null };

        string*[] _args = new string[args.length];
        for (int i = 0; i < args.length; i++) {
            _args[i] = args[i];
        }

        try {
            var opt_context = new OptionContext ("- OptionContext example");
            opt_context.set_help_enabled (true);
            opt_context.add_main_entries (options, null);
            unowned string[] tmp = _args;
            opt_context.parse (ref tmp);
        } catch (OptionError e) {
            stdout.printf ("error: %s\n", e.message);
            stdout.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
            return 0;
        }

        loop = new MainLoop ();

        server = new Server (test_mode);
        server.exit.connect ((code) => {
            exit_code = code;
            loop.quit ();
        });

        loop.run ();
        return exit_code;
    }

    public static int main (string[] args) {
        var app = new Vls.Application ();
        return app.run (args);
    }
}
