# ExValidator

Helpers for validating and normalizing Elixir data structures.

The validation works as simple composable functions, allowing simple validations...

  ```elixir
  iex> validator = integer(max: 2)
  iex> validator.(2)
  {:ok, 2}
  iex> validator.(4)
  {:error, "greater than 2"}
  ```

...data casting...

  ```elixir
  iex> validator = map_of(%{name: string(required: true), age: integer(min: 1)})
  iex> validator.(%{"name" => "Jhon", "age": "26"})
  {:ok, %{name: "Jhon", age: 26}}
  iex> validator.(%{"age": "a"})
  {:error, %{name: "is blank", age: "not a number"}}
  ```

...and more complex use cases:

  ```elixir
  iex> address = map_of(%{
  ...>   city: string(required: true),
  ...>   state: string(required: true, min: 2, max: 2)
  ...> })
  iex> person = map_of(%{
  ...>   name: string(required: true),
  ...>   age: integer(min: 1),
  ...>   addresses: list_of(address)
  ...> })
  iex> validator = list_of(person)
  iex> data = [
  ...>   %{
  ...>     "name" => "Jhon",
  ...>     "age" => "aa",
  ...>     "addresses" => [
  ...>       %{"city" => "New York", "state" => "NY"},
  ...>       %{"city" => "Los Angeles", "state" => "LA"},
  ...>     ]
  ...>   },
  ...>   %{
  ...>     "name" => "Alex",
  ...>     "addresses" => [
  ...>       %{"city" => "Chicago", "states" => "IL"},
  ...>       %{"city" => "San Francisco", "state" => "CA"},
  ...>     ]
  ...>   }
  ...> ]
  iex> validator.(data)
  {:error, %{
    0 => %{age: "not a number"},
    1 => %{addresses: %{0 => %{state: "is blank"}}}
  }}
  ```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `validator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:validator, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/validator](https://hexdocs.pm/validator).
