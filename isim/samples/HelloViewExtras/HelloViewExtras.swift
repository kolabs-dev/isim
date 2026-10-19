// Sample: view and control members from the documentation sweep (#9), each logged with "vx".
// - Views: margins that preserve the superview's or ignore the safe area, alignment rect insets, a baseline view,
//   the update constraints pass, content size category limits, UIView.Invalidating, the delete system animation,
//   repeated animations, label and image view extras
// - Controls: a configuration with a subtitle and a title transformer, a pop-up button (indicator), an attributed
//   title, a button menu on a long press, a system image button, event handler enumeration, a toggle's selection
//   look, segment actions, stepper images, switch styles, a progress view following a Progress, page controls (a
//   timer progress, scrubbing, indicator images)
// - Calendar: a calendar view (single, multiple or week selection, decorations) in a scroll view that scrolls to the
//   top from the status bar and with the keyboard
import UIKit

func log(_ s: String) { print("vx \(s)") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let tabs = UITabBarController()
        let views = ViewsViewController(), controls = ControlsViewController(), calendar = CalendarViewController()
        views.tabBarItem = UITabBarItem(title: "Views", image: UIImage(systemName: "square.on.square"), tag: 0)
        controls.tabBarItem = UITabBarItem(title: "Controls", image: UIImage(systemName: "slider.horizontal.3"), tag: 1)
        calendar.tabBarItem = UITabBarItem(title: "Calendar", image: UIImage(systemName: "calendar"), tag: 2)
        tabs.viewControllers = [views, controls, calendar]
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
}

// MARK: - Views
final class AlignedView: UIView {
    override var alignmentRectInsets: UIEdgeInsets { UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10) }
    override var intrinsicContentSize: CGSize { CGSize(width: 60, height: 20) }
}
final class BaselineBox: UIView {
    let inner = UILabel()
    override var forFirstBaselineLayout: UIView { inner }
    override var forLastBaselineLayout: UIView { inner }
}
final class UpdatingView: UIView {
    var updates = 0
    override func updateConstraints() { updates += 1; log("updateConstraints \(updates)"); super.updateConstraints() }
}
final class Badge: UIView {
    @UIView.Invalidating(.layout, .display) var count = 0
    override func layoutSubviews() { super.layoutSubviews(); if count > 0 { log("invalidating layout \(count)") } }
}

