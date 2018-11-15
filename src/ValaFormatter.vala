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

public class Vls.ValaFormatter : Vala.CodeVisitor {
	private bool spaces_instead_of_tabs = true;
	private int tab_width = 4;

	static GLib.Regex fix_indent_regex;

	private Vala.CodeContext context;

	StringBuilder stream;

	int indent;
	/* at begin of line */
	bool bol = true;

	Vala.Scope current_scope;

	public ValaFormatter (bool spaces_instead_of_tabs = true, int tab_width = 4) {
		this.spaces_instead_of_tabs = spaces_instead_of_tabs;
		this.tab_width = tab_width;
	}

	public string format (Vala.CodeContext context) {
		this.context = context;

		stream = new StringBuilder ();

		current_scope = context.root.scope;

		context.accept (this);

		current_scope = null;

		var result = stream.str;
		try {
			var fix_blank_lines_regex = new Regex ("""\n\n(?=\s*})""");
			result = fix_blank_lines_regex.replace (result, -1, 0, "\n");
		} catch (Error e) {
			warning ("Failed to remove extra blank lines from formatted output: %s", e.message);
		}

		return result;
	}

	public override void visit_using_directive (Vala.UsingDirective ns) {
		write_string ("using ");

		var symbols = new GLib.List<Vala.UnresolvedSymbol> ();
		var sym = (Vala.UnresolvedSymbol) ns.namespace_symbol;
		symbols.prepend (sym);

		while ((sym = sym.inner) != null) {
			symbols.prepend (sym);
		}

		write_string (symbols.nth_data (0).name);

		for (int i = 1; i < symbols.length (); i++) {
			write_string (".");
			write_string (symbols.nth_data (i).name);
		}

		write_string (";\n");
	}

	public override void visit_namespace (Vala.Namespace ns) {
		if (ns.external_package) {
			return;
		}

		if (ns.name == null)  {
			ns.accept_children (this);
			return;
		}

		var comments = ns.get_comments ();
		if (context.vapi_comments && comments.size > 0) {
			bool first = true;
			Vala.SourceReference? first_reference = null;
			foreach (Vala.Comment comment in comments) {
				if (comment.source_reference.file.file_type == Vala.SourceFileType.SOURCE) {
					if (first) {
						write_comment (comment);
						first = false;
						first_reference = comment.source_reference;
					}
				}
			}
		}

		write_attributes (ns);

		write_indent ();
		write_string ("namespace ");
		write_identifier (ns.name);
		write_begin_block ();

		current_scope = ns.scope;

		visit_sorted (ns.get_namespaces ());
		visit_sorted (ns.get_classes ());
		visit_sorted (ns.get_interfaces ());
		visit_sorted (ns.get_structs ());
		visit_sorted (ns.get_enums ());
		visit_sorted (ns.get_error_domains ());
		visit_sorted (ns.get_delegates ());
		visit_sorted (ns.get_fields ());
		visit_sorted (ns.get_constants ());
		visit_sorted (ns.get_methods ());

		current_scope = current_scope.parent_scope;

		write_end_block ();
		write_newline ();
	}

	private string get_cheaders (Vala.Symbol sym) {
		string cheaders = "";
		if (!sym.external_package) {
			cheaders = sym.get_attribute_string ("CCode", "cheader_filename") ?? "";
			if (cheaders == "" && sym.parent_symbol != null && sym.parent_symbol != context.root) {
				cheaders = get_cheaders (sym.parent_symbol);
			}
			if (cheaders == "" && sym.source_reference != null && !sym.external_package) {
				cheaders = sym.source_reference.file.get_cinclude_filename ();
			}
		}
		return cheaders;
	}

	public override void visit_class (Vala.Class cl) {
		if (cl.external_package) {
			return;
		}

		if (!check_accessibility (cl)) {
			return;
		}

		if (context.vapi_comments && cl.comment != null) {
			write_comment (cl.comment);
		}

		write_attributes (cl);

		write_indent ();
		write_accessibility (cl);
		if (cl.is_abstract) {
			write_string ("abstract ");
		}
		write_string ("class ");
		write_identifier (cl.name);

		write_type_parameters (cl.get_type_parameters ());

		var base_types = cl.get_base_types ();
		if (base_types.size > 0) {
			write_string (" : ");

			bool first = true;
			foreach (Vala.DataType base_type in base_types) {
				if (!first) {
					write_string (", ");
				} else {
					first = false;
				}
				write_type (base_type);
			}
		}
		write_begin_block ();

		current_scope = cl.scope;

		visit_sorted (cl.get_classes ());
		visit_sorted (cl.get_structs ());
		visit_sorted (cl.get_enums ());
		visit_sorted (cl.get_delegates ());
		write_newline ();
		visit_sorted (cl.get_constants ());
		write_newline ();

		bool constructors_inserted = false;
		foreach (var member in cl.get_members ()) {
			if (!constructors_inserted && member is Vala.Method) {
				if (cl.constructor != null && cl.constructor.body != null) {
					write_newline ();
				 	cl.constructor.accept (this);
				}

				if (cl.class_constructor != null && cl.class_constructor.body != null) {
					cl.class_constructor.accept (this);
				}

				if (cl.static_constructor != null && cl.static_constructor.body != null) {
					cl.static_constructor.accept (this);
				}

				constructors_inserted = true;
			}

			member.accept (this);
		}

		current_scope = current_scope.parent_scope;

		write_end_block ();
		write_newline ();
		write_newline ();
	}

	void visit_sorted (Vala.List<Vala.Symbol> symbols) {
		foreach (Vala.Symbol sym in symbols) {
			sym.accept (this);
		}
	}

