// One session = one menu item = one of these views, so every session row
// carries a NATIVE submenu (▸ jump / end — see SessionActions). The row
// keeps the custom drawing (identity glyph, columns, dimming) and the
// drag-to-pin gesture: the drag is tracked here and reported to the
// AssignSectionView (the 3×3 node grid, its own menu item above).

import AppKit

/// Grid placement derived once per refresh: which node each session sits
/// in, which nodes are occupied — shared by row views and the node grid.
struct GridDerivation {
    let slotOf: [String: Int]
    let occupied: [Int]
    let reserved: Set<Int>

    init(store: FleetStore) {
        let cfg = Settings.slots
        let slots = store.slotted(hidden: Settings.hidden, slots: cfg)
        var so: [String: Int] = [:]
        for (i, d) in slots.enumerated() {
            if let d { so[d.sess.id] = i }
        }
        slotOf = so
        occupied = slots.enumerated().compactMap { $1 == nil ? nil : $0 }
        reserved = Set((0..<9).filter { $0 < cfg.count && cfg[$0] != nil })
    }
}

final class SessionRowView: NSView {
    private let sess: FleetSession
    private let single: Bool
    private let dupTag: String
    /// the node grid to report drags to (grid mode only)
    weak var nodesView: AssignSectionView?
    /// repaint the status item + sibling views after any change
    var onChange: (() -> Void)?

    private var gridIndex: Int?
    private var occupied: [Int] = []
    private var reserved: Set<Int> = []
    private var dimmed = false
    private var hover = false
    private var dragging = false
    private var downPoint = NSPoint.zero
    private var tracking: NSTrackingArea?

    private var display: DisplaySession {
        DisplaySession(sess: sess, finishedAgo: nil)
    }

    init(width: CGFloat, sess: FleetSession, dupTag: String, single: Bool,
         store: FleetStore) {
        self.sess = sess
        self.single = single
        self.dupTag = dupTag
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        refresh(store: store)
    }

    required init?(coder: NSCoder) { nil }

    /// Re-derive everything shown from current settings + roster.
    func refresh(store: FleetStore) {
        dimmed = !single && Settings.hidden.contains(sess.id)
        if single {
            gridIndex = nil
            occupied = []
            reserved = []
        } else {
            let g = GridDerivation(store: store)
            gridIndex = g.slotOf[sess.id]
            occupied = g.occupied
            reserved = g.reserved
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        IconRenderer.barIsDark = effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let r = bounds
        // highlight on hover (mirrors the item's submenu highlight)
        if (hover || enclosingMenuItem?.isHighlighted == true) && !dragging {
            NSColor.selectedContentBackgroundColor
                .withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: r.insetBy(dx: 6, dy: 1),
                         xRadius: 5, yRadius: 5).fill()
        }
        if single && Settings.pinned == sess.id {
            // the pinned session, menu-checkmark position
            ("✓" as NSString).draw(
                at: NSPoint(x: 2, y: r.minY + 3),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: NSColor.labelColor])
        }
        let alpha: CGFloat = dimmed ? 0.35 : 1.0
        let map = IconRenderer.menuDot(
            display, gridIndex: gridIndex, occupied: occupied, now: Date())
        map.draw(in: NSRect(x: 12, y: r.minY + 2, width: 18, height: 18),
                 from: .zero, operation: .sourceOver, fraction: alpha)

