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

public class Vls.Utils {
    public static LanguageServer.Types.Range vala_ref_to_lsp_range (Vala.SourceReference vala_ref) {
        var start_line = vala_ref.begin.line - 1;
        if (start_line < 0) start_line = 0;

        var start_char = vala_ref.begin.column - 1;
        if (start_char < 0) start_char = 0;

        var end_line = vala_ref.end.line - 1;
        if (end_line < 0) end_line = 0;

        return new LanguageServer.Types.Range () {
            start = new LanguageServer.Types.Position () {
                line = start_line,
                character = start_char
            },
            end = new LanguageServer.Types.Position () {
                line = end_line,
                character = vala_ref.end.column
            }
        };
    }
}
