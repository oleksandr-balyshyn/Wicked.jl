module Forms

using ..Core
using ..Runtime
import ..Core: render!

@enum ValidationStatus::UInt8 begin
    Unvalidated
    Validating
    ValidField
    InvalidField
end

"""One machine-readable validation problem."""
struct ValidationIssue
    code::Symbol
    message::String
    severity::Symbol

    function ValidationIssue(
        code::Symbol,
        message::AbstractString;
        severity::Symbol=:error,
    )
        severity in (:info, :warning, :error) ||
            throw(ArgumentError("validation severity must be info, warning, or error"))
        new(code, String(message), severity)
    end
end

"""A synchronous or asynchronous field validator."""
struct Validator{F}
    check::F
    asynchronous::Bool
    code::Symbol
    message::String
end

function Validator(
    check::F;
    asynchronous::Bool=false,
    code::Symbol=:invalid,
    message::AbstractString="Invalid value",
) where {F}
    Validator{F}(check, asynchronous, code, String(message))
end

required_validator(; message::AbstractString="This field is required") = Validator(
    value -> !(isnothing(value) || (value isa AbstractString && isempty(strip(value))));
    code=:required,
    message,
)

"""Declarative metadata and validators for one form field."""
struct FormField
    id::Any
    label::String
    initial::Any
    validators::Vector{Validator}
end

function FormField(
    id;
    label::AbstractString=string(id),
    initial=nothing,
    validators=Validator[],
)
    FormField(id, String(label), initial, Validator[validators...])
end

"""A form schema with stable field IDs."""
struct Form
    fields::Vector{FormField}

    function Form(fields)
        resolved = FormField[fields...]
        ids = Set{Any}()
        for field in resolved
            field.id in ids && throw(ArgumentError("duplicate form field ID: $(field.id)"))
            push!(ids, field.id)
        end
        new(resolved)
    end
end

mutable struct FieldState
    value::Any
    initial::Any
    status::ValidationStatus
    issues::Vector{ValidationIssue}
    touched::Bool
    dirty::Bool
    generation::UInt64
end

FieldState(value) = FieldState(value, value, Unvalidated, ValidationIssue[], false, false, 0)

"""Mutable values and validation results for a form schema."""
mutable struct FormState
    fields::Dict{Any,FieldState}
    submitting::Bool
    submit_count::UInt64
end

function FormState(form::Form)
    FormState(
        Dict{Any,FieldState}(field.id => FieldState(field.initial) for field in form.fields),
        false,
        0,
    )
end

function _field(form::Form, id)
    index = findfirst(field -> field.id == id, form.fields)
    isnothing(index) && throw(KeyError(id))
    form.fields[index]
end

field_state(state::FormState, id) = get(state.fields, id) do
    throw(KeyError(id))
end

field_value(state::FormState, id) = field_state(state, id).value

"""Set a field value and invalidate any older asynchronous result."""
function set_field!(state::FormState, id, value; touched::Bool=true)
    field = field_state(state, id)
    field.value = value
    field.touched |= touched
    field.dirty = !isequal(field.value, field.initial)
    field.status = Unvalidated
    empty!(field.issues)
    field.generation += 1
    state
end

function reset_field!(state::FormState, id)
    field = field_state(state, id)
    field.value = field.initial
    field.status = Unvalidated
    empty!(field.issues)
    field.touched = false
    field.dirty = false
    field.generation += 1
    state
end

function reset_form!(form::Form, state::FormState)
    for field in form.fields
        reset_field!(state, field.id)
    end
    state.submitting = false
    state
end

function _validation_issues(result, validator::Validator)
    if isnothing(result) || result === true
        ValidationIssue[]
    elseif result === false
        ValidationIssue[ValidationIssue(validator.code, validator.message)]
    elseif result isa ValidationIssue
        ValidationIssue[result]
    elseif result isa AbstractString
        ValidationIssue[ValidationIssue(validator.code, result)]
    elseif result isa AbstractVector{<:ValidationIssue}
        ValidationIssue[result...]
    else
        throw(ArgumentError("validator must return nothing, Bool, String, ValidationIssue, or a vector of issues"))
    end
end

struct ValidationCompleted
    field_id::Any
    generation::UInt64
    issues::Vector{ValidationIssue}
end

