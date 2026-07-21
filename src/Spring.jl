# Spring physics primitive — Harmonica-style damped spring for natural motion
# (smooth scrolling, progress easing, cursor glide).
#
# This is a numerically-stable semi-implicit (symplectic) Euler integrator for a
# damped harmonic oscillator, parameterised the same way as Charm's Harmonica:
# an angular frequency and a damping ratio. Damping ratio < 1 is under-damped
# (overshoots the target and settles), = 1 is critically damped (fastest
# non-overshooting approach), > 1 is over-damped (slow, no overshoot).
#
# Internal, non-exported: reachable as `Wicked.Spring` / `Wicked.spring_update`.
# Promote by exporting from `Wicked.API` and adding ledger rows; the docstrings
# below satisfy the documentation audit.

"""A damped-spring configuration.

Construct with a time step and, optionally, an `angular_frequency` (stiffness,
in radians/second) and `damping_ratio`. Advance a value toward a target with
[`spring_update`](@ref).

```julia
spring = Spring(1 / 60; angular_frequency = 8.0, damping_ratio = 0.6)
position, velocity = 0.0, 0.0
for _ in 1:120
    position, velocity = spring_update(spring, position, velocity, 1.0)
end
```
"""
struct Spring
    delta_time::Float64
    angular_frequency::Float64
    damping_ratio::Float64
end

function Spring(
    delta_time::Real = 1 / 60;
    angular_frequency::Real = 6.0,
    damping_ratio::Real = 1.0,
)
    delta_time > 0 || throw(ArgumentError("spring delta_time must be positive"))
    angular_frequency >= 0 ||
        throw(ArgumentError("spring angular_frequency must be non-negative"))
    damping_ratio >= 0 ||
        throw(ArgumentError("spring damping_ratio must be non-negative"))
    Spring(Float64(delta_time), Float64(angular_frequency), Float64(damping_ratio))
end

"""
    spring_update(spring, position, velocity, target) -> (position, velocity)

Advance `position`/`velocity` one time step toward `target` under `spring`.
Returns the new `(position, velocity)`. Feed the results back in on the next
frame; the value converges to `target` with `velocity` approaching zero.
"""
function spring_update(spring::Spring, position::Real, velocity::Real, target::Real)
    stiffness = spring.angular_frequency^2
    damping = 2 * spring.damping_ratio * spring.angular_frequency
    acceleration = -stiffness * (Float64(position) - Float64(target)) -
                   damping * Float64(velocity)
    new_velocity = Float64(velocity) + acceleration * spring.delta_time
    new_position = Float64(position) + new_velocity * spring.delta_time
    return (new_position, new_velocity)
end
