/* AgentIDE Linux shell: Adwaita window that speaks NDJSON to
 * agentide-core. The sidebar lists overview worktrees; the content
 * pane is a VTE terminal when the build found vte-2.91-gtk4, else
 * a placeholder. No session attach yet. */

private class WorktreeRow : Object {
    public string repository_name { get; set; default = ""; }
    public string branch { get; set; default = ""; }
    public string worktree_path { get; set; default = ""; }
    public string session_name { get; set; default = ""; }
    public string activity { get; set; default = ""; }

    public string title () {
        var name = repository_name.length > 0 ? repository_name : worktree_path;
        if (branch.length > 0) {
            return @"$name · $branch";
        }
        return name;
    }
}

private List<WorktreeRow> parse_overview (string line) {
    var rows = new List<WorktreeRow> ();
    try {
        var parser = new Json.Parser ();
        parser.load_from_data (line);
        var root = parser.get_root ().get_object ();
        if (!root.get_boolean_member ("ok")) {
            return rows;
        }
        if (!root.has_member ("worktrees")) {
            return rows;
        }
        var arr = root.get_array_member ("worktrees");
        for (uint i = 0; i < arr.get_length (); i++) {
            var obj = arr.get_object_element (i);
            var row = new WorktreeRow ();
            row.repository_name = obj.get_string_member_with_default ("repositoryName", "");
            row.branch = obj.get_string_member_with_default ("branch", "");
            row.worktree_path = obj.get_string_member_with_default ("worktreePath", "");
            if (obj.has_member ("sessionName") && !obj.get_null_member ("sessionName")) {
                row.session_name = obj.get_string_member ("sessionName");
            }
            if (obj.has_member ("agentActivity") && !obj.get_null_member ("agentActivity")) {
                row.activity = obj.get_string_member ("agentActivity");
            }
            rows.append (row);
        }
    } catch (Error e) {
        warning ("overview parse: %s", e.message);
    }
    return rows;
}

private Gtk.Widget make_terminal_pane () {
#if HAVE_VTE
    var terminal = new Vte.Terminal ();
    terminal.set_size (80, 24);
    terminal.feed ("Attach a herdr session to use this pane.\r\n".data);
    var scroll = new Gtk.ScrolledWindow ();
    scroll.child = terminal;
    scroll.vexpand = true;
    return scroll;
#else
    var placeholder = new Adw.StatusPage () {
        title = "Terminal pane",
        description = "Build with vte-2.91-gtk4 for a VTE placeholder. Session attach is not wired yet."
    };
    return placeholder;
#endif
}

private async void load_overview (Gtk.ListBox list, Gtk.Label status) {
    try {
        string[] argv = { "agentide-core" };
        var flags = SubprocessFlags.STDIN_PIPE
            | SubprocessFlags.STDOUT_PIPE
            | SubprocessFlags.STDERR_PIPE;
        var proc = new Subprocess.newv (argv, flags);

        var stdin = proc.get_stdin_pipe ();
        var stdout = new DataInputStream (proc.get_stdout_pipe ());

        stdin.write_all ("{\"cmd\":\"overview\"}\n{\"cmd\":\"quit\"}\n".data, null);
        stdin.close ();

        size_t length;
        string? line = yield stdout.read_line_async (Priority.DEFAULT, null, out length);
        yield proc.wait_async ();

        if (line == null) {
            status.label = "agentide-core: empty overview";
            return;
        }

        var rows = parse_overview (line);
        while (list.get_first_child () != null) {
            list.remove (list.get_first_child ());
        }
        if (rows.length () == 0) {
            status.label = "No worktrees yet. Clone into the shared workspace.";
            var empty = new Gtk.Label ("Nothing listed");
            empty.add_css_class ("dim-label");
            list.append (empty);
            return;
        }

        status.label = @"$(rows.length ()) worktree(s)";
        foreach (var row in rows) {
            var title = new Gtk.Label (row.title ()) {
                xalign = 0,
                ellipsize = Pango.EllipsizeMode.MIDDLE
            };
            var subtitle_text = row.session_name.length > 0 ? row.session_name : row.worktree_path;
            var subtitle = new Gtk.Label (subtitle_text) {
                xalign = 0,
                ellipsize = Pango.EllipsizeMode.MIDDLE
            };
            subtitle.add_css_class ("dim-label");
            subtitle.add_css_class ("caption");
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            box.append (title);
            box.append (subtitle);
            box.margin_top = 8;
            box.margin_bottom = 8;
            box.margin_start = 8;
            box.margin_end = 8;
            list.append (box);
        }
    } catch (Error e) {
        status.label = "agentide-core: " + e.message;
    }
}

int main (string[] args) {
    var app = new Adw.Application ("app.agentide.AgentIDE", ApplicationFlags.DEFAULT_FLAGS);
    app.activate.connect (() => {
        var window = new Adw.ApplicationWindow (app) {
            title = "AgentIDE",
            default_width = 1100,
            default_height = 720
        };

        var list = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        list.add_css_class ("navigation-sidebar");
        var sidebar_scroll = new Gtk.ScrolledWindow ();
        sidebar_scroll.child = list;
        sidebar_scroll.hexpand = true;

        var status = new Gtk.Label ("Loading worktrees…") {
            xalign = 0,
            margin_top = 8,
            margin_bottom = 8,
            margin_start = 12,
            margin_end = 12
        };
        var sidebar_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        sidebar_box.append (status);
        sidebar_box.append (sidebar_scroll);

        var split = new Adw.NavigationSplitView ();
        split.sidebar = new Adw.NavigationPage (sidebar_box, "Worktrees");
        split.content = new Adw.NavigationPage (make_terminal_pane (), "Session");
        window.content = split;
        window.present ();

        load_overview.begin (list, status);
    });
    return app.run (args);
}