	public override void visit_struct (Vala.Struct st) {
		if (st.external_package) {
			return;
		}

		if (!check_accessibility (st)) {
			return;
		}

		if (context.vapi_comments && st.comment != null) {
			write_comment (st.comment);
		}

		write_attributes (st);

		write_indent ();
		write_accessibility (st);
		write_string ("struct ");
		write_identifier (st.name);

		write_type_parameters (st.get_type_parameters ());

		if (st.base_type != null) {
			write_string (" : ");
			write_type (st.base_type);
		}

		write_begin_block ();

		current_scope = st.scope;

		foreach (Vala.Field field in st.get_fields ()) {
			field.accept (this);
		}
		visit_sorted (st.get_constants ());
		visit_sorted (st.get_methods ());
		visit_sorted (st.get_properties ());

		current_scope = current_scope.parent_scope;

		write_end_block ();
		write_newline ();
		write_newline ();
	}

	public override void visit_interface (Vala.Interface iface) {
		if (iface.external_package) {
			return;
		}

		if (!check_accessibility (iface)) {
			return;
		}

		if (context.vapi_comments && iface.comment != null) {
			write_comment (iface.comment);
		}

		write_attributes (iface);

		write_indent ();
		write_accessibility (iface);
		write_string ("interface ");
		write_identifier (iface.name);

		write_type_parameters (iface.get_type_parameters ());

		var prerequisites = iface.get_prerequisites ();
		if (prerequisites.size > 0) {
			write_string (" : ");

			bool first = true;
			foreach (Vala.DataType prerequisite in prerequisites) {
				if (!first) {
					write_string (", ");
				} else {
					first = false;
				}
				write_type (prerequisite);
			}
		}
		write_begin_block ();

		current_scope = iface.scope;

		visit_sorted (iface.get_classes ());
		visit_sorted (iface.get_structs ());
		visit_sorted (iface.get_enums ());
		visit_sorted (iface.get_delegates ());
		visit_sorted (iface.get_fields ());
		visit_sorted (iface.get_constants ());
		visit_sorted (iface.get_methods ());
		visit_sorted (iface.get_properties ());
		visit_sorted (iface.get_signals ());

		current_scope = current_scope.parent_scope;

		write_end_block ();
		write_newline ();
		write_newline ();
	}

	public override void visit_enum (Vala.Enum en) {
		if (en.external_package) {
			return;
		}

		if (!check_accessibility (en)) {
			return;
		}

		if (context.vapi_comments && en.comment != null) {
			write_comment (en.comment);
		}

		write_attributes (en);

		write_indent ();
		write_accessibility (en);
		write_string ("enum ");
		write_identifier (en.name);
		write_begin_block ();

		bool first = true;
		foreach (Vala.EnumValue ev in en.get_values ()) {
			if (first) {
				first = false;
			} else {
				write_string (",");
				write_newline ();
			}

			if (context.vapi_comments && ev.comment != null) {
				write_comment (ev.comment);
			}

			write_attributes (ev);

			write_indent ();
			write_identifier (ev.name);

			if (ev.value != null) {
				write_string(" = ");
				ev.value.accept (this);
			}
		}

		if (!first) {
			if (en.get_methods ().size > 0 || en.get_constants ().size > 0) {
				write_string (";");
			}
			write_newline ();
		}

		current_scope = en.scope;
		foreach (Vala.Method m in en.get_methods ()) {
			m.accept (this);
		}
		foreach (Vala.Constant c in en.get_constants ()) {
			c.accept (this);
		}
		current_scope = current_scope.parent_scope;

		write_end_block ();
		write_newline ();
		write_newline ();
	}

	public override void visit_error_domain (Vala.ErrorDomain edomain) {
		if (edomain.external_package) {
			return;
		}

		if (!check_accessibility (edomain)) {
			return;
		}

		if (context.vapi_comments && edomain.comment != null) {
			write_comment (edomain.comment);
		}

		write_attributes (edomain);

		write_indent ();
		write_accessibility (edomain);
		write_string ("errordomain ");
		write_identifier (edomain.name);
		write_begin_block ();

		bool first = true;
		foreach (Vala.ErrorCode ecode in edomain.get_codes ()) {
			if (first) {
				first = false;
			} else {
				write_string (",");
				write_newline ();
			}

			if (context.vapi_comments && ecode.comment != null) {
				write_comment (ecode.comment);
			}

			write_attributes (ecode);

			write_indent ();
			write_identifier (ecode.name);
		}

		if (!first) {
			if (edomain.get_methods ().size > 0) {
				write_string (";");
			}
			write_newline ();
		}

		current_scope = edomain.scope;
		foreach (Vala.Method m in edomain.get_methods ()) {
			m.accept (this);
		}
		current_scope = current_scope.parent_scope;

		write_end_block ();
		write_newline ();
	}

	public override void visit_constant (Vala.Constant c) {
		if (c.external_package) {
			return;
		}

		if (!check_accessibility (c)) {
			return;
		}

		if (context.vapi_comments && c.comment != null) {
			write_comment (c.comment);
		}

		write_attributes (c);

		write_indent ();
		write_accessibility (c);
		write_string ("const ");

		write_type (c.type_reference);

		write_string (" ");
		write_identifier (c.name);
		write_type_suffix (c.type_reference);
		if (c.value != null) {
			write_string(" = ");
			c.value.accept (this);
		}
		write_string (";");
		write_newline ();
	}