        // invisible table: name | project | % | badge, fixed columns,
        // tail-truncated so no field can shove its neighbors
        let trunc = NSMutableParagraphStyle()
        trunc.lineBreakMode = .byTruncatingTail
        let nameColor = dimmed ? NSColor.tertiaryLabelColor
                               : NSColor.labelColor
        ("\(sess.name)\(dupTag)" as NSString).draw(
            in: NSRect(x: 38, y: r.minY + 3, width: 150, height: 16),
            withAttributes: [
                .font: NSFont.menuFont(ofSize: 13),
                .foregroundColor: nameColor,
                .paragraphStyle: trunc])
        let proj = sess.provider == "claude"
            ? sess.projectTail
            : "\(sess.projectTail) · \(sess.provider)"
        (proj as NSString).draw(
            in: NSRect(x: 196, y: r.minY + 3, width: 104, height: 16),
            withAttributes: [
                .font: NSFont.menuFont(ofSize: 13),
                .foregroundColor: dimmed
                    ? NSColor.tertiaryLabelColor
                    : NSColor.secondaryLabelColor,
                .paragraphStyle: trunc])
        if let f = sess.fill {
            let pct = "\(Int((f * 100).rounded()))%" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(
                    ofSize: 12, weight: .regular),
                .foregroundColor: dimmed
                    ? NSColor.tertiaryLabelColor
                    : NSColor.secondaryLabelColor]
            let sz = pct.size(withAttributes: attrs)
            pct.draw(at: NSPoint(x: 340 - sz.width, y: r.minY + 4),
                     withAttributes: attrs)
        }
        // badge column: pin location, or the hidden marker
        if let n = gridIndex, reserved.contains(n) {
            ("⌖\(n + 1)" as NSString).draw(
                at: NSPoint(x: 344, y: r.minY + 3),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.controlAccentColor])
        } else if dimmed {
            ("off" as NSString).draw(
                at: NSPoint(x: 344, y: r.minY + 4),
                withAttributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: NSColor.tertiaryLabelColor])
        }
        // a view-backed item draws no native submenu chevron — hand-draw it
        ("›" as NSString).draw(
            at: NSPoint(x: bounds.width - 13, y: r.minY + 3),
            withAttributes: [
                .font: NSFont.menuFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor])

        // visual-validation hook: this row's screen rect, for automation
        if ProcessInfo.processInfo.environment["AMTRINO_DUMP"] != nil,
           let w = window {
            let sr = w.convertToScreen(convert(bounds, to: nil))
            NSLog("%@", "amtrino rowframe \(sess.name): \(NSStringFromRect(sr))")
        }
    }

    // MARK: mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = tracking { removeTrackingArea(t) }
        let t = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil)
        addTrackingArea(t)
        tracking = t
    }

    override func mouseEntered(with event: NSEvent) {
        hover = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        hover = false
        needsDisplay = true
    }

    // The menu window routes every mouse event to the view UNDER THE
    // CURSOR, not the mouse-down view (verified: a drag's mouseDragged
    // lands on whichever row it crosses). So a drag lives in shared state
    // (RowDrag) that any of our views advances when an event reaches it.

    override func mouseDown(with event: NSEvent) {
        RowDrag.begin(origin: self, display: display,
                      canDrag: !single, at: NSEvent.mouseLocation)
    }

    override func mouseDragged(with event: NSEvent) {
        RowDrag.dragged(to: NSEvent.mouseLocation, nodes: nodesView)
    }

    override func mouseUp(with event: NSEvent) {
        RowDrag.up(at: NSEvent.mouseLocation, on: self, nodes: nodesView)
    }

    /// The plain-click action, invoked by RowDrag when a press both began
    /// and ended on this row without dragging.
    func performClick() {
        if single {
            // click pins; clicking the pinned row again returns to auto
            Settings.pinned = Settings.pinned == sess.id ? nil : sess.id
        } else {
            // plain click: show/hide in the grid
            var h = Settings.hidden
            if h.contains(sess.id) { h.remove(sess.id) } else { h.insert(sess.id) }
            Settings.hidden = h
        }
        onChange?()
    }
}

/// Shared press/drag state for the session rows — static because the menu
/// window delivers each event to the view under the cursor, so one gesture
/// is witnessed by several views.
enum RowDrag {
    private static var origin: SessionRowView?
    private static var display: DisplaySession?
    private static var canDrag = false
    private static var started = false
    private static var downScreen = NSPoint.zero

    static func begin(origin o: SessionRowView, display d: DisplaySession,
                      canDrag c: Bool, at p: NSPoint) {
        origin = o
        display = d
        canDrag = c
        started = false
        downScreen = p
    }

    static func dragged(to p: NSPoint, nodes: AssignSectionView?) {
        guard canDrag, let d = display else { return }
        if !started && hypot(p.x - downScreen.x, p.y - downScreen.y) > 4 {
            started = true
        }
        guard started else { return }
        nodes?.dragUpdate(d, screenPoint: p)
    }

    static func up(at p: NSPoint, on view: SessionRowView?,
                   nodes: AssignSectionView?) {
        defer { origin = nil; display = nil; started = false }
        if started, let d = display {
            nodes?.dragDrop(d, screenPoint: p)
        } else if let o = origin, view === o {
            o.performClick()
        } else {
            nodes?.dragCancel()
        }
    }
}
