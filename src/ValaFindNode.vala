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

public class Vls.ValaFindNode : Vala.CodeVisitor {
    private LanguageServer.Types.Position pos;
    public Gee.ArrayList<Vala.CodeNode> results;

    public ValaFindNode (Vala.SourceFile file, LanguageServer.Types.Position pos) {
        this.pos = pos;
        results = new Gee.ArrayList<Vala.CodeNode> ();

        visit_source_file (file);
    }

    private bool match (Vala.CodeNode node) {
        var sr = node.source_reference;
        if (sr == null) {
            return false;
        }

        if (pos.line + 1 > sr.end.line || pos.line + 1 < sr.begin.line) {
            return false;
        }

        if (sr.begin.line == sr.end.line && (pos.character > sr.begin.column || pos.character < sr.end.column)) {
            return true;
        }

        if (pos.line + 1 > sr.begin.line && pos.line + 1 < sr.end.line) {
            return true;
        }

        if (pos.line + 1 == sr.begin.line && pos.character > sr.begin.column) {
            return true;
        }

        if (pos.line + 1 == sr.end.line && pos.character < sr.end.column) {
            return true;
        }

        return false;
    }

    public override void visit_source_file (Vala.SourceFile file) {
        file.accept_children (this);
    }

    public override void visit_addressof_expression (Vala.AddressofExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_array_creation_expression (Vala.ArrayCreationExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_assignment (Vala.Assignment a) {
        if (match (a)) {
            results.add (a);
        }

        a.accept_children (this);
    }

    public override void visit_base_access (Vala.BaseAccess expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_binary_expression (Vala.BinaryExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_block (Vala.Block b) {
        b.accept_children (this);
    }

    public override void visit_boolean_literal (Vala.BooleanLiteral lit) {
        if (match (lit)) {
            results.add (lit);
        }

        lit.accept_children (this);
    }

    public override void visit_break_statement (Vala.BreakStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_cast_expression (Vala.CastExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_catch_clause (Vala.CatchClause clause) {
        if (match (clause)) {
            results.add (clause);
        }

        clause.accept_children (this);
    }

    public override void visit_character_literal (Vala.CharacterLiteral lit) {
        if (match (lit)) {
            results.add (lit);
        }

        lit.accept_children (this);
    }

    public override void visit_class (Vala.Class cl) {
        if (match (cl)) {
            results.add (cl);
        }

        cl.accept_children (this);
    }

    public override void visit_conditional_expression (Vala.ConditionalExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_constant (Vala.Constant c) {
        if (match (c)) {
            results.add (c);
        }

        c.accept_children (this);
    }

    public override void visit_constructor (Vala.Constructor c) {
        if (match (c)) {
            results.add (c);
        }

        c.accept_children (this);
    }

    public override void visit_continue_statement (Vala.ContinueStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_creation_method (Vala.CreationMethod m) {
        if (match (m)) {
            results.add (m);
        }

        m.accept_children (this);
    }

    public override void visit_declaration_statement (Vala.DeclarationStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_delegate (Vala.Delegate cb) {
        if (match (cb)) {
            results.add (cb);
        }

        cb.accept_children (this);
    }

    public override void visit_delete_statement (Vala.DeleteStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_do_statement (Vala.DoStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_element_access (Vala.ElementAccess expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_empty_statement (Vala.EmptyStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_enum (Vala.Enum en) {
        if (match (en)) {
            results.add (en);
        }

        en.accept_children (this);
    }

    public override void visit_error_domain (Vala.ErrorDomain edomain) {
        if (match (edomain)) {
            results.add (edomain);
        }

        edomain.accept_children (this);
    }

    public override void visit_expression_statement (Vala.ExpressionStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_field (Vala.Field f) {
        if (match (f)) {
            results.add (f);
        }

        f.accept_children (this);
    }

    public override void visit_for_statement (Vala.ForStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_foreach_statement (Vala.ForeachStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_if_statement (Vala.IfStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_initializer_list (Vala.InitializerList list) {
        if (match (list)) {
            results.add (list);
        }

        list.accept_children (this);
    }

    public override void visit_integer_literal (Vala.IntegerLiteral lit) {
        if (match (lit)) {
            results.add (lit);
        }

        lit.accept_children (this);
    }

    public override void visit_interface (Vala.Interface iface) {
        if (match (iface)) {
            results.add (iface);
        }

        iface.accept_children (this);
    }

    public override void visit_lambda_expression (Vala.LambdaExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_local_variable (Vala.LocalVariable local) {
        if (match (local)) {
            results.add (local);
        }

        local.accept_children (this);
    }

    public override void visit_lock_statement (Vala.LockStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_loop (Vala.Loop stmt) {
        stmt.accept_children (this);
    }

    public override void visit_member_access (Vala.MemberAccess expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_method (Vala.Method m) {
        if (match (m)) {
            results.add (m);
        }

        m.accept_children (this);
    }

    public override void visit_method_call (Vala.MethodCall expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_namespace (Vala.Namespace ns) {
        if (match (ns)) {
            results.add (ns);
        }

        ns.accept_children (this);
    }

    public override void visit_null_literal (Vala.NullLiteral lit) {
        if (match (lit)) {
            results.add (lit);
        }

        lit.accept_children (this);
    }

    public override void visit_object_creation_expression (Vala.ObjectCreationExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_pointer_indirection (Vala.PointerIndirection expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_postfix_expression (Vala.PostfixExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_property (Vala.Property prop) {
        if (match (prop)) {
            results.add (prop);
        }

        prop.accept_children (this);
    }

    public override void visit_real_literal (Vala.RealLiteral lit) {
        if (match (lit)) {
            results.add (lit);
        }

        lit.accept_children (this);
    }

    public override void visit_reference_transfer_expression (Vala.ReferenceTransferExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_return_statement (Vala.ReturnStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_signal (Vala.Signal sig) {
        if (match (sig)) {
            results.add (sig);
        }

        sig.accept_children (this);
    }

    public override void visit_sizeof_expression (Vala.SizeofExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_slice_expression (Vala.SliceExpression expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }

    public override void visit_string_literal (Vala.StringLiteral lit) {
        if (match (lit)) {
            results.add (lit);
        }

        lit.accept_children (this);
    }

    public override void visit_struct (Vala.Struct st) {
        if (match (st)) {
            results.add (st);
        }

        st.accept_children (this);
    }

    public override void visit_switch_label (Vala.SwitchLabel label) {
        if (match (label)) {
            results.add (label);
        }

        label.accept_children (this);
    }

    public override void visit_switch_section (Vala.SwitchSection section) {
        if (match (section)) {
            results.add (section);
        }

        section.accept_children (this);
    }

    public override void visit_switch_statement (Vala.SwitchStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_throw_statement (Vala.ThrowStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_try_statement (Vala.TryStatement stmt) {
        if (match (stmt)) {
            results.add (stmt);
        }

        stmt.accept_children (this);
    }

    public override void visit_type_check (Vala.TypeCheck expr) {
        if (match (expr)) {
            results.add (expr);
        }

        expr.accept_children (this);
    }
}
