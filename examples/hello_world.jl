# Hello, World — the smallest possible Wicked program.
#
# Wicked renders into a `Buffer` (a grid of styled cells). You can print that
# buffer to any terminal — or, as here, inspect it as plain text. No terminal is
# required, which is exactly what makes Wicked easy to test.
#
# Run it with:  julia --project=. examples/hello_world.jl

using Wicked.API

# 1. Make a buffer: 3 rows tall, 34 columns wide.
buffer = Buffer(3, 34)

# 2. Render a bordered panel containing a paragraph into the whole buffer.
render!(
    Frame(buffer),
    Panel(Paragraph("Hello, Wicked!"); block=Block(title="hello")),
    buffer.area,
)

# 3. Look at the result. `plain_snapshot` strips styling and returns the text.
println(plain_snapshot(buffer))

# In a real app you would present the buffer to a terminal backend and loop on
# input events — see runtime_quickstart.jl and weather_app.jl.

@assert occursin("Hello, Wicked!", plain_snapshot(buffer))
println("\nhello world example completed")
