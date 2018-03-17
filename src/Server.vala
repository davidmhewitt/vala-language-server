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

public class Vls.Server : LanguageServer.Server {
    private ProjectManager manager;

    public Server () {
        Object (
            supports_document_formatting: true
        );
    }

    protected override void initialize (LanguageServer.Types.InitializeParams init_params) {
        manager = new ProjectManager (init_params.rootUri);
        manager.publish_diagnostics.connect (publish_diagnostics);
    }

    protected override void did_open (LanguageServer.Types.TextDocumentItem document) {
        manager.add_document (document);
    }

    protected override void did_change (LanguageServer.Types.DidChangeTextDocumentParams params) {
        manager.handle_document_changes (params);
    }

    protected override Gee.ArrayList<LanguageServer.Types.TextEdit> format_document (LanguageServer.Types.DocumentFormattingParams params) {
        return manager.format_document (params.textDocument.uri);
    }

    protected override void cleanup () {
        // TODO: Cleanup if necessary?
    }
}