	public override void visit_field (Vala.Field f) {
		if (f.external_package) {
			return;
		}

		if (!check_accessibility (f)) {
			return;
		}

		// Don't include autogenerated fields for properties
		if (f.name.has_prefix ("_") && current_scope.owner is Vala.Class) {
			var parent_class = current_scope.owner as Vala.Class;
			foreach (var prop in parent_class.get_properties ()) {
				if ("_%s".printf (prop.name) != f.name) {
					continue;
				}

				bool empty_get = (prop.get_accessor != null && prop.get_accessor.body == null);
				bool empty_set = (prop.set_accessor != null && prop.set_accessor.body == null);

				if (empty_get && empty_set) {
					return;
				}
			}
		}

		if (context.vapi_comments && f.comment != null) {
			write_comment (f.comment);
		}

		write_attributes (f);

		write_indent ();
		write_accessibility (f);

		if (f.binding == Vala.MemberBinding.STATIC) {
			write_string ("static ");
		} else if (f.binding == Vala.MemberBinding.CLASS) {
			write_string ("class ");
		}

		if (f.variable_type.is_weak ()) {
			write_string ("weak ");
		}

		write_type (f.variable_type);

		write_string (" ");
		write_identifier (f.name);
		write_type_suffix (f.variable_type);

		if (f.initializer != null) {
			write_string (" = ");
			f.initializer.accept (this);
		}

		write_string (";");
		write_newline ();
	}

	private void write_error_domains (Vala.List<Vala.DataType> error_domains) {
		if (error_domains.size > 0) {
			write_string (" throws ");

			bool first = true;
			foreach (Vala.DataType type in error_domains) {
				if (!first) {
					write_string (", ");
				} else {
					first = false;
				}

				write_type (type);
			}
		}
	}

	private void write_params (Vala.List<Vala.Parameter> params) {
		write_string ("(");

		int i = 1;
		foreach (Vala.Parameter param in params) {
			if (i > 1) {
				write_string (", ");
			}

			if (param.ellipsis) {
				write_string ("...");
				continue;
			}

			write_attributes (param);

			if (param.params_array) {
				write_string ("params ");
			}

			if (param.direction == Vala.ParameterDirection.IN) {
				if (param.variable_type.value_owned) {
					write_string ("owned ");
				}
			} else {
				if (param.direction == Vala.ParameterDirection.REF) {
					write_string ("ref ");
				} else if (param.direction == Vala.ParameterDirection.OUT) {
					write_string ("out ");
				}
				if (param.variable_type.is_weak ()) {
					write_string ("unowned ");
				}
			}

			write_type (param.variable_type);

			write_string (" ");
			write_identifier (param.name);
			write_type_suffix (param.variable_type);

			if (param.initializer != null) {
				write_string (" = ");
				param.initializer.accept (this);
			}

			i++;
		}

		write_string (")");
	}

	public override void visit_delegate (Vala.Delegate cb) {
		if (cb.external_package) {
			return;
		}

		if (!check_accessibility (cb)) {
			return;
		}

		if (context.vapi_comments && cb.comment != null) {
			write_comment (cb.comment);
		}

		write_attributes (cb);

		write_indent ();

		write_accessibility (cb);
		write_string ("delegate ");

		write_return_type (cb.return_type);

		write_string (" ");
		write_identifier (cb.name);

		write_type_parameters (cb.get_type_parameters ());

		write_string (" ");

		write_params (cb.get_parameters ());

		write_error_domains (cb.get_error_types ());

		write_string (";");

		write_newline ();
	}

	public override void visit_constructor (Vala.Constructor c) {
		if (context.vapi_comments && c.comment != null) {
			write_comment (c.comment);
		}

		write_indent ();

		if (c.binding == Vala.MemberBinding.STATIC) {
			write_string ("static ");
		} else if (c.binding == Vala.MemberBinding.CLASS) {
			write_string ("class ");
		}

		write_string ("construct");
		write_code_block (c.body);
		write_newline ();
		write_newline ();
	}

	public override void visit_method (Vala.Method m) {
		if (m.external_package) {
			return;
		}

		if (m is Vala.CreationMethod && m.body.get_statements ().size == 0) {
			return;
		}

		if (context.vapi_comments && m.comment != null) {
			write_comment (m.comment);
		}

		write_attributes (m);

		write_indent ();
		write_accessibility (m);

		if (m is Vala.CreationMethod) {
			if (m.coroutine) {
				write_string ("async ");
			}

			var datatype = (Vala.TypeSymbol) m.parent_symbol;
			write_identifier (datatype.name);
			if (m.name != ".new") {
				write_string (".");
				write_identifier (m.name);
			}
			write_string (" ");
		} else {
			if (m.binding == Vala.MemberBinding.STATIC) {
				write_string ("static ");
			} else if (m.binding == Vala.MemberBinding.CLASS) {
				write_string ("class ");
			} else if (m.is_abstract) {
				write_string ("abstract ");
			} else if (m.is_virtual) {
				write_string ("virtual ");
			} else if (m.overrides) {
				write_string ("override ");
			}

			if (m.hides) {
				write_string ("new ");
			}

			if (m.coroutine) {
				write_string ("async ");
			}

			write_return_type (m.return_type);
			write_string (" ");

			write_identifier (m.name);

			write_type_parameters (m.get_type_parameters ());

			write_string (" ");
		}

		write_params (m.get_parameters ());

		write_error_domains (m.get_error_types ());

		write_code_block (m.body);

		write_newline ();
		write_newline ();
	}

	public override void visit_creation_method (Vala.CreationMethod m) {
		visit_method (m);
	}

