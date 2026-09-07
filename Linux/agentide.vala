/* AgentIDE Linux shell: Adwaita window that speaks NDJSON to
 * agentide-core. VTE comes later; this only proves the bridge. */

private async void ping_core (Gtk.Label status) {
    try {
        string[] argv = { "agentide-core" };
        var flags = SubprocessFlags.STDIN_PIPE
            | SubprocessFlags.STDOUT_PIPE
            | SubprocessFlags.STDERR_PIPE;
        var proc = new Subprocess.newv (argv, flags);

        var stdin = proc.get_stdin_pipe ();
        var stdout = new DataInputStream (proc.get_stdout_pipe ());

        stdin.write_all ("{\"cmd\":\"ping\"}\n".data, null);
        stdin.close ();

        size_t length;
        string? line = yield stdout.read_line_async (Priority.DEFAULT, null, out length);
        if (line != null && line.contains ("\"pong\":true")) {
            status.label = "agentide-core: pong";
        } else {
            status.label = "agentide-core: unexpected reply";
        }

        yield proc.wait_async ();
    } catch (Error e) {
        status.label = "agentide-core: " + e.message;
    }
}

int main (string[] args) {
    var app = new Adw.Application ("app.agentide.AgentIDE", ApplicationFlags.DEFAULT_FLAGS);
    app.activate.connect (() => {
        var window = new Adw.ApplicationWindow (app) {
            title = "AgentIDE",
            default_width = 960,
            default_height = 640
        };

        var split = new Adw.NavigationSplitView ();
        var sidebar_page = new Adw.NavigationPage (new Gtk.Label ("Sessions"), "Sidebar");
        var status = new Gtk.Label ("Contacting agentide-core…") {
            margin_top = 24,
            margin_bottom = 24,
            margin_start = 24,
            margin_end = 24
        };
        var content_page = new Adw.NavigationPage (status, "AgentIDE");
        split.sidebar = sidebar_page;
        split.content = content_page;
        window.content = split;
        window.present ();

        ping_core.begin (status);
    });
    return app.run (args);
}
