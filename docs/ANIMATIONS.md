# Animations

Wicked animations are part of `Wicked.API` and are driven by the application runtime. They do not create tasks
or sleep independently. This keeps terminal rendering deterministic: call
`tick_animations!` once per frame or timer event, apply returned values, and render
only when updates are produced.

## Animate a value

```julia
manager = AnimationManager()
opacity = Ref(0.0)

handle = animate!(
    manager,
    AnimationSpec(
        AnimationTrack(0.0, 1.0; easing=ease_in_out_cubic);
        duration=0.25,
        key=:panel_opacity,
    );
    on_update=value -> (opacity[] = value),
)

updates = tick_animations!(manager)
isempty(updates) || request_render!()
```

A non-`nothing` key identifies a replaceable animation channel. Starting another
animation with the same key removes the previous entry and calls its finish handler
with `AnimationReplaced`. Replacement uses a copied-state commit, so allocation or
construction failure leaves the previous animation registered.

## Keyframes and interpolation

```julia
track = AnimationTrack([
    Keyframe(0.0, 0; easing=ease_out_quad),
    Keyframe(0.7, 12; easing=ease_out_back),
    Keyframe(1.0, 10),
])
```

Keyframe offsets must start at zero, end at one, and increase strictly. Wicked
interpolates numbers, tuples, and vectors. Other value types use discrete
interpolation by default. Extend `interpolate_value` or pass an `interpolation`
callable to `AnimationTrack` for colors, geometry, styles, or domain values.

Easing belongs to the segment beginning at a keyframe. Easing functions may
overshoot, which supports effects such as `ease_out_back`; they must return a
finite real value.

## Repetition and direction

```julia
spec = AnimationSpec(
    AnimationTrack(0, 8);
    duration=0.4,
    iterations=4,
    direction=AlternateAnimation,
)
```

Use `iterations=nothing` for an infinite animation. Infinite animations require a
positive duration and continue until cancelled or replaced.

## Lifecycle

```julia
pause_animation!(manager, handle)
resume_animation!(manager, handle)
cancel_animation!(manager, handle)
```

Finish callbacks receive `(handle, reason, last_value)`. Callback and sampling
failures never corrupt scheduler state; they are captured by
`take_animation_errors!`. A sampling failure ends that animation with
`AnimationFailed`.

The scheduler accepts an injected monotonic nanosecond clock, making timelines and
frame updates deterministic in tests.

## Reduced motion

`AnimationManager` supports `FullMotion`, `ReducedMotion`, and `DisabledMotion`.
Reduced motion caps nonessential animation duration and delay while preserving the
logical terminal value. Disabled motion applies the terminal value immediately.
Set `essential=true` only when motion communicates state that has no non-motion
equivalent.

Policy changes affect animations scheduled afterward. Applications that change
policy at runtime should cancel or replace existing nonessential animation keys as
part of the same settings update.

For a runnable public-API example that combines deterministic animations with
spinners, skeletons, and loading indicators, see
[`examples/animations_loading_quickstart.jl`](../examples/animations_loading_quickstart.jl).
