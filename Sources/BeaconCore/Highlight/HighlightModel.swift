import CoreGraphics
import Foundation

/// Everything the renderer needs for one frame, in global screen coordinates. Pure data.
public struct HighlightFrame: Equatable, Sendable {
    public var time: TimeInterval
    public var style: HighlightStyle
    /// Whether the style's layers are on screen at all.
    public var isShown: Bool
    /// Visible amount 0...1 (entrance and exit).
    public var level: CGFloat
    /// Drawn center of the highlight. Equals the pointer exactly once the follower has settled.
    public var center: CGPoint
    public var velocity: CGVector
    public var isSettled: Bool
    /// Uniform scale of the body: entrance pop, breathing and press shrink combined.
    public var bodyScale: CGFloat
    /// Body opacity multiplier from breathing (1 when not breathing).
    public var breathAlpha: CGFloat
    public var stretch: VelocityStretch
    public var pulse: RingState?
    public var sonarRings: [RingState]
    /// Sonar dot visibility 0...1.
    public var dotLevel: CGFloat
    /// Lens radius multiplier (entrance closes in from 2.2, press shrinks to 0.8).
    public var lensScale: CGFloat
    /// Lens dim strength 0...1 of the recipe's dim.
    public var dimLevel: CGFloat
    public var trail: [TrailPoint]
    public var ripples: [RingState]
    public var press: RingState?

    static func hidden(time: TimeInterval, style: HighlightStyle, at point: CGPoint) -> HighlightFrame {
        HighlightFrame(
            time: time, style: style, isShown: false, level: 0, center: point, velocity: .zero, isSettled: true,
            bodyScale: 1, breathAlpha: 1, stretch: .identity, pulse: nil, sonarRings: [], dotLevel: 0, lensScale: 1,
            dimLevel: 0, trail: [], ripples: [], press: nil
        )
    }
}

/// The highlight's whole behavior as a value: toggle, follower, trail, breathing, press and click ripples. Stepped
/// from a display-synchronized clock with the latest pointer position; the controller only maps frames to layers.
public struct HighlightModel: Equatable, Sendable {
    struct Ripple: Equatable, Sendable {
        var start: TimeInterval
        var center: CGPoint
        var startRadius: CGFloat
        var button: MouseButton
    }

    struct Press: Equatable, Sendable {
        var start: TimeInterval
        var button: MouseButton
    }

    /// A gap longer than this between steps (the clock was paused) restarts stepping instead of integrating it.
    static let restartGap: TimeInterval = 0.25
    /// Breathing starts this long after the follower comes to rest.
    static let breathDelay: TimeInterval = 0.25

    public private(set) var style: HighlightStyle
    public private(set) var recipe: StyleRecipe
    public var ripplesEnabled: Bool {
        didSet { if !ripplesEnabled { press = nil } }
    }
    public private(set) var toggle: HighlightToggle
    public private(set) var follower: SpringFollower
    public private(set) var trail: TrailBuffer
    private(set) var ripples: [Ripple] = []
    private var press: Press?
    private var pressSpring: ScalarSpring
    private var lastTime: TimeInterval?
    private var restSince: TimeInterval?
    /// Start of the current breathing run; kept while moving so the breath fades out by weight, never jumps.
    private var breathStart: TimeInterval?
    private var breathWeight: Double = 0
    private var pointer: CGPoint

    public init(style: HighlightStyle, ripplesEnabled: Bool = true, pointer: CGPoint = .zero) {
        self.style = style
        self.recipe = style.recipe
        self.ripplesEnabled = ripplesEnabled
        self.pointer = pointer
        toggle = HighlightToggle(appearDuration: style.recipe.appearDuration, disappearDuration: style.recipe.disappearDuration)
        follower = SpringFollower(parameters: style.recipe.spring, position: pointer)
        trail = TrailBuffer(recipe: style.recipe.comet)
        pressSpring = ScalarSpring(value: 1, omega: 4 / style.recipe.lens.pressDuration)
    }

    public var isOn: Bool { toggle.isOn }

    // MARK: Input

    public mutating func setStyle(_ newStyle: HighlightStyle, at time: TimeInterval) {
        guard newStyle != style else { return }
        style = newStyle
        recipe = newStyle.recipe
        toggle.appearDuration = recipe.appearDuration
        toggle.disappearDuration = recipe.disappearDuration
        follower.parameters = recipe.spring
        follower.reset(to: pointer)
        trail = TrailBuffer(recipe: recipe.comet)
        pressSpring = ScalarSpring(value: 1, omega: 4 / pressDuration)
        restSince = nil
        breathStart = nil
        breathWeight = 0
        toggle.replayEntrance(at: time)
    }