final class ViewsViewController: UIViewController {
    let outer = UIView(), child = UIView(), marginLabel = UILabel()
    let unsafe = UIView(), aligned = AlignedView(), baseline = BaselineBox(), reference = UILabel()
    let updating = UpdatingView(), limited = UILabel(), badge = Badge(), doomed = UIView(), pulse = UIView()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // margins: the child preserves the outer view's 40 pt margin where it overlaps it
        outer.frame = CGRect(x: 0, y: 120, width: 300, height: 60); outer.layoutMargins = UIEdgeInsets(top: 0, left: 40, bottom: 0, right: 0)
        outer.backgroundColor = .systemGray6
        child.frame = CGRect(x: 10, y: 0, width: 280, height: 60); child.layoutMargins = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        child.preservesSuperviewLayoutMargins = true
        marginLabel.text = "Margins"; marginLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outer); outer.addSubview(child); child.addSubview(marginLabel)
        NSLayoutConstraint.activate([marginLabel.leadingAnchor.constraint(equalTo: child.layoutMarginsGuide.leadingAnchor),
                                     marginLabel.centerYAnchor.constraint(equalTo: child.centerYAnchor)])
        // margins that ignore the safe area (the view sits under the status bar)
        unsafe.frame = CGRect(x: 0, y: 0, width: 100, height: 100); unsafe.layoutMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        unsafe.insetsLayoutMarginsFromSafeArea = false
        view.addSubview(unsafe)
        // alignment rect: the frame reaches 10 pt past the leading edge it is pinned to
        aligned.backgroundColor = .systemTeal; aligned.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(aligned)
        NSLayoutConstraint.activate([aligned.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
                                     aligned.topAnchor.constraint(equalTo: view.topAnchor, constant: 200)])
        // a box whose first baseline is its inner label's, aligned with another label's
        baseline.inner.text = "Inner"; baseline.inner.font = .systemFont(ofSize: 15); baseline.inner.frame = CGRect(x: 0, y: 30, width: 80, height: 20)
        baseline.addSubview(baseline.inner); baseline.translatesAutoresizingMaskIntoConstraints = false
        reference.text = "Reference"; reference.font = .systemFont(ofSize: 15); reference.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(baseline); view.addSubview(reference)
        NSLayoutConstraint.activate([baseline.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                                     baseline.topAnchor.constraint(equalTo: view.topAnchor, constant: 240),
                                     baseline.widthAnchor.constraint(equalToConstant: 80), baseline.heightAnchor.constraint(equalToConstant: 60),
                                     reference.leadingAnchor.constraint(equalTo: baseline.trailingAnchor, constant: 20),
                                     reference.firstBaselineAnchor.constraint(equalTo: baseline.firstBaselineAnchor)])
        // the update constraints pass (a subclass overriding updateConstraints gets it when it enters the window)
        updating.frame = CGRect(x: 20, y: 320, width: 40, height: 40); updating.backgroundColor = .systemYellow
        view.addSubview(updating)
        // Dynamic Type limited to Medium
        limited.text = "Limited"; limited.frame = CGRect(x: 80, y: 320, width: 200, height: 30); limited.maximumContentSizeCategory = .medium
        view.addSubview(limited)
        badge.frame = CGRect(x: 20, y: 380, width: 40, height: 40); badge.backgroundColor = .systemRed; view.addSubview(badge)
        doomed.frame = CGRect(x: 80, y: 380, width: 40, height: 40); doomed.backgroundColor = .systemPurple; view.addSubview(doomed)
        pulse.frame = CGRect(x: 140, y: 380, width: 40, height: 40); pulse.backgroundColor = .systemGreen; view.addSubview(pulse)
        // label and image view members
        let label = UILabel(); label.text = "A label"; label.lineBreakStrategy = .standard; label.showsExpansionTextWhenTruncated = true
        label.allowsDefaultTighteningForTruncation = true; label.baselineAdjustment = .alignCenters
        let image = UIImageView(image: UIImage(systemName: "sun.max")); image.preferredImageDynamicRange = .high
        log("label extras \(label.showsExpansionTextWhenTruncated) \(label.baselineAdjustment == .alignCenters) image range \(image.preferredImageDynamicRange == .high)")
        log("alignment round trip \(aligned.frame(forAlignmentRect: aligned.alignmentRect(forFrame: CGRect(x: 0, y: 0, width: 80, height: 20))))")
        log("forced animations \(UIView.areAnimationsEnabled)")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.layoutIfNeeded()
        log("margins preserved \(Int(marginLabel.frame.minX))")
        log("safe area margins \(unsafe.insetsLayoutMarginsFromSafeArea) \(Int(unsafe.layoutMarginsGuide.layoutFrame.minY))")
        log("alignment frame x \(Int(aligned.frame.minX)) width \(Int(aligned.frame.width))")
        let refBaseline = reference.frame.minY + reference.font.ascender, innerBaseline = baseline.frame.minY + baseline.inner.frame.minY + baseline.inner.font.ascender
        log("baseline view \(baseline.forFirstBaselineLayout === baseline.inner) aligned \(abs(refBaseline - innerBaseline) < 1)")
        log("affecting horizontal \(aligned.constraintsAffectingLayout(for: .horizontal).count) ambiguous \(aligned.hasAmbiguousLayout)")
        updating.setNeedsUpdateConstraints()
        log("needs update \(updating.needsUpdateConstraints())")
        updating.updateConstraintsIfNeeded()
        log("needs update after \(updating.needsUpdateConstraints())")
        log("clamped \(limited.traitCollection.preferredContentSizeCategory.rawValue) \(limited.appliedContentSizeCategoryLimitsDescription.contains("maximum"))")
        badge.count = 3
        UIView.perform(.delete, on: [doomed], options: [], animations: nil) { _ in log("deleted \(self.doomed.superview == nil)") }
        UIView.animate(withDuration: 0.1, animations: {
            UIView.modifyAnimations(withRepeatCount: 2, autoreverses: true) { self.pulse.alpha = 0.3 }
        }, completion: { _ in log("repeated animation done") })
    }
}

