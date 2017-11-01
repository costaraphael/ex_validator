# ExValidator

[![Hex.pm](https://img.shields.io/hexpm/v/ex_validator.svg?style=flat-square)](https://hex.pm/packages/ex_validator)
[![Hex.pm](https://img.shields.io/hexpm/dt/ex_validator.svg?style=flat-square)](https://hex.pm/packages/ex_validator)

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

The package can be installed by adding `ex_validator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_validator, "~> 0.1.0"}
  ]
end
```

## Documentation

Online documentation is available [here](https://hexdocs.pm/ex_validator).

## Licence

The ExValidator source code is lecensed under the [MIT License](https://github.com/ex_validator/ecto/blob/master/LICENSE)
