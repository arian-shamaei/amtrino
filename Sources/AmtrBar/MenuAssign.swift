// The menu's 3×3 node grid — EXACTLY the menu bar icon's layout (node 1 =
// top-left … node 9 = bottom-right), so dropping a session somewhere means
// putting it THERE in the bar. One custom menu-item view; the session rows
// are their own items (SessionRowView) and report their drags here, since
// standard menu items cannot be dragged and a drag must cross items.

import AppKit

final class AssignSectionView: NSView {
    private var slots: [DisplaySession?] = []        // current 9-node layout
    private var reserved: Set<Int> = []              // assigned node indices
    private var cfg: [String?] = []
    /// repaint the status item + sibling row views after any change
    var onChange: (() -> Void)?

    // geometry
    private let nodeD: CGFloat = 34
    private let nodeGap: CGFloat = 7
    private var nodesH: CGFloat { nodeD * 3 + nodeGap * 2 + 12 }

    // live drag state, fed by the SessionRowView that owns the mouse
    private var dropSess: DisplaySession?
    private var dropPoint: NSPoint?
    private var hoverNode: Int?

    init(width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 10))
    }

    required init?(coder: NSCoder) { nil }

    func reload(store: FleetStore) {
        cfg = Settings.slots
        slots = store.slotted(hidden: Settings.hidden, slots: cfg)
        reserved = Set((0..<9).filter { $0 < cfg.count && cfg[$0] != nil })
        setFrameSize(NSSize(width: frame.width, height: nodesH))
        needsDisplay = true
    }

    /// True when the node holds a PINNED session (a real id, not the
    /// explicit-empty sentinel).
    private func isPinned(_ i: Int) -> Bool {
        i < cfg.count && cfg[i] != nil && cfg[i] != Settings.emptySlot
    }

    // MARK: geometry

    private func nodeRect(_ i: Int) -> NSRect {
        let col = CGFloat(i % 3), row = CGFloat(i / 3)
        let gridW = nodeD * 3 + nodeGap * 2
        let x0 = (bounds.width - gridW) / 2
        // row 0 on TOP, matching the icon (view origin is bottom-left)
        let yTop = bounds.height - 8
        return NSRect(x: x0 + col * (nodeD + nodeGap),
                      y: yTop - (row + 1) * nodeD - row * nodeGap,
                      width: nodeD, height: nodeD)
    }

    private func nodeAt(_ p: NSPoint) -> Int? {
        (0..<9).first { nodeRect($0).insetBy(dx: -4, dy: -4).contains(p) }
    }

    private func fromScreen(_ p: NSPoint) -> NSPoint? {
        guard let w = window else { return nil }
        return convert(w.convertPoint(fromScreen: p), from: nil)
    }

    // MARK: drag interface (called by SessionRowView)

    func dragUpdate(_ d: DisplaySession, screenPoint: NSPoint) {
        guard let p = fromScreen(screenPoint) else { return }
        dropSess = d
        dropPoint = p
        hoverNode = nodeAt(p)
        needsDisplay = true
    }

    /// Finish a drag; pins when the drop landed on a node.
    @discardableResult
    func dragDrop(_ d: DisplaySession, screenPoint: NSPoint) -> Bool {
        defer {
            dropSess = nil
            dropPoint = nil
            hoverNode = nil
            needsDisplay = true
        }
        guard let p = fromScreen(screenPoint), let n = nodeAt(p)
        else { return false }
        var s = Settings.slots
        for j in 0..<s.count where s[j] == d.sess.id { s[j] = nil }
        s[n] = d.sess.id
        Settings.slots = s
        onChange?()
        return true
    }

    func dragCancel() {
        dropSess = nil
        dropPoint = nil
        hoverNode = nil
        needsDisplay = true
    }

    // MARK: drawing

    override func draw(_ dirtyRect: NSRect) {
        // this view lives on the MENU's background, not the bar's
        IconRenderer.barIsDark = effectiveAppearance
            .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let now = Date()

        // visual-validation hook: node 1's screen rect, for automation
        if ProcessInfo.processInfo.environment["AMTRINO_DUMP"] != nil,
           let w = window {
            let sr = w.convertToScreen(convert(nodeRect(0), to: nil))
            NSLog("%@", "amtrino nodeframe 1: \(NSStringFromRect(sr))")
        }

        // the 9 nodes. Ring language must mirror REALITY in the bar:
        // every occupied node reads identically (they are all shown);
        // pinned-vs-auto is a ⌖ badge, not a heavier ring; a reserved
        // node holding no session is a dashed ring (a kept-open seat).
        for i in 0..<9 {
            let r = nodeRect(i)
            let occupiedHere = (slots[safe: i] ?? nil) != nil
            let ring = NSBezierPath(ovalIn: r.insetBy(dx: 1.5, dy: 1.5))
            let active = dropSess != nil && hoverNode == i
            if reserved.contains(i) && !occupiedHere {
                ring.setLineDash([3, 2], count: 2, phase: 0)
            }
            (active ? NSColor.controlAccentColor
                    : occupiedHere
                        ? NSColor.labelColor.withAlphaComponent(0.55)
                        : NSColor.separatorColor).setStroke()
            ring.lineWidth = active ? 2.5 : occupiedHere ? 1.4 : 1.1
            ring.stroke()
            if let d = slots[safe: i] ?? nil {
                IconRenderer.statusDotImage(d, r: 7, canvas: 20, now: now)
                    .draw(in: NSRect(x: r.midX - 10, y: r.midY - 10,
                                     width: 20, height: 20))
            } else {
                ("\(i + 1)" as NSString).draw(
                    at: NSPoint(x: r.midX - 3, y: r.midY - 7),
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                        .foregroundColor: NSColor.tertiaryLabelColor])
            }
            if isPinned(i) {
                // pinned marker: corner badge, same glyph as the row tag
                ("⌖" as NSString).draw(
                    at: NSPoint(x: r.maxX - 8, y: r.minY - 2),
                    withAttributes: [
                        .font: NSFont.systemFont(ofSize: 9, weight: .semibold),
                        .foregroundColor: NSColor.controlAccentColor])
            }
        }

        // drag ghost, once the pointer is over this view
        if let d = dropSess, let p = dropPoint, bounds.contains(p) {
            IconRenderer.statusDotImage(d, r: 8, canvas: 22, now: now)
                .draw(in: NSRect(x: p.x - 11, y: p.y - 11,
                                 width: 22, height: 22))
        }
    }

    // MARK: mouse (node clicks)

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        guard let n = nodeAt(p) else { return }
        // The node click cycle, and every step is VISIBLE (clearing a
        // pin straight to auto-fill refills instantly with a full
        // fleet — it looked like the click did nothing):
        //   occupied (pinned or auto) → EMPTY (a real gap in the bar)
        //   empty (dashed)            → auto-fill again
        //   free numbered             → no-op
        var s = Settings.slots
        let occupiedHere = (slots[safe: n] ?? nil) != nil
        if s[n] == Settings.emptySlot {
            s[n] = nil
        } else if s[n] != nil || occupiedHere {
            s[n] = Settings.emptySlot
        } else {
            return
        }
        Settings.slots = s
        onChange?()
    }

    // a row drag whose events land here (the cursor is over the grid)
    override func mouseDragged(with event: NSEvent) {
        RowDrag.dragged(to: NSEvent.mouseLocation, nodes: self)
    }

    override func mouseUp(with event: NSEvent) {
        RowDrag.up(at: NSEvent.mouseLocation, on: nil, nodes: self)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