	public override void visit_property (Vala.Property prop) {
		if (!check_accessibility (prop) || (prop.base_interface_property != null && !prop.is_abstract && !prop.is_virtual)) {
			return;
		}

		if (context.vapi_comments && prop.comment != null) {
			write_comment (prop.comment);
		}

		write_attributes (prop);

		write_indent ();
		write_accessibility (prop);

		if (prop.binding == Vala.MemberBinding.STATIC) {
			write_string ("static ");
		} else  if (prop.is_abstract) {
			write_string ("abstract ");
		} else if (prop.is_virtual) {
			write_string ("virtual ");
		} else if (prop.overrides) {
			write_string ("override ");
		}

		write_type (prop.property_type);

		write_string (" ");
		write_identifier (prop.name);
		write_string (" {");
		if (prop.get_accessor != null) {
			write_attributes (prop.get_accessor);

			if (prop.get_accessor.body != null) {
				write_newline ();
				indent += 1;
				write_indent ();
			} else {
				write_string (" ");
			}

			write_property_accessor_accessibility (prop.get_accessor);

			if (prop.get_accessor.value_type.is_disposable ()) {
				write_string ("owned ");
			}

			write_string ("get");
			write_code_block (prop.get_accessor.body);

			if (prop.get_accessor.body != null) {
				write_newline ();
				indent--;
				write_indent ();
			} else {
				write_string (" ");
			}
		}

		if (prop.set_accessor != null) {
			write_attributes (prop.set_accessor);

			if (prop.set_accessor.body != null) {
				write_newline ();
				indent += 1;
				write_indent ();
			} else {
				write_string (" ");
			}

			write_property_accessor_accessibility (prop.set_accessor);

			if (prop.set_accessor.value_type.value_owned) {
				write_string ("owned ");
			}

			if (prop.set_accessor.writable && prop.set_accessor.construction) {
				write_string ("construct set");
			} else if (prop.set_accessor.writable) {
				write_string ("set");
			} else if (prop.set_accessor.construction) {
				write_string ("construct");
			}

			write_code_block (prop.set_accessor.body);

			if (prop.set_accessor.body != null) {
				write_newline ();
				indent--;
				write_indent ();
			} else {
				write_string (" ");
			}
		}

		write_string ("}");
		write_newline ();
		write_newline ();
	}

	public override void visit_signal (Vala.Signal sig) {
		if (!check_accessibility (sig)) {
			return;
		}

		if (context.vapi_comments && sig.comment != null) {
			write_comment (sig.comment);
		}

		write_attributes (sig);

		write_indent ();
		write_accessibility (sig);

		if (sig.is_virtual) {
			write_string ("virtual ");
		}

		write_string ("signal ");

		write_return_type (sig.return_type);

		write_string (" ");
		write_identifier (sig.name);

		write_string (" ");

		write_params (sig.get_parameters ());

		write_string (";");

		write_newline ();
	}

	public override void visit_block (Vala.Block b) {
		write_begin_block ();

		foreach (Vala.Statement stmt in b.get_statements ()) {
			stmt.accept (this);
		}

		write_end_block ();
	}

	public override void visit_empty_statement (Vala.EmptyStatement stmt) {
	}

	public override void visit_declaration_statement (Vala.DeclarationStatement stmt) {
		write_indent ();
		stmt.declaration.accept (this);
		write_string (";");
		write_newline ();
	}

	public override void visit_local_variable (Vala.LocalVariable local) {
		if (local.variable_type != null && local.variable_type.is_weak ()) {
			write_string ("unowned ");
		}

        if (local.variable_type != null) {
            write_type (local.variable_type);
            write_string (" ");
        } else {
            write_string ("var ");
        }

		write_identifier (local.name);

        if (local.variable_type != null) {
            write_type_suffix (local.variable_type);
        }

		if (local.initializer != null) {
			write_string (" = ");
			local.initializer.accept (this);
		}
	}

	public override void visit_initializer_list (Vala.InitializerList list) {
		write_string ("{");

		bool first = true;
		foreach (Vala.Expression initializer in list.get_initializers ()) {
			if (!first) {
				write_string (", ");
			} else {
				write_string (" ");
			}
			first = false;
			initializer.accept (this);
		}
		write_string (" }");
	}

	public override void visit_expression_statement (Vala.ExpressionStatement stmt) {
		write_indent ();
		stmt.expression.accept (this);

		bool has_lambda = false;
		if (stmt.expression is Vala.MethodCall) {
			var method = stmt.expression as Vala.MethodCall;
			foreach (var arg in method.get_argument_list ()) {
				if (arg is Vala.LambdaExpression) {
					has_lambda = true;
					break;
				}
			}
		}

		write_string (";");
		write_newline ();
		if (has_lambda) {
			write_newline ();
		}
	}

	public override void visit_if_statement (Vala.IfStatement stmt) {
		write_indent ();
		write_string ("if (");
		stmt.condition.accept (this);
		write_string (")");
		stmt.true_statement.accept (this);
		if (stmt.false_statement != null) {
			var statements = stmt.false_statement.get_statements ();
			if (statements.size == 1 && statements[0] is Vala.IfStatement) {
				visit_else_if (statements[0] as Vala.IfStatement);
			} else {
				write_string (" else");
				stmt.false_statement.accept (this);
			}
		}

		write_newline ();
		write_newline ();
	}

	private void visit_else_if (Vala.IfStatement stmt) {
		write_string (" else if (");
		stmt.condition.accept (this);
		write_string (")");
		stmt.true_statement.accept (this);
		if (stmt.false_statement != null) {
			var statements = stmt.false_statement.get_statements ();
			if (statements.size == 1 && statements[0] is Vala.IfStatement) {
				visit_else_if (statements[0] as Vala.IfStatement);
			} else {
				write_string (" else");
				stmt.false_statement.accept (this);
			}
		}
	}

