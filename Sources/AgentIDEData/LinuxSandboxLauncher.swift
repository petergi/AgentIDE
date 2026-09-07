#if os(Linux)
    /// Builds the sudo and `agentide-sandbox enter` argv that runs a
    /// payload as the sandvault sandbox user under bubblewrap. This
    /// is the Linux counterpart of `SandvaultLauncher`.
    public struct LinuxSandboxLauncher: SandboxLaunching, Sendable {
        // MARK: Lifecycle

        /// Creates a launcher for the given host (GUI) user name.
        public init(hostUser: String) {
            self.hostUser = hostUser
        }

        // MARK: Public

        /// The host user the sandbox identity is derived from.
        public let hostUser: String

        /// The login shell that runs payloads inside the sandbox.
        public let loginShell = "/bin/bash"

        /// Background the server without a controlling terminal.
        /// Mac uses zsh's `&!`; on Linux, `enter`'s `--new-session`
        /// and a plain `&` are enough (macOS `nohup` is the wrong
        /// tool there, and HerdrClient already redirects output).
        public let detachSuffix = "&"

        /// Loads the sandbox user's bash startup files before a
        /// long-lived server start outside an already-configured
        /// session.
        public let profileBootstrap =
            "cd ~ && { test -f ~/.profile && . ~/.profile; "
                + "test -f ~/.bashrc && . ~/.bashrc; }; "

        /// Homebrew on Linux first, then the usual system path.
        public let sandboxPath =
            "/home/linuxbrew/.linuxbrew/bin:/usr/local/bin:/usr/bin:/bin"

        /// The sandbox user, the host user with a `sandvault-` prefix.
        public var sandboxUser: String {
            "sandvault-" + hostUser
        }

        /// The sandbox user's home directory.
        public var sandboxHome: String {
            "/home/" + sandboxUser
        }

        /// The workspace directory both users read and write.
        public var sharedWorkspace: String {
            "/var/lib/agentide/" + hostUser
        }

        /// The installed bubblewrap entry helper.
        public var enterPath: String {
            "/usr/libexec/agentide/enter"
        }

        /// The full argv that runs `payload` inside the sandbox
        /// through bash, with home, shared workspace and session
        /// identity passed to `enter`.
        public func command(
            payload: String,
            initialDirectory: String,
            sessionID: String,
            sessionName: String,
        ) -> [String] {
            [
                "sudo", "--login", "--set-home", "--user=" + sandboxUser,
                enterPath,
                "--home=" + sandboxHome,
                "--shared=" + sharedWorkspace,
                "--workdir=" + initialDirectory,
                "--session-id=" + sessionID,
                "--session-name=" + sessionName,
                "--",
                loginShell, "-lc", payload,
            ]
        }
    }
#endif