// MARK: - Controls
final class ControlsViewController: UIViewController, UIPageControlTimerProgressDelegate {
    let progress = Progress(totalUnitCount: 10)
    let progressView = UIProgressView(progressViewStyle: .default)
    let pager = UIPageControl(), scrubber = UIPageControl()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // a configuration with a subtitle, the title made bold by its transformer
        var sub = UIButton.Configuration.filled(); sub.title = "Title"; sub.subtitle = "Subtitle"
        sub.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a; a.font = UIFont.boldSystemFont(ofSize: 20); return a
        }
        sub.imageColorTransformer = .grayscale
        let subButton = UIButton(configuration: sub); subButton.accessibilityIdentifier = "subtitle-button"
        var plain = UIButton.Configuration.filled(); plain.title = "Title"
        let h1 = subButton.intrinsicContentSize.height, h0 = UIButton(configuration: plain).intrinsicContentSize.height
        log("subtitle taller \(h1 > h0 + 10) label \(subButton.subtitleLabel?.text ?? "-")")
        subButton.frame = CGRect(x: 20, y: 70, width: 160, height: h1)
        view.addSubview(subButton)
        // a pop-up button: the menu as its primary action, the chosen item as its title, the pop-up indicator
        var popupConf = UIButton.Configuration.gray(); popupConf.indicator = .popup
        let popup = UIButton(configuration: popupConf)
        popup.menu = UIMenu(options: .singleSelection, children: ["Red", "Green", "Blue"].map { name in
            UIAction(title: name, state: name == "Red" ? .on : .off) { _ in log("popup chose \(name)") }
        })
        popup.showsMenuAsPrimaryAction = true; popup.changesSelectionAsPrimaryAction = true
        popup.accessibilityIdentifier = "popup-button"
        popup.frame = CGRect(x: 200, y: 70, width: 140, height: 44)
        view.addSubview(popup)
        // an attributed title for the normal state
        let attr = UIButton(type: .system)
        attr.setAttributedTitle(NSAttributedString(string: "Attributed", attributes: [.foregroundColor: UIColor.systemRed, .font: UIFont.boldSystemFont(ofSize: 18)]), for: .normal)
        attr.frame = CGRect(x: 20, y: 140, width: 140, height: 40); attr.accessibilityIdentifier = "attr-button"
        view.addSubview(attr)
        log("attributed current title \(attr.currentTitle ?? "-") \(attr.currentAttributedTitle != nil)")
        // a long press shows a button's menu
        let menuButton = UIButton(type: .system); menuButton.setTitle("Hold me", for: .normal)
        menuButton.menu = UIMenu(children: [UIAction(title: "Copy") { _ in log("menu Copy") }, UIAction(title: "Share") { _ in log("menu Share") }])
        menuButton.frame = CGRect(x: 200, y: 140, width: 140, height: 40); menuButton.accessibilityIdentifier = "menu-button"
        view.addSubview(menuButton)
        log("context menu enabled \(menuButton.isContextMenuInteractionEnabled) \(menuButton.contextMenuInteraction != nil)")
        // a system button with an image, its handlers and the primary action
        let plus = UIButton.systemButton(with: UIImage(systemName: "plus.circle")!, target: self, action: #selector(plusTapped))
        plus.frame = CGRect(x: 20, y: 200, width: 44, height: 44); plus.accessibilityIdentifier = "plus-button"
        plus.addAction(UIAction(identifier: UIAction.Identifier("extra")) { _ in log("extra action") }, for: .touchUpInside)
        view.addSubview(plus)
        var handlers = 0
        plus.enumerateEventHandlers { action, target, events, _ in handlers += 1; _ = (action, target, events) }
        plus.removeAction(identifiedBy: UIAction.Identifier("extra"), for: .touchUpInside)
        var after = 0
        plus.enumerateEventHandlers { _, _, _, _ in after += 1 }
        log("handlers \(handlers) after remove \(after)")
        plus.contentHorizontalAlignment = .leading
        log("effective alignment left \(plus.effectiveContentHorizontalAlignment == .left)")
        // a toggle: a selected plain button looks tinted
        var toggleConf = UIButton.Configuration.plain(); toggleConf.title = "Toggle"
        let toggle = UIButton(configuration: toggleConf); toggle.changesSelectionAsPrimaryAction = true
        toggle.configurationUpdateHandler = { b in log("toggle selected \(b.isSelected) hovered \(b.isHovered)") }
        toggle.frame = CGRect(x: 80, y: 200, width: 100, height: 44); toggle.accessibilityIdentifier = "toggle"
        view.addSubview(toggle)
        // segments made from actions
        let segments = UISegmentedControl(frame: CGRect(x: 20, y: 260, width: 300, height: 32), actions: ["One", "Two", "Three"].map { t in
            UIAction(title: t, identifier: UIAction.Identifier("seg-\(t)")) { _ in log("segment action \(t)") }
        })
        segments.accessibilityIdentifier = "segments"
        segments.setContentOffset(CGSize(width: 0, height: 1), forSegmentAt: 0)
        view.addSubview(segments)
        log("segment index \(segments.segmentIndex(identifiedBy: UIAction.Identifier("seg-Two"))) action \(segments.actionForSegment(at: 2)?.title ?? "-") width \(segments.widthForSegment(at: 0))")
        // a stepper with chevron images
        let stepper = UIStepper(frame: CGRect(x: 20, y: 310, width: 94, height: 32))
        stepper.setIncrementImage(UIImage(systemName: "chevron.up"), for: .normal)
        stepper.setDecrementImage(UIImage(systemName: "chevron.down"), for: .normal)
        stepper.addAction(UIAction { a in log("stepper \(Int((a.sender as! UIStepper).value))") }, for: .valueChanged)
        stepper.accessibilityIdentifier = "stepper"
        view.addSubview(stepper)
        // switch style: iOS always slides
        let sw = UISwitch(frame: CGRect(x: 140, y: 310, width: 51, height: 31)); sw.preferredStyle = .checkbox
        view.addSubview(sw)
        log("switch style sliding \(sw.style == .sliding) preferred checkbox \(sw.preferredStyle == .checkbox)")
        // a progress view following a Progress
        progressView.frame = CGRect(x: 20, y: 360, width: 300, height: 4); progressView.observedProgress = progress
        view.addSubview(progressView)
        progress.completedUnitCount = 4
        log("observed progress \(progressView.progress)")
        // page controls: a timer that advances the pages, scrubbing, indicator images, a prominent background
        pager.numberOfPages = 4; pager.frame = CGRect(x: 20, y: 390, width: 300, height: 26); pager.accessibilityIdentifier = "pager"
        pager.backgroundStyle = .prominent
        pager.addAction(UIAction { [unowned self] _ in log("pager page \(pager.currentPage)") }, for: .valueChanged)
        view.addSubview(pager)
        scrubber.numberOfPages = 6; scrubber.frame = CGRect(x: 20, y: 440, width: 300, height: 26); scrubber.accessibilityIdentifier = "scrubber"
        scrubber.preferredIndicatorImage = UIImage(systemName: "star.fill")
        scrubber.setIndicatorImage(UIImage(systemName: "heart.fill"), forPage: 0)
        scrubber.addAction(UIAction { [unowned self] _ in log("scrubber page \(scrubber.currentPage) state \(scrubber.interactionState.rawValue)") }, for: .valueChanged)
        view.addSubview(scrubber)
        log("indicator image heart \(scrubber.indicatorImage(forPage: 0) != nil) continuous \(scrubber.allowsContinuousInteraction)")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 16.0, *), pager.progress == nil {
            let timer = UIPageControlTimerProgress(preferredDuration: 0.4)
            timer.resetsToInitialPageAfterEnd = false
            timer.delegate = self
            pager.progress = timer
            timer.resumeTimer()
        }
        progress.completedUnitCount = 7
        DispatchQueue.main.async { log("observed progress later \(self.progressView.progress)") }
    }
    func pageControlTimerProgressDidChange(_ progress: UIPageControlTimerProgress) { log("timer running \(progress.isRunning)") }
    func pageControlTimerProgress(_ progress: UIPageControlTimerProgress, shouldAdvanceToPage page: Int) -> Bool { log("advance to \(page)"); return true }
    @objc func plusTapped() {
        log("system button")
        if #available(iOS 17.4, *) { log("primary action available") }
    }
}