	public override void visit_switch_statement (Vala.SwitchStatement stmt) {
		write_indent ();
		write_string ("switch (");
		stmt.expression.accept (this);
		write_string (") {");
		write_newline ();

		foreach (Vala.SwitchSection section in stmt.get_sections ()) {
			section.accept (this);
		}

		write_indent ();
		write_string ("}");
		write_newline ();
		write_newline ();
	}

	public override void visit_switch_section (Vala.SwitchSection section) {
		foreach (Vala.SwitchLabel label in section.get_labels ()) {
			label.accept (this);
		}

		foreach (Vala.Statement stmt in section.get_statements ()) {
			indent += 2;
			stmt.accept (this);
			indent -= 2;
		}
	}

	public override void visit_switch_label (Vala.SwitchLabel label) {
		if (label.expression != null) {
			indent++;
			write_indent ();
			write_string ("case ");
			label.expression.accept (this);
			write_string (":");
			write_newline ();
			indent--;
		} else {
			indent++;
			write_indent ();
			write_string ("default:");
			write_newline ();
			indent--;
		}
	}

	public override void visit_loop (Vala.Loop stmt) {
		write_indent ();
		write_string ("loop");
		stmt.body.accept (this);
		write_newline ();
	}

	public override void visit_while_statement (Vala.WhileStatement stmt) {
		write_indent ();
		write_string ("while (");
		stmt.condition.accept (this);
		write_string (")");
		stmt.body.accept (this);
		write_newline ();
	}

	public override void visit_do_statement (Vala.DoStatement stmt) {
		write_indent ();
		write_string ("do");
		stmt.body.accept (this);
		write_string ("while (");
		stmt.condition.accept (this);
		write_string (");");
		write_newline ();
	}

	public override void visit_for_statement (Vala.ForStatement stmt) {
		write_indent ();
		write_string ("for (");

		bool first = true;
		foreach (Vala.Expression initializer in stmt.get_initializer ()) {
			if (!first) {
				write_string (", ");
			}
			first = false;
			initializer.accept (this);
		}
		write_string ("; ");

		stmt.condition.accept (this);
		write_string ("; ");

		first = true;
		foreach (Vala.Expression iterator in stmt.get_iterator ()) {
			if (!first) {
				write_string (", ");
			}
			first = false;
			iterator.accept (this);
		}

		write_string (")");
		stmt.body.accept (this);
		write_newline ();
		write_newline ();
	}

	public override void visit_foreach_statement (Vala.ForeachStatement stmt) {
		write_indent ();
		write_string ("foreach (");

		if (stmt.type_reference != null) {
            write_type (stmt.type_reference);
            write_string (" ");
        } else {
            write_string ("var ");
        }

		write_identifier (stmt.variable_name);

        if (stmt.type_reference != null) {
            write_type_suffix (stmt.type_reference);
        }

		write_string (" in ");

		stmt.collection.accept (this);

		write_string (")");
		stmt.body.accept (this);
		write_newline ();
		write_newline ();
	}

	public override void visit_break_statement (Vala.BreakStatement stmt) {
		write_indent ();
		write_string ("break;");
		write_newline ();
	}

	public override void visit_continue_statement (Vala.ContinueStatement stmt) {
		write_indent ();
		write_string ("continue;");
		write_newline ();
	}

	public override void visit_return_statement (Vala.ReturnStatement stmt) {
		write_indent ();
		write_string ("return");
		if (stmt.return_expression != null) {
			write_string (" ");
			stmt.return_expression.accept (this);
		}
		write_string (";");
		write_newline ();
	}

	public override void visit_yield_statement (Vala.YieldStatement y) {
		write_indent ();
		write_string ("yield");
		if (y.yield_expression != null) {
			write_string (" ");
			y.yield_expression.accept (this);
		}
		write_string (";");
		write_newline ();
	}

	public override void visit_throw_statement (Vala.ThrowStatement stmt) {
		write_indent ();
		write_string ("throw");
		if (stmt.error_expression != null) {
			write_string (" ");
			stmt.error_expression.accept (this);
		}
		write_string (";");
		write_newline ();
	}

	public override void visit_try_statement (Vala.TryStatement stmt) {
		write_indent ();
		write_string ("try");
		stmt.body.accept (this);
		foreach (var clause in stmt.get_catch_clauses ()) {
			clause.accept (this);
		}

		if (stmt.finally_body != null) {
			write_string (" finally");
			stmt.finally_body.accept (this);
		}

		write_newline ();
		write_newline ();
	}

	public override void visit_catch_clause (Vala.CatchClause clause) {
		var type_name = clause.error_type == null ? "GLib.Error" : clause.error_type.to_string ();
		var var_name = clause.variable_name == null ? "_" : clause.variable_name;
		write_string (" catch (%s %s)".printf (type_name, var_name));
		clause.body.accept (this);
	}

	public override void visit_lock_statement (Vala.LockStatement stmt) {
		write_indent ();
		write_string ("lock (");
		stmt.resource.accept (this);
		write_string (")");
		if (stmt.body == null) {
			write_string (";");
		} else {
			stmt.body.accept (this);
		}
		write_newline ();
	}

	public override void visit_delete_statement (Vala.DeleteStatement stmt) {
		write_indent ();
		write_string ("delete ");
		stmt.expression.accept (this);
		write_string (";");
		write_newline ();
	}

