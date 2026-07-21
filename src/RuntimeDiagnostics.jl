module RuntimeDiagnostics

import ..Runtime: WickedApp, initialize, update!, app_view, subscriptions
using ..Diagnostics: DiagnosticsHub,
                     begin_frame!,
                     end_frame!,
                     record_input!,
                     record_command!,
                     trace!,
                     with_trace_span

export InstrumentedApp,
       instrumented,
       diagnostics,
       instrument_frame!,
       instrument_event!,
       instrument_command!,
       instrument_render!,
       instrument_reconcile!,
       instrument_layout!

"""
Transparent `WickedApp` proxy that traces application lifecycle hooks.

The proxy preserves the wrapped application's model, message, command, view, and
subscription values. It therefore works with immediate-mode applications and
Toolkit applications without introducing diagnostics-specific domain types.
"""
struct InstrumentedApp{A,H<:DiagnosticsHub} <: WickedApp
    application::A
    hub::H
end

InstrumentedApp(application; hub::DiagnosticsHub=DiagnosticsHub()) =
    InstrumentedApp{typeof(application),typeof(hub)}(application, hub)

instrumented(application; hub::DiagnosticsHub=DiagnosticsHub()) =
    InstrumentedApp(application; hub=hub)

diagnostics(application::InstrumentedApp) = application.hub

function _lifecycle(
    operation::F,
    application::InstrumentedApp,
    name::Symbol;
    metadata=nothing,
) where {F}
    return with_trace_span(
        operation,
        application.hub.traces,
        :application,
        name;
        metadata=metadata,
    )
end

function initialize(application::InstrumentedApp, arguments...; keywords...)
    return _lifecycle(application, :initialize) do
        initialize(application.application, arguments...; keywords...)
    end
end

function update!(application::InstrumentedApp, arguments...; keywords...)
    message = isempty(arguments) ? nothing : last(arguments)
    application.hub.enabled && trace!(
        application.hub.traces,
        :application,
        :message;
        metadata=(message=repr(message),),
    )
    return _lifecycle(application, :update; metadata=(message=repr(message),)) do
        update!(application.application, arguments...; keywords...)
    end
end

function app_view(application::InstrumentedApp, arguments...; keywords...)
    return _lifecycle(application, :view) do
        app_view(application.application, arguments...; keywords...)
    end
end

function subscriptions(application::InstrumentedApp, arguments...; keywords...)
    return _lifecycle(application, :subscriptions) do
        subscriptions(application.application, arguments...; keywords...)
    end
end

_resolve_count(value::Integer, _) = Int(value)
_resolve_count(value::Function, result) = Int(value(result))

"""
Execute a complete render/diff/write operation and record its frame metrics.

`diff_cells` and `drawn_cells` may be integers or functions of the operation's
result. This keeps the instrumentation independent of a particular backend
result type while retaining accurate cell counts.
"""
function instrument_frame!(
    operation::F,
    hub::DiagnosticsHub;
    diff_cells::Union{Integer,Function}=0,
    drawn_cells::Union{Integer,Function}=0,
) where {F}
    started = begin_frame!(hub)
    try
        result = operation()
        end_frame!(
            hub,
            started;
            diff_cells=_resolve_count(diff_cells, result),
            drawn_cells=_resolve_count(drawn_cells, result),
        )
        return result
    catch error
        duration = time_ns() - started
        trace!(
            hub.traces,
            :render,
            :frame;
            phase=:error,
            metadata=(duration_ns=duration, error=repr(error)),
        )
        rethrow()
    end
end

"""Record and trace one event-dispatch boundary."""
function instrument_event!(operation::F, hub::DiagnosticsHub, event) where {F}
    record_input!(hub, event)
    return with_trace_span(
        operation,
        hub.traces,
        :runtime,
        :dispatch;
        metadata=(; event),
    )
end

"""Record and trace one command-execution boundary."""
function instrument_command!(operation::F, hub::DiagnosticsHub, command) where {F}
    record_command!(hub, command)
    return with_trace_span(
        operation,
        hub.traces,
        :runtime,
        :command_execution;
        metadata=(; command),
    )
end

function _instrument_phase(
    operation::F,
    hub::DiagnosticsHub,
    phase::Symbol;
    metadata=nothing,
) where {F}
    return with_trace_span(operation, hub.traces, :render, phase; metadata=metadata)
end

instrument_render!(operation::F, hub::DiagnosticsHub; metadata=nothing) where {F} =
    _instrument_phase(operation, hub, :render; metadata=metadata)

instrument_reconcile!(operation::F, hub::DiagnosticsHub; metadata=nothing) where {F} =
    _instrument_phase(operation, hub, :reconcile; metadata=metadata)

instrument_layout!(operation::F, hub::DiagnosticsHub; metadata=nothing) where {F} =
    _instrument_phase(operation, hub, :layout; metadata=metadata)

end