// MARK: - Calendar and scrolling
final class InsetWatchingScrollView: UIScrollView {
    override func adjustedContentInsetDidChange() { super.adjustedContentInsetDidChange(); log("adjusted inset changed") }
}
final class CalendarViewController: UIViewController, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate,
                                    UICalendarSelectionMultiDateDelegate, UIScrollViewDelegate {
    let scroller = InsetWatchingScrollView()
    let calendar = UICalendarView()
    let modes = UISegmentedControl(items: ["Single", "Multi", "Week"])
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        scroller.frame = view.bounds; scroller.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroller.contentSize = CGSize(width: view.bounds.width, height: 2400)
        scroller.delegate = self; scroller.indicatorStyle = .black; scroller.isDirectionalLockEnabled = true
        scroller.accessibilityIdentifier = "scroller"
        view.addSubview(scroller)
        modes.frame = CGRect(x: 20, y: 10, width: view.bounds.width - 40, height: 32); modes.selectedSegmentIndex = 0
        modes.addAction(UIAction { [unowned self] _ in setMode(modes.selectedSegmentIndex) }, for: .valueChanged)
        modes.accessibilityIdentifier = "modes"
        scroller.addSubview(modes)
        // March 2026, days 10 to 25 available; decorations on the 5th (dot), 12th (image) and 20th (custom view)
        let cal = Calendar(identifier: .gregorian)
        calendar.calendar = cal
        calendar.visibleDateComponents = DateComponents(year: 2026, month: 3)
        calendar.availableDateRange = DateInterval(start: cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
                                                   end: cal.date(from: DateComponents(year: 2026, month: 4, day: 30))!)
        calendar.delegate = self; calendar.wantsDateDecorations = true
        calendar.frame = CGRect(x: 0, y: 50, width: view.bounds.width, height: calendar.intrinsicContentSize.height)
        calendar.accessibilityIdentifier = "calendar"
        scroller.addSubview(calendar)
        setMode(0)
        for y in stride(from: 600, to: 2400, by: 120) {           // rows to scroll past
            let l = UILabel(frame: CGRect(x: 20, y: CGFloat(y), width: 300, height: 40)); l.text = "Row \(y / 120)"; scroller.addSubview(l)
        }
        log("visible \(calendar.visibleDateComponents.year ?? 0)-\(calendar.visibleDateComponents.month ?? 0) range \(Int(calendar.availableDateRange.duration / 86400))")
        log("content touches cancel button \(scroller.touchesShouldCancel(in: UIButton())) view \(scroller.touchesShouldCancel(in: UIView()))")
        if #available(iOS 17.4, *) {
            scroller.bouncesHorizontally = false
            log("bounces horizontally \(scroller.bouncesHorizontally) vertically \(scroller.bouncesVertically)")
        }
    }
    func setMode(_ m: Int) {
        switch m {
        case 1: let s = UICalendarSelectionMultiDate(delegate: self); s.selectedDates = [DateComponents(year: 2026, month: 3, day: 11)]; calendar.selectionBehavior = s
        case 2:
            if #available(iOS 18.0, *) { calendar.selectionBehavior = UICalendarSelectionWeekOfYear(delegate: WeekDelegate.shared) }
            else { log("week selection unavailable") }
        default: calendar.selectionBehavior = UICalendarSelectionSingleDate(delegate: self)
        }
        log("mode \(m)")
    }
    func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
        switch dateComponents.day {
        case 5: return .default(color: .systemRed, size: .large)
        case 12: return .image(UIImage(systemName: "star.fill"), color: .systemOrange)
        case 20: return .customView { let v = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 4)); v.backgroundColor = .systemGreen; return v }
        default: return nil
        }
    }
    func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previous: DateComponents) {
        log("visible changed from \(previous.month ?? 0) to \(calendarView.visibleDateComponents.month ?? 0)")
    }
    func dateSelection(_ selection: UICalendarSelectionSingleDate, canSelectDate dateComponents: DateComponents?) -> Bool { dateComponents?.day != 13 }
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        log("selected \(dateComponents?.month ?? 0)/\(dateComponents?.day ?? 0)")
    }
    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents) { log("multi selected \(dateComponents.day ?? 0) count \(selection.selectedDates.count)") }
    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents) { log("multi deselected \(dateComponents.day ?? 0) count \(selection.selectedDates.count)") }
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool { log("should scroll to top from \(Int(scrollView.contentOffset.y))"); return true }
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) { log("did scroll to top \(Int(scrollView.contentOffset.y + scrollView.adjustedContentInset.top))") }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        let bottom = scrollView.contentSize.height + scrollView.adjustedContentInset.bottom - scrollView.bounds.height
        log("scrolled by keyboard at bottom \(abs(scrollView.contentOffset.y - bottom) < 1)")
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { log("scrolled down \(scrollView.contentOffset.y > 100)") }
}
@available(iOS 18.0, *)
final class WeekDelegate: NSObject, UICalendarSelectionWeekOfYearDelegate {
    static let shared = WeekDelegate()
    func week(ofYearSelection selection: UICalendarSelectionWeekOfYear, didSelectWeekOfYear weekOfYearComponents: DateComponents?) {
        log("week selected \(weekOfYearComponents?.weekOfYear ?? 0)")
    }
}
