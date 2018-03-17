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

class Vls.SourceError {
    public Vala.SourceReference location;
    public string message;

    public SourceError (Vala.SourceReference location, string message) {
        this.location = location;
        this.message = message;
    }
}

class Vls.Reporter : Vala.Report {
    public Gee.ArrayList<SourceError> error_list = new Gee.ArrayList<SourceError> ();
    public Gee.ArrayList<SourceError> warning_list = new Gee.ArrayList<SourceError> ();

    public override void depr (Vala.SourceReference? source, string message) {
        if (source != null) {
            warning_list.add (new SourceError (source, message));
        }

        warnings++;
    }
    public override void err (Vala.SourceReference? source, string message) {
        if (source != null) {
            error_list.add (new SourceError (source, message));
        }

        errors++;
    }
    public override void note (Vala.SourceReference? source, string message) {
        if (source != null) {
            warning_list.add (new SourceError (source, message));
        }

        warnings++;
    }
    public override void warn (Vala.SourceReference? source, string message) {
        if (source != null) {
            warning_list.add (new SourceError (source, message));
        }

        warnings++;
    }
}
