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

public class Vls.Linter : Object {
    public int run (string[] args) {
        string content;
        FileUtils.get_contents (args[1], out content);

        var context = new Vala.CodeContext ();

        Vala.CodeContext.push (context);
        context.report = new Vala.Report ();
        context.profile = Vala.Profile.GOBJECT;
        context.vapi_comments = true;

        var file = new Vala.SourceFile (context, Vala.SourceFileType.SOURCE, args[1], content);

        context.add_source_file (file);

        var parser = new Vala.Parser ();
        parser.parse (context);

        var formatter = new ValaFormatter ();
        stdout.printf (formatter.format (context));

        Vala.CodeContext.pop ();

        return 0;
    }

    public static int main (string[] args) {
        var app = new Linter ();
        return app.run (args);
    }
}