"""Validate one field and return a command for pending asynchronous checks."""
function validate_field!(form::Form, state::FormState, id)
    specification = _field(form, id)
    field = field_state(state, id)
    field.touched = true
    synchronous = ValidationIssue[]
    asynchronous = Validator[]
    for validator in specification.validators
        if validator.asynchronous
            push!(asynchronous, validator)
        else
            append!(synchronous, _validation_issues(validator.check(field.value), validator))
        end
    end
    field.issues = synchronous
    if !isempty(synchronous)
        field.status = InvalidField
        return NoCommand()
    elseif isempty(asynchronous)
        field.status = ValidField
        return NoCommand()
    end
    field.status = Validating
    generation = field.generation
    value = field.value
    TaskCommand(
        () -> begin
            issues = ValidationIssue[]
            for validator in asynchronous
                append!(issues, _validation_issues(validator.check(value), validator))
            end
            ValidationCompleted(id, generation, issues)
        end;
        id=(:validation, id),
        on_success=identity,
        replace=true,
    )
end

"""Apply an asynchronous result only when its field generation is current."""
function apply_validation!(state::FormState, completed::ValidationCompleted)
    field = field_state(state, completed.field_id)
    field.generation == completed.generation || return false
    field.issues = completed.issues
    field.status = isempty(completed.issues) ? ValidField : InvalidField
    true
end

function apply_validation!(state::FormState, completed::CommandFinished)
    completed.value isa ValidationCompleted || return false
    apply_validation!(state, completed.value)
end

"""Validate every field and return a batch of asynchronous checks."""
function validate_form!(form::Form, state::FormState)
    commands = AbstractCommand[]
    for field in form.fields
        command = validate_field!(form, state, field.id)
        command isa NoCommand || push!(commands, command)
    end
    isempty(commands) ? NoCommand() : BatchCommand(commands)
end

form_valid(form::Form, state::FormState) = all(
    field -> field_state(state, field.id).status == ValidField,
    form.fields,
)

form_pending(form::Form, state::FormState) = any(
    field -> field_state(state, field.id).status == Validating,
    form.fields,
)

form_dirty(form::Form, state::FormState) = any(
    field -> field_state(state, field.id).dirty,
    form.fields,
)

form_values(form::Form, state::FormState) =
    Dict(field.id => field_state(state, field.id).value for field in form.fields)

form_issues(form::Form, state::FormState) = [
    (field.id, issue)
    for field in form.fields
    for issue in field_state(state, field.id).issues
]

"""Inline validation issues rendered as styled text."""
struct ValidationMessage
    issues::Vector{ValidationIssue}
    error_style::Style
    warning_style::Style
    info_style::Style
    symbol::String
end

function ValidationMessage(
    issues::AbstractVector{ValidationIssue};
    error_style::Style=Style(foreground=AnsiColor(1)),
    warning_style::Style=Style(foreground=AnsiColor(3)),
    info_style::Style=Style(foreground=AnsiColor(4)),
    symbol::AbstractString="! ",
)
    ValidationMessage(
        collect(issues),
        error_style,
        warning_style,
        info_style,
        String(symbol),
    )
end

function render!(buffer::Buffer, widget::ValidationMessage, area::Rect)
    active = intersection(buffer.area, area)
    for (offset, issue) in enumerate(widget.issues)
        offset > active.height && break
        style = issue.severity == :error ? widget.error_style :
                issue.severity == :warning ? widget.warning_style : widget.info_style
        draw_text!(
            buffer,
            active.row + offset - 1,
            active.column,
            widget.symbol * issue.message;
            style,
            clip=active,
        )
    end
    buffer
end

"""All current form issues rendered with field labels."""
struct ValidationSummary
    form::Form
    state::FormState
    style::Style
end

ValidationSummary(form::Form, state::FormState; style::Style=Style(foreground=AnsiColor(1))) =
    ValidationSummary(form, state, style)

function render!(buffer::Buffer, widget::ValidationSummary, area::Rect)
    active = intersection(buffer.area, area)
    issues = form_issues(widget.form, widget.state)
    for (offset, (id, issue)) in enumerate(issues)
        offset > active.height && break
        label = _field(widget.form, id).label
        draw_text!(
            buffer,
            active.row + offset - 1,
            active.column,
            label * ": " * issue.message;
            style=widget.style,
            clip=active,
        )
    end
    buffer
end

export FieldState,
       Form,
       FormField,
       FormState,
       InvalidField,
       Unvalidated,
       ValidField,
       Validating,
       ValidationCompleted,
       ValidationIssue,
       ValidationMessage,
       ValidationStatus,
       ValidationSummary,
       Validator,
       apply_validation!,
       field_state,
       field_value,
       form_dirty,
       form_issues,
       form_pending,
       form_valid,
       form_values,
       required_validator,
       reset_field!,
       reset_form!,
       set_field!,
       validate_field!,
       validate_form!

end
