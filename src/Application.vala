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

    construct {
        loop = new MainLoop ();

        server = new Server ();
        server.exit.connect ((code) => {
            exit_code = code;
            loop.quit ();
        });
    }

    public int run (string[] args) {
        loop.run ();
        return exit_code;
    }

    public static int main (string[] args) {
        var app = new Vls.Application ();
        return app.run (args);
    }
}
