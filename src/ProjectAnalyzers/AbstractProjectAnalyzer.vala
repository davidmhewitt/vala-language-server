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

public interface Vls.ProjectAnalyzer : Object {
    public abstract string root_uri { get; construct; }
    public abstract string pivot_file { get; set; }

    public signal void dependencies_updated (Gee.ArrayList<string> deps);
    public signal void build_files_updated (Gee.ArrayList<string> files);

    public abstract bool detected ();
}