	public override void visit_array_creation_expression (Vala.ArrayCreationExpression expr) {
		write_string ("new ");
		write_type (expr.element_type);
		write_string ("[");

		bool first = true;
		foreach (Vala.Expression size in expr.get_sizes ()) {
			if (!first) {
				write_string (", ");
			}
			first = false;

			size.accept (this);
		}

		write_string ("]");

		if (expr.initializer_list != null) {
			write_string (" ");
			expr.initializer_list.accept (this);
		}
	}

	public override void visit_boolean_literal (Vala.BooleanLiteral lit) {
		write_string (lit.value.to_string ());
	}

	public override void visit_character_literal (Vala.CharacterLiteral lit) {
		write_string (lit.value);
	}

	public override void visit_integer_literal (Vala.IntegerLiteral lit) {
		write_string (lit.value);
	}

	public override void visit_real_literal (Vala.RealLiteral lit) {
		write_string (lit.value);
	}

	public override void visit_string_literal (Vala.StringLiteral lit) {
		write_string (lit.value);
	}

	public override void visit_null_literal (Vala.NullLiteral lit) {
		write_string ("null");
	}

	public override void visit_member_access (Vala.MemberAccess expr) {
		if (expr.inner != null) {
			expr.inner.accept (this);
			write_string (".");
		}
		write_identifier (expr.member_name);
	}

	public override void visit_method_call (Vala.MethodCall expr) {
		expr.call.accept (this);

		bool is_translation = false;
		if (expr.call is Vala.MemberAccess) {
			var ma = (Vala.MemberAccess) expr.call;
			if (ma.member_name == "_") {
				is_translation = true;
			}
		}

		if (is_translation) {
			write_string ("(");
		} else {
			write_string (" (");
		}

		bool first = true;
		foreach (Vala.Expression arg in expr.get_argument_list ()) {
			if (!first) {
				write_string (", ");
			}
			first = false;

			arg.accept (this);
		}

		write_string (")");
	}

	public override void visit_named_argument (Vala.NamedArgument arg) {
		write_string (arg.name);
		write_string (": ");
		arg.inner.accept (this);
	}

	public override void visit_element_access (Vala.ElementAccess expr) {
		expr.container.accept (this);
		write_string ("[");

		bool first = true;
		foreach (Vala.Expression index in expr.get_indices ()) {
			if (!first) {
				write_string (", ");
			}
			first = false;

			index.accept (this);
		}

		write_string ("]");
	}

	public override void visit_slice_expression (Vala.SliceExpression expr) {
		expr.container.accept (this);
		write_string ("[");
		expr.start.accept (this);
		write_string (":");
		expr.stop.accept (this);
		write_string ("]");
	}

	public override void visit_base_access (Vala.BaseAccess expr) {
		write_string ("base");
	}

	public override void visit_postfix_expression (Vala.PostfixExpression expr) {
		expr.inner.accept (this);
		if (expr.increment) {
			write_string ("++");
		} else {
			write_string ("--");
		}
	}

	public override void visit_object_creation_expression (Vala.ObjectCreationExpression expr) {
		if (!expr.struct_creation) {
			write_string ("new ");
		}

		if (expr.type_reference != null) {
			write_type (expr.type_reference);

			if (expr.symbol_reference.name != ".new") {
				write_string (".");
				write_string (expr.symbol_reference.name);
			}
		} else {
			write_string (expr.member_name.to_string ());
			Vala.ArrayList<Vala.TypeParameter> params = new Vala.ArrayList<Vala.TypeParameter> ();
			foreach (var type in expr.member_name.get_type_arguments ()) {
				params.add (new Vala.TypeParameter (type.to_qualified_string (current_scope), type.source_reference));
			}

			write_type_parameters (params);
		}

		write_string (" (");

		bool first = true;
		foreach (Vala.Expression arg in expr.get_argument_list ()) {
			if (!first) {
				write_string (", ");
			}
			first = false;

			arg.accept (this);
		}

		write_string (")");
	}

	public override void visit_sizeof_expression (Vala.SizeofExpression expr) {
		write_string ("sizeof (");
		write_type (expr.type_reference);
		write_string (")");
	}

	public override void visit_typeof_expression (Vala.TypeofExpression expr) {
		write_string ("typeof (");
		write_type (expr.type_reference);
		write_string (")");
	}

	public override void visit_unary_expression (Vala.UnaryExpression expr) {
		switch (expr.operator) {
		case Vala.UnaryOperator.PLUS:
			write_string ("+");
			break;
		case Vala.UnaryOperator.MINUS:
			write_string ("-");
			break;
		case Vala.UnaryOperator.LOGICAL_NEGATION:
			write_string ("!");
			break;
		case Vala.UnaryOperator.BITWISE_COMPLEMENT:
			write_string ("~");
			break;
		case Vala.UnaryOperator.INCREMENT:
			write_string ("++");
			break;
		case Vala.UnaryOperator.DECREMENT:
			write_string ("--");
			break;
		case Vala.UnaryOperator.REF:
			write_string ("ref ");
			break;
		case Vala.UnaryOperator.OUT:
			write_string ("out ");
			break;
		default:
			assert_not_reached ();
		}
		expr.inner.accept (this);
	}

	public override void visit_cast_expression (Vala.CastExpression expr) {
		if (expr.is_non_null_cast) {
			write_string ("(!) ");
			expr.inner.accept (this);
			return;
		}

		if (!expr.is_silent_cast) {
			write_string ("(");
			write_type (expr.type_reference);
			write_string (") ");
		}

		if (expr.is_silent_cast) {
			write_string ("(");
		}

		expr.inner.accept (this);

		if (expr.is_silent_cast) {
			write_string (" as ");
			write_type (expr.type_reference);
			write_string (")");
		}
	}

