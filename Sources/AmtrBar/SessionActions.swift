// Per-session actions — jump to its terminal, or end it — exposed as a
// native submenu per session under the menu's "Session actions" group.
// (This began life as a right-click context menu on the session rows, but
// menu tracking consumes right-clicks and tears down anything popped near
// its own dismissal — a submenu is the reliable, discoverable surface.)

import AppKit

final class SessionActions: NSObject, NSMenuDelegate {
    static let shared = SessionActions()

    /// The actions submenu for one session.
    func submenu(for s: FleetSession) -> NSMenu {
        let m = NSMenu(title: s.name)
        m.autoenablesItems = false
        m.delegate = self

        let jump = NSMenuItem(title: "Jump to terminal",
                              action: #selector(jump(_:)), keyEquivalent: "")
        jump.target = self
        jump.representedObject = s
        jump.isEnabled = !(s.tmux ?? "").isEmpty || s.pid != nil
        m.addItem(jump)

        m.addItem(.separator())
        let end = NSMenuItem(title: s.pid != nil ? "End session…"
                                                 : "End session (no pid)",
                             action: #selector(end(_:)), keyEquivalent: "")
        end.target = self
        end.representedObject = s
        end.isEnabled = s.pid != nil
        m.addItem(end)
        return m
    }

    /// Observability: proves hover actually opens a view-backed item's
    /// submenu (the one AppKit behavior this design leans on).
    func menuWillOpen(_ menu: NSMenu) {
        NSLog("%@", "amtrino: actions submenu opened for \(menu.title)")
    }

    @objc private func jump(_ mi: NSMenuItem) {
        guard let s = mi.representedObject as? FleetSession else { return }
        SessionFocus.focus(tmux: (s.tmux?.isEmpty ?? true) ? nil : s.tmux,
                           pid: s.pid)
    }

    /// Confirm, then SIGTERM — the same graceful quit the CLI gets from
    /// Ctrl-C twice; the terminal pane stays open and the conversation can
    /// be resumed from the CLI.
    @objc private func end(_ mi: NSMenuItem) {
        guard let s = mi.representedObject as? FleetSession,
              let pid = s.pid else { return }
        let a = NSAlert()
        a.messageText = "End session “\(s.name)”?"
        a.informativeText = "This sends a quit signal (SIGTERM) to the "
            + "\(s.provider) process (pid \(pid)) working in "
            + "\(s.projectTail). The terminal pane stays open, and the "
            + "conversation can usually be resumed from the CLI."
        a.alertStyle = .warning
        let endBtn = a.addButton(withTitle: "End Session")
        if #available(macOS 11.0, *) { endBtn.hasDestructiveAction = true }
        a.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        guard a.runModal() == .alertFirstButtonReturn else { return }
        if kill(pid_t(pid), SIGTERM) != 0 {
            NSLog("%@", "amtrino: SIGTERM \(pid) failed: errno \(errno)")
            NSSound.beep()
        } else {
            NSLog("%@", "amtrino: sent SIGTERM to \(s.provider) pid \(pid) (\(s.name))")
        }
    }
}