    public mutating func toggleHighlight(at time: TimeInterval, pointer: CGPoint) {
        setHighlight(!toggle.isOn, at: time, pointer: pointer)
    }

    public mutating func setHighlight(_ on: Bool, at time: TimeInterval, pointer: CGPoint) {
        guard on != toggle.isOn else { return }
        self.pointer = pointer
        if on {
            // Appear exactly on the pointer: never fly in from where it was last time.
            if !toggle.isVisible {
                follower.reset(to: pointer)
                trail.reset()
            }
            restSince = nil
            breathStart = nil
            breathWeight = 0
            toggle.turnOn(at: time)
        } else {
            toggle.turnOff(at: time)
        }
    }

    public mutating func mouseDown(_ button: MouseButton, at time: TimeInterval) {
        if ripplesEnabled { press = Press(start: time, button: button) }
        pressSpring.target = Double(pressTarget)
    }

    public mutating func mouseUp(_ button: MouseButton, at point: CGPoint, time: TimeInterval) {
        pressSpring.target = 1
        guard ripplesEnabled else {
            press = nil
            return
        }
        let curve = RippleCurve(recipe: recipe.ripple)
        let startRadius = press.map { curve.press(elapsed: time - $0.start, center: point, button: button).radius }
        press = nil
        ripples.append(Ripple(start: time, center: point, startRadius: startRadius ?? recipe.ripple.startRadius, button: button))
        if ripples.count > recipe.ripple.maxConcurrent {
            ripples.removeFirst(ripples.count - recipe.ripple.maxConcurrent)
        }
    }

    // MARK: Stepping

    /// True while anything still moves; the controller pauses its display link otherwise.
    public var needsFrames: Bool {
        if toggle.isAnimating || !ripples.isEmpty || press != nil || !pressSpring.isSettled { return true }
        guard toggle.isOn else { return false }
        if !follower.isSettled || !trail.isEmpty { return true }
        if let start = toggle.appearStart, let pulse = recipe.pulse, lastTime.map({ $0 - start < pulse.duration }) ?? true {
            return true
        }
        if style == .aura, let breathStart {
            let breathEnd = breathStart + recipe.aura.breathPeriod * recipe.aura.breathCycles
            return (lastTime ?? 0) < breathEnd
        }
        return false
    }

    /// Advances to `time` with the latest pointer position and returns what to draw.
    public mutating func step(pointer: CGPoint, time: TimeInterval) -> HighlightFrame {
        self.pointer = pointer
        var dt: TimeInterval = 0
        if let lastTime {
            if time < lastTime { return frame(at: lastTime) }
            dt = time - lastTime
            if dt > Self.restartGap { dt = 0 }
        }
        lastTime = time
        toggle.advance(to: time)

        follower.target = pointer
        follower.step(dt: dt)
        pressSpring.step(dt: dt)
        ripples.removeAll { time - $0.start >= recipe.ripple.duration }

        if follower.isSettled {
            if restSince == nil {
                restSince = time
                // Continue a breath that was only briefly interrupted; otherwise start a new run from zero.
                if breathStart == nil || breathWeight < 0.05 { breathStart = time + Self.breathDelay }
            }
        } else {
            restSince = nil
        }
        let resting = restSince.map { time - $0 >= Self.breathDelay } ?? false
        let tau = resting ? 0.3 : 0.08
        let targetWeight: Double = resting && style == .aura && toggle.isOn ? 1 : 0
        breathWeight += (targetWeight - breathWeight) * (1 - exp(-dt / tau))
        if breathWeight < 0.001 && targetWeight == 0 { breathWeight = 0 }

        if style == .comet && toggle.isVisible {
            trail.append(follower.position, at: time, speed: follower.speed)
        } else if !trail.isEmpty || trail.head != nil {
            trail.reset()
        }
        return frame(at: time)
    }

    private var pressDuration: TimeInterval {
        style == .keyline ? recipe.keyline.pressDuration : recipe.lens.pressDuration
    }

    private var pressTarget: CGFloat {
        switch style {
        case .lens: recipe.lens.pressScale
        case .keyline: recipe.keyline.pressScale
        case .aura, .comet, .sonar: 1
        }
    }