	public override void visit_pointer_indirection (Vala.PointerIndirection expr) {
		write_string ("*");
		expr.inner.accept (this);
	}

	public override void visit_addressof_expression (Vala.AddressofExpression expr) {
		write_string ("&");
		expr.inner.accept (this);
	}

	public override void visit_reference_transfer_expression (Vala.ReferenceTransferExpression expr) {
		write_string ("(owned) ");
		expr.inner.accept (this);
	}

	public override void visit_binary_expression (Vala.BinaryExpression expr) {
		expr.left.accept (this);

		switch (expr.operator) {
		case Vala.BinaryOperator.PLUS:
			write_string (" + ");
			break;
		case Vala.BinaryOperator.MINUS:
			write_string (" - ");
			break;
		case Vala.BinaryOperator.MUL:
			write_string (" * ");
			break;
		case Vala.BinaryOperator.DIV:
			write_string (" / ");
			break;
		case Vala.BinaryOperator.MOD:
			write_string (" % ");
			break;
		case Vala.BinaryOperator.SHIFT_LEFT:
			write_string (" << ");
			break;
		case Vala.BinaryOperator.SHIFT_RIGHT:
			write_string (" >> ");
			break;
		case Vala.BinaryOperator.LESS_THAN:
			write_string (" < ");
			break;
		case Vala.BinaryOperator.GREATER_THAN:
			write_string (" > ");
			break;
		case Vala.BinaryOperator.LESS_THAN_OR_EQUAL:
			write_string (" <= ");
			break;
		case Vala.BinaryOperator.GREATER_THAN_OR_EQUAL:
			write_string (" >= ");
			break;
		case Vala.BinaryOperator.EQUALITY:
			write_string (" == ");
			break;
		case Vala.BinaryOperator.INEQUALITY:
			write_string (" != ");
			break;
		case Vala.BinaryOperator.BITWISE_AND:
			write_string (" & ");
			break;
		case Vala.BinaryOperator.BITWISE_OR:
			write_string (" | ");
			break;
		case Vala.BinaryOperator.BITWISE_XOR:
			write_string (" ^ ");
			break;
		case Vala.BinaryOperator.AND:
			write_string (" && ");
			break;
		case Vala.BinaryOperator.OR:
			write_string (" || ");
			break;
		case Vala.BinaryOperator.IN:
			write_string (" in ");
			break;
		case Vala.BinaryOperator.COALESCE:
			write_string (" ?? ");
			break;
		default:
			assert_not_reached ();
		}

		expr.right.accept (this);
	}

	public override void visit_type_check (Vala.TypeCheck expr) {
		expr.expression.accept (this);
		write_string (" is ");
		write_type (expr.type_reference);
	}

	public override void visit_conditional_expression (Vala.ConditionalExpression expr) {
		expr.condition.accept (this);
		write_string (" ? ");
		expr.true_expression.accept (this);
		write_string (" : ");
		expr.false_expression.accept (this);
	}

	public override void visit_lambda_expression (Vala.LambdaExpression expr) {
		write_string ("(");
		var params = expr.get_parameters ();
		int i = 1;
		foreach (var param in params) {
			if (i > 1) {
				write_string (", ");
			}

			if (param.direction == Vala.ParameterDirection.REF) {
				write_string ("ref ");
			} else if (param.direction == Vala.ParameterDirection.OUT) {
				write_string ("out ");
			}

			write_identifier (param.name);

			i++;
		}
		write_string (") =>");
		if (expr.statement_body != null) {
			expr.statement_body.accept (this);
		} else if (expr.expression_body != null) {
			expr.expression_body.accept (this);
		}
	}

	public override void visit_assignment (Vala.Assignment a) {
		a.left.accept (this);
		switch (a.operator) {
			case Vala.AssignmentOperator.SIMPLE:
				write_string (" = ");
				break;
			case Vala.AssignmentOperator.BITWISE_OR:
				write_string (" |= ");
				break;
			case Vala.AssignmentOperator.BITWISE_AND:
				write_string (" &= ");
				break;
			case Vala.AssignmentOperator.BITWISE_XOR:
				write_string (" ^= ");
				break;
			case Vala.AssignmentOperator.ADD:
				write_string (" += ");
				break;
			case Vala.AssignmentOperator.SUB:
				write_string (" -= ");
				break;
			case Vala.AssignmentOperator.MUL:
				write_string (" *= ");
				break;
			case Vala.AssignmentOperator.DIV:
				write_string (" /= ");
				break;
			case Vala.AssignmentOperator.PERCENT:
				write_string (" %= ");
				break;
			case Vala.AssignmentOperator.SHIFT_LEFT:
				write_string (" <<= ");
				break;
			case Vala.AssignmentOperator.SHIFT_RIGHT:
				write_string (" >>= ");
				break;
			default:
				break;
		}

		a.right.accept (this);
	}

	private void write_indent () {
		if (!bol) {
			stream.append_c ('\n');
		}

		if (spaces_instead_of_tabs) {
			stream.append (string.nfill (indent * tab_width, ' '));
		} else {
			stream.append (string.nfill (indent, '\t'));
		}

		bol = false;
	}

	private void write_comment (Vala.Comment comment) {
		try {
			if (fix_indent_regex == null)
				fix_indent_regex = new Regex ("\\n[\\t ]*");
		} catch (Error e) {
			assert_not_reached ();
		}

		string replacement = "";
		if (spaces_instead_of_tabs) {
			replacement = "\n%s ".printf (string.nfill (indent * tab_width, ' '));
		} else {
			replacement = "\n%s ".printf (string.nfill (indent, '\t'));
		}
		string fixed_content;
		try {
			fixed_content = fix_indent_regex.replace (comment.content, comment.content.length, 0, replacement);
		} catch (Error e) {
			assert_not_reached();
		}

		write_indent ();
		write_string ("/*");
		write_string (fixed_content);
		write_string ("*/");
	}

