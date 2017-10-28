defmodule Validator do
  @moduledoc """
  Helpers for validating and normalizing Elixir data structures.

  The validation works as simple composable functions, allowing simple validations...

      iex> validator = integer(max: 2)
      iex> validator.(2)
      {:ok, 2}
      iex> validator.(4)
      {:error, "greater than 2"}

  ...data casting...

      iex> validator = map_of(%{name: string(required: true), age: integer(min: 1)})
      iex> validator.(%{"name" => "Jhon", "age": "26"})
      {:ok, %{name: "Jhon", age: 26}}
      iex> validator.(%{"age": "a"})
      {:error, %{name: "is blank", age: "not a number"}}

  ...and more complex use cases:

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

  ## Global options

  These are the global options shared among all validators:

    - `required` - validates if the value is present
  """

  @doc """
  Validates and trims strings. Values that implement the `String.Chars` protocol are converted
  to strings.

  ## Options

    - `max` - validates if the string is smaller than the given size
    - `min` - validates if the string is bigger than the given size
    - `one_of` - validates if the value is contained in the passed list
    - `message` - changes the returned error message

  ## Examples

      iex> string().("some text")
      {:ok, "some text"}
      iex> string().("   some text \\n")
      {:ok, "some text"}
      iex> string().(%{})
      {:error, "not a string"}

      iex> string().("")
      {:ok, nil}
      iex> string(required: true).("")
      {:error, "is blank"}
  """
  def string(opts \\ []) do
    fn value ->
      run_steps(value, opts[:message], [
        &parse_string(&1),
        &trim_string(&1),
        &validate_required(&1, opts[:required]),
        &validate_one_of(&1, opts[:one_of]),
        &validate_min_string(&1, opts[:min]),
        &validate_max_string(&1, opts[:max])
      ])
    end
  end

  @doc """
  Validates and parses integers.

  ## Options

    - `min` - validates if the number is less than the passed option
    - `max` - validates if the number is greater than the passed option
    - `one_of` - validates if the value is contained in the passed list
    - `message` - changes the returned error message

  ## Examples

      iex> integer().(1)
      {:ok, 1}
      iex> integer().("1")
      {:ok, 1}
      iex> integer().("1a")
      {:error, "not a number"}
      iex> integer(message: "what is this?").(:foo)
      {:error, "what is this?"}

      iex> integer().(nil)
      {:ok, nil}
      iex> integer(required: true).(nil)
      {:error, "is blank"}
  """
  def integer(opts \\ []) do
    fn v ->
      run_steps(v, opts[:message], [
        fn v -> parse_number(v, &Integer.parse/1) end,
        &validate_required(&1, opts[:required]),
        &validate_one_of(&1, opts[:one_of]),
        &validate_min_number(&1, opts[:min]),
        &validate_max_number(&1, opts[:max])
      ])
    end
  end

  @doc """
  Validates and parses floats

  ## Options

    - `min` - validates if the number is less than the passed option
    - `max` - validates if the number is greater than the passed option
    - `message` - changes the returned error message

  ## Examples

      iex> float().(1.0)
      {:ok, 1.0}
      iex> float().("1")
      {:ok, 1.0}
      iex> float().("1a")
      {:error, "not a number"}
      iex> float(message: "whaaaat?").(:foo)
      {:error, "whaaaat?"}

      iex> float().(nil)
      {:ok, nil}
      iex> float(required: true).(nil)
      {:error, "is blank"}
  """
  def float(opts \\ []) do
    fn v ->
      run_steps(v, opts[:message], [
        fn v -> parse_number(v, &Float.parse/1) end,
        &validate_required(&1, opts[:required]),
        &validate_min_number(&1, opts[:min]),
        &validate_max_number(&1, opts[:max])
      ])
    end
  end

  @doc """
  Validates lists, while stripping `nil`s.

  Errors are returned as a map containing the index and the respective error.

  ## Options

    - `min` - validates that the list length is equal to or greater than the passed value
    - `max` - validates that the list length is equal to or smaller than the passed value

  ## Examples

      iex> list_of(integer()).([1, 2, 3])
      {:ok, [1, 2, 3]}
      iex> list_of(integer()).("")
      {:error, "not a list"}
      iex> list_of(integer(min: 5, max: 15)).([3, 4, 7, 8, 10, 13, 17])
      {:error, %{0 => "less than 5", 1 => "less than 5", 6 => "greater than 15"}}

      iex> list_of(integer()).(nil)
      {:ok, nil}
      iex> list_of(integer(), required: true).(nil)
      {:error, "is blank"}
  """
  def list_of(validator, opts \\ []) do
    fn value ->
      run_steps(value, [
        &ensure_list(&1),
        &validate_required(&1, opts[:required]),
        &validate_elements(&1, validator),
        &validate_min_list(&1, opts[:min]),
        &validate_max_list(&1, opts[:max])
      ])
    end
  end

  @doc """
  Validates maps.

  Errors are returned as a map containing the key and the respective error.

  ## Examples

      iex> validator = map_of(%{name: string(required: true), age: integer(min: 1)})
      iex> validator.(%{name: "Jhon", foo: "Bar"})
      {:ok, %{name: "Jhon", age: nil}}
      iex> validator.(%{"name" => "Jhon", "age" => "2"})
      {:ok, %{name: "Jhon", age: 2}}
      iex> validator.(%{age: 0})
      {:error, %{name: "is blank", age: "less than 1"}}
      iex> validator.(nil)
      {:ok, nil}
      iex> validator.("")
      {:error, "not a map"}

      iex> map_of(%{}, required: true).(nil)
      {:error, "is blank"}
  """
  def map_of(spec, opts \\ []) do
    fn value ->
      run_steps(value, [
        &validate_map(&1),
        &validate_required(&1, opts[:required]),
        &validate_spec(&1, spec)
      ])
    end
  end

  @doc """
  Allows for easy validation composition.

  Useful for customizing the error message for each kind of error.

  ## Examples

      iex> validator = compose([
      ...>   integer(required: true, message: "WHERE'S THE NUMBER??"),
      ...>   integer(min: 5, message: "IT'S TOO LOW!!!"),
      ...>   integer(max: 15, message: "IT'S TOO HIGH!!!"),
      ...> ])
      iex> validator.(10)
      {:ok, 10}
      iex> validator.(nil)
      {:error, "WHERE'S THE NUMBER??"}
      iex> validator.(3)
      {:error, "IT'S TOO LOW!!!"}
      iex> validator.(17)
      {:error, "IT'S TOO HIGH!!!"}
  """
  def compose(validators) do
    fn value -> run_steps(value, validators) end
  end

  defp run_steps(value, custom_message \\ nil, steps)

  defp run_steps(value, _custom_message, []), do: {:ok, value}

  defp run_steps(value, custom_message, [head | tail]) do
    with {:ok, new_value} <- head.(value) do
      run_steps(new_value, custom_message, tail)
    else
      {:error, default_message} -> {:error, custom_message || default_message}
    end
  end

  defp validate_required(nil, true), do: {:error, "is blank"}
  defp validate_required(value, _), do: {:ok, value}

  defp validate_one_of(value, nil), do: {:ok, value}

  defp validate_one_of(value, enum) do
    if value in enum do
      {:ok, value}
    else
      {:error, "not allowed"}
    end
  end

  # String parsing and validation

  defp validate_min_string(nil, _min), do: {:ok, nil}
  defp validate_min_string(str, nil), do: {:ok, str}

  defp validate_min_string(str, min) do
    if String.length(str) >= min do
      {:ok, str}
    else
      {:error, "less than #{min} chars long"}
    end
  end

  defp validate_max_string(nil, _max), do: {:ok, nil}
  defp validate_max_string(str, nil), do: {:ok, str}

  defp validate_max_string(str, max) do
    if String.length(str) <= max do
      {:ok, str}
    else
      {:error, "more than #{max} chars long"}
    end
  end

  defp parse_string(v) when is_binary(v), do: {:ok, v}

  defp parse_string(v) do
    {:ok, to_string(v)}
  rescue
    Protocol.UndefinedError -> {:error, "not a string"}
  end

  defp trim_string(str) do
    case String.trim(str) do
      "" -> {:ok, nil}
      str -> {:ok, str}
    end
  end

  # Number parsing and validation

  defp validate_min_number(nil, _min), do: {:ok, nil}
  defp validate_min_number(n, nil), do: {:ok, n}
  defp validate_min_number(n, min) when n >= min, do: {:ok, n}
  defp validate_min_number(_, min), do: {:error, "less than #{min}"}

  defp validate_max_number(nil, _max), do: {:ok, nil}
  defp validate_max_number(n, nil), do: {:ok, n}
  defp validate_max_number(n, max) when n <= max, do: {:ok, n}
  defp validate_max_number(_, max), do: {:error, "greater than #{max}"}

  defp parse_number(v, _parser) when is_number(v), do: {:ok, v}

  defp parse_number(nil, _parser), do: {:ok, nil}

  defp parse_number(v, parser) when is_binary(v) do
    run_steps(v, [
      string(),
      parse_number_from_string(parser)
    ])
  end

  defp parse_number(_, _parser), do: {:error, "not a number"}

  defp parse_number_from_string(parser) do
    fn
      nil ->
        {:ok, nil}

      str ->
        case parser.(str) do
          {n, ""} -> {:ok, n}
          _ -> {:error, "not a number"}
        end
    end
  end

  # List validation

  defp ensure_list(nil), do: {:ok, nil}
  defp ensure_list(list) when is_list(list), do: {:ok, list}
  defp ensure_list(_), do: {:error, "not a list"}

  defp validate_elements(nil, _validator), do: {:ok, nil}

  defp validate_elements(list, validator) do
    results =
      list
      |> Enum.with_index()
      |> Enum.map(fn {elem, index} -> {index, validator.(elem)} end)
      |> Enum.group_by(fn {_i, {s, _v}} -> s end, fn {i, {_s, v}} -> {i, v} end)

    if results[:error] do
      {:error, Enum.into(results.error, %{})}
    else
      final_list =
        results.ok
        |> Enum.map(fn {_index, elem} -> elem end)
        |> Enum.reject(&is_nil/1)

      {:ok, final_list}
    end
  end

  defp validate_min_list(nil, _min), do: {:ok, nil}
  defp validate_min_list(list, nil), do: {:ok, list}
  defp validate_min_list(list, min) when length(list) >= min, do: {:ok, list}
  defp validate_min_list(_list, min), do: {:error, "smaller than #{min} elements"}

  defp validate_max_list(nil, _max), do: {:ok, nil}
  defp validate_max_list(list, nil), do: {:ok, list}
  defp validate_max_list(list, max) when length(list) <= max, do: {:ok, list}
  defp validate_max_list(_list, max), do: {:error, "longer than #{max} elements"}

  # Map validation

  defp validate_map(nil), do: {:ok, nil}
  defp validate_map(map) when is_map(map), do: {:ok, map}
  defp validate_map(_), do: {:error, "not a map"}

  defp validate_spec(nil, _spec), do: {:ok, nil}

  defp validate_spec(map, spec) do
    results =
      spec
      |> Enum.map(fn {key, validator} -> {key, map |> fetch_map_value(key) |> validator.()} end)
      |> Enum.group_by(fn {_k, {s, _v}} -> s end, fn {k, {_s, v}} -> {k, v} end)

    if results[:error] do
      {:error, Enum.into(results.error, %{})}
    else
      {:ok, Enum.into(results.ok, %{})}
    end
  end

  defp fetch_map_value(map, key), do: map[key] || map[to_string(key)]
end