    private func frame(at time: TimeInterval) -> HighlightFrame {
        var frame = HighlightFrame.hidden(time: time, style: style, at: follower.position)
        let curve = RippleCurve(recipe: recipe.ripple)
        frame.ripples = ripples.map { ripple in
            curve.ring(
                at: (time - ripple.start) / recipe.ripple.duration, center: ripple.center,
                from: ripple.startRadius, button: ripple.button
            )
        }
        frame.press = press.map { curve.press(elapsed: time - $0.start, center: pointer, button: $0.button) }
        guard toggle.isVisible else { return frame }

        let level = CGFloat(toggle.level(at: time))
        let progress = toggle.progress(at: time)
        let appearElapsed = toggle.appearStart.map { time - $0 }
        let leaving: Double? = {
            if case .disappearing = toggle.phase { return Easing.easeIn(progress) }
            return nil
        }()

        frame.isShown = true
        frame.level = level
        frame.velocity = follower.velocity
        frame.isSettled = follower.isSettled
        frame.center = follower.position
        if let pulse = recipe.pulse, let elapsed = appearElapsed {
            frame.pulse = SummonPulse.ring(pulse, elapsed: elapsed, center: follower.position)
        }

        let press = CGFloat(pressSpring.value)
        switch style {
        case .aura:
            let aura = recipe.aura
            frame.stretch = VelocityStretch.of(
                velocity: follower.velocity, stretch: aura.stretch, squash: aura.squash, fullSpeed: aura.stretchSpeed
            )
            let breath = breathOffset(at: time) * breathWeight
            let entrance = appearElapsed.map { CGFloat(Easing.pop($0, from: Double(aura.bloomFrom))) } ?? 1
            let exit = leaving.map { 1 - 0.08 * CGFloat($0) } ?? 1
            frame.bodyScale = entrance * exit * (1 + (aura.breathScale - 1) * CGFloat(breath))
            frame.breathAlpha = 1 + aura.breathAlpha * CGFloat(breath)
        case .lens:
            let lens = recipe.lens
            let entrance = appearElapsed.map { lens.entranceScale - (lens.entranceScale - 1) * CGFloat(Easing.outExpo($0 / recipe.appearDuration)) } ?? 1
            let exit = leaving.map { 1 + 0.3 * CGFloat($0) } ?? 1
            frame.lensScale = entrance * exit * press
            frame.dimLevel = level
        case .comet:
            let entrance = appearElapsed.map { CGFloat(Easing.pop($0, from: 0.3, omega: 22)) } ?? 1
            let exit = leaving.map { 1 - 0.3 * CGFloat($0) } ?? 1
            frame.bodyScale = entrance * exit
            frame.trail = CatmullRom.smooth(trail.tapered())
        case .keyline:
            let keyline = recipe.keyline
            frame.center = PredictiveLead.drawn(
                follower: follower.position, velocity: follower.velocity, pointer: pointer,
                lead: keyline.predictionLead, clamp: keyline.predictionClamp
            )
            let entrance = appearElapsed.map { keyline.appearFrom - (keyline.appearFrom - 1) * CGFloat(Easing.outExpo($0 / recipe.appearDuration)) } ?? 1
            let exit = leaving.map { 1 + 0.15 * CGFloat($0) } ?? 1
            frame.bodyScale = entrance * exit * press
        case .sonar:
            let sonar = recipe.sonar
            if let elapsed = appearElapsed {
                frame.sonarRings = SummonPulse.sonarRings(sonar, elapsed: elapsed, center: follower.position)
                let dot = (elapsed - sonar.dotDelay) / sonar.dotAppear
                frame.dotLevel = CGFloat(Easing.outExpo(dot))
                frame.bodyScale = elapsed > sonar.dotDelay ? CGFloat(Easing.pop(elapsed - sonar.dotDelay, from: 0.4)) : 0.4
            } else {
                frame.dotLevel = level
                frame.bodyScale = 1 - 0.2 * CGFloat(leaving ?? 0)
            }
        }
        return frame
    }

    /// 0...1 breathing offset: starts and ends at 0 smoothly and stops after the recipe's cycle count.
    private func breathOffset(at time: TimeInterval) -> Double {
        guard let breathStart else { return 0 }
        let aura = recipe.aura
        let phase = (time - breathStart) / aura.breathPeriod
        guard phase > 0, phase < aura.breathCycles else { return 0 }
        return 0.5 - 0.5 * cos(2 * .pi * phase)
    }
}