	private void write_identifier (string s) {
		if (s == "this") {
			write_string (s);
			return;
		}

		char* id = (char*)s;
		int id_length = (int)s.length;
		if (Vala.Scanner.get_identifier_or_keyword (id, id_length) != Vala.TokenType.IDENTIFIER ||
		    s.get_char ().isdigit ()) {
			stream.append_c ('@');
		}
		write_string (s);
	}

	private void write_return_type (Vala.DataType type) {
		if (type.is_weak ()) {
			write_string ("unowned ");
		}

		write_type (type);
	}

	private void write_type (Vala.DataType type) {
		write_string (type.to_qualified_string (current_scope));
	}

	private void write_type_suffix (Vala.DataType type) {
		var array_type = type as Vala.ArrayType;
		if (array_type != null && array_type.fixed_length) {
			write_string ("[");
			array_type.length.accept (this);
			write_string ("]");
		}
	}

	private void write_string (string s) {
		stream.append (s);
		bol = false;
	}

	private void write_newline () {
		stream.append_c ('\n');
		bol = true;
	}

	void write_code_block (Vala.Block? block) {
		if (block == null) {
			write_string (";");
			return;
		}

		block.accept (this);
	}

	private void write_begin_block () {
		if (!bol) {
			stream.append_c (' ');
		} else {
			write_indent ();
		}
		stream.append_c ('{');
		write_newline ();
		indent++;
	}

	private void write_end_block () {
		indent--;
		write_indent ();
		stream.append_c ('}');
	}

	private bool check_accessibility (Vala.Symbol sym) {
		return true;
	}

	private bool skip_since_tag_check (Vala.Symbol sym, string since_val) {
		Vala.Symbol parent_symbol = sym;

		while (parent_symbol.parent_symbol != null) {
			parent_symbol = parent_symbol.parent_symbol;
			if (parent_symbol.version.since == since_val) {
				return true;
			}
		}

		return false;
	}

	private void write_attributes (Vala.CodeNode node) {
		var sym = node as Vala.Symbol;

		var attributes = new GLib.Sequence<Vala.Attribute> ();
		foreach (var attr in node.attributes) {
			attributes.insert_sorted (attr, (a, b) => strcmp (a.name, b.name));
		}

		var iter = attributes.get_begin_iter ();
		while (!iter.is_end ()) {
			unowned Vala.Attribute attr = iter.get ();
			iter = iter.next ();

			var keys = new GLib.Sequence<string> ();
			foreach (var key in attr.args.get_keys ()) {
				if (key == "cheader_filename" && sym is Vala.Namespace) {
					continue;
				}
				keys.insert_sorted (key, (CompareDataFunc<string>) strcmp);
			}

			if (attr.name == "CCode" && keys.get_length () == 0) {
				// only cheader_filename on namespace
				continue;
			}

			if (sym != null && attr.args.size == 1 && attr.name == "Version") {
				string since_val = attr.get_string ("since");
				if (since_val != null && skip_since_tag_check (sym, since_val)) {
					continue;
				}
			}

			if (!(node is Vala.Parameter) && !(node is Vala.PropertyAccessor)) {
				write_indent ();
			}

			stream.append_printf ("[%s", attr.name);
			if (keys.get_length () > 0) {
				stream.append (" (");

				unowned string separator = "";
				var arg_iter = keys.get_begin_iter ();
				while (!arg_iter.is_end ()) {
					unowned string arg_name = arg_iter.get ();
					arg_iter = arg_iter.next ();
					if (arg_name == "cheader_filename") {
						stream.append_printf ("%scheader_filename = \"%s\"", separator, get_cheaders (sym));
					} else {
						stream.append_printf ("%s%s = %s", separator, arg_name, attr.args.get (arg_name));
					}
					separator = ", ";
				}

				stream.append (")");
			}
			stream.append ("]");
			if (node is Vala.Parameter || node is Vala.PropertyAccessor) {
				write_string (" ");
			} else {
				write_newline ();
			}
		}
	}

	private void write_accessibility (Vala.Symbol sym) {
		if (sym.access == Vala.SymbolAccessibility.PUBLIC) {
			write_string ("public ");
		} else if (sym.access == Vala.SymbolAccessibility.PROTECTED) {
			write_string ("protected ");
		} else if (sym.access == Vala.SymbolAccessibility.INTERNAL) {
			write_string ("internal ");
		} else if (sym.access == Vala.SymbolAccessibility.PRIVATE) {
			write_string ("private ");
		}

		if (sym.external && !sym.external_package) {
			write_string ("extern ");
		}
	}

	void write_property_accessor_accessibility (Vala.Symbol sym) {
		if (sym.access == Vala.SymbolAccessibility.PROTECTED) {
			write_string ("protected ");
		} else if (sym.access == Vala.SymbolAccessibility.INTERNAL) {
			write_string ("internal ");
		} else if (sym.access == Vala.SymbolAccessibility.PRIVATE) {
			write_string ("private ");
		}
	}

	void write_type_parameters (Vala.List<Vala.TypeParameter> type_params) {
		if (type_params.size > 0) {
			write_string ("<");
			bool first = true;
			foreach (Vala.TypeParameter type_param in type_params) {
				if (first) {
					first = false;
				} else {
					write_string (", ");
				}
				write_identifier (type_param.name);
			}
			write_string (">");
		}
	}
}
