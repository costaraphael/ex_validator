defmodule ExValidator do
  @moduledoc """
  Helpers for validating and normalizing Elixir data structures.

  _All the examples below asume that the `ExValidator` module is imported._

  The validation works as simple composable functions, allowing simple validations...

      iex> validator = integer(max: 2)
      iex> validator.(2)
      {:ok, 2}
      iex> validator.(4)
      {:error, "is greater than 2"}

  ...data casting...

      iex> validator = map_of(%{name: string(required: true), age: integer(min: 1)})
      iex> validator.(%{"name" => "Jhon", "age": "26"})
      {:ok, %{name: "Jhon", age: 26}}
      iex> validator.(%{"age": "a"})
      {:error, %{name: "is blank", age: "is not a number"}}

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
        0 => %{age: "is not a number"},
        1 => %{addresses: %{0 => %{state: "is blank"}}}
      }}

  ## Global options

  These are the global options shared among all validators:

    - `required` - validates if the value is present
    - `default` - default result for when the value is not present
  """

  @type t(result) :: (any() -> {:ok, result} | {:error, any()})

  @doc """
  Validates and trims strings. Values that implement the `String.Chars` protocol are converted
  to strings.

  ## Options

    - `min` - validates that the string length is equal to or greater than the given value
    - `max` - validates that the string length is equal to or smaller than the given value
    - `one_of` - validates that the string is contained in the given enum
    - `matches` - validates that the string matches the given pattern
    - `message` - changes the returned error message

  ## Examples

      iex> string().("some text")
      {:ok, "some text"}
      iex> string().("   some text \\n")
      {:ok, "some text"}
      iex> string(matches: ~r/foo|bar/).("fooz")
      {:ok, "fooz"}
      iex> string(matches: ~r/foo|bar/).("baz")
      {:error, "does not match"}
      iex> string().(%{})
      {:error, "is not a string"}

      iex> string().("")
      {:ok, nil}
      iex> string(required: true).("")
      {:error, "is blank"}
  """
  @spec string(Keyword.t()) :: t(String.t())
  def string(opts \\ []) do
    fn value ->
      run_steps(value, opts[:message], [
        &parse_string(&1),
        &trim_string(&1),
        &validate_required(&1, opts[:required]),
        &validate_one_of(&1, opts[:one_of]),
        &validate_string_min(&1, opts[:min]),
        &validate_string_max(&1, opts[:max]),
        &validate_string_matches(&1, opts[:matches]),
        &put_default(&1, opts[:default])
      ])
    end
  end

  @doc """
  Validates and parses integers.

  ## Options

    - `min` - validates that the number is equal to or greater than the given value
    - `max` - validates that the number is equal to or smaller than the given value
    - `one_of` - validates if the number is contained in the given enum
    - `message` - changes the returned error message

  ## Examples

      iex> integer().(1)
      {:ok, 1}
      iex> integer().("1")
      {:ok, 1}
      iex> integer().("1a")
      {:error, "is not a number"}
      iex> integer(message: "what is this?").(:foo)
      {:error, "what is this?"}

      iex> integer().(nil)
      {:ok, nil}
      iex> integer(required: true).(nil)
      {:error, "is blank"}
  """
  @spec integer(Keyword.t()) :: t(integer())
  def integer(opts \\ []) do
    fn v ->
      run_steps(v, opts[:message], [
        fn v -> parse_number(v, &Integer.parse/1) end,
        &validate_required(&1, opts[:required]),
        &validate_one_of(&1, opts[:one_of]),
        &validate_number_min(&1, opts[:min]),
        &validate_number_max(&1, opts[:max]),
        &put_default(&1, opts[:default])
      ])
    end
  end

  @doc """
  Validates and parses floats

  ## Options

    - `min` - validates that the number is equal to or greater than the given value
    - `max` - validates that the number is equal to or smaller than the given value
    - `message` - changes the returned error message

  ## Examples

      iex> float().(1.0)
      {:ok, 1.0}
      iex> float().("1")
      {:ok, 1.0}
      iex> float().("1a")
      {:error, "is not a number"}
      iex> float(message: "whaaaat?").(:foo)
      {:error, "whaaaat?"}

      iex> float().(nil)
      {:ok, nil}
      iex> float(required: true).(nil)
      {:error, "is blank"}
  """
  @spec float(Keyword.t()) :: t(float())
  def float(opts \\ []) do
    fn v ->
      run_steps(v, opts[:message], [
        fn v -> parse_number(v, &Float.parse/1) end,
        &validate_required(&1, opts[:required]),
        &validate_number_min(&1, opts[:min]),
        &validate_number_max(&1, opts[:max]),
        &put_default(&1, opts[:default])
      ])
    end
  end

  @doc """
  Validates and parses booleans.

  The parsing follows the following rule:

    - truthy values: true, "true", 1, "1"
    - falsey values: false, "false", 0, "0"

  ## Options

    - `message` - changes the returned error message

  ## Examples

      iex> boolean().(true)
      {:ok, true}
      iex> boolean().("1")
      {:ok, true}
      iex> boolean().("true")
      {:ok, true}
      iex> boolean().("0")
      {:ok, false}
      iex> boolean().("false")
      {:ok, false}
      iex> boolean().(nil)
      {:ok, nil}
      iex> boolean().("yes")
      {:error, "is not a boolean"}
  """
  @spec boolean(Keyword.t()) :: t(boolean())
  def boolean(opts \\ []) do
    fn value ->
      run_steps(value, [
        &parse_boolean(&1),
        &validate_required(&1, opts[:required]),
        &put_default(&1, opts[:default])
      ])
    end
  end

  @doc """
  Validates lists, while stripping `nil`s.

  Errors are returned as a map containing the index and the respective error.

  ## Options

    - `min` - validates that the list length is equal to or greater than the given value
    - `max` - validates that the list length is equal to or smaller than the given value

  ## Examples

      iex> list_of(integer()).([1, 2, 3])
      {:ok, [1, 2, 3]}
      iex> list_of(integer()).("")
      {:error, "is not a list"}
      iex> list_of(integer(min: 5, max: 15)).([3, 4, 7, 8, 10, 13, 17])
      {:error, %{0 => "is less than 5", 1 => "is less than 5", 6 => "is greater than 15"}}

      iex> list_of(integer()).(nil)
      {:ok, nil}
      iex> list_of(integer(), required: true).(nil)
      {:error, "is blank"}
  """
  @spec list_of(t(a), Keyword.t()) :: t([a]) when a: var
  def list_of(validator, opts \\ []) do
    fn value ->
      run_steps(value, [
        &ensure_list(&1),
        &validate_required(&1, opts[:required]),
        &validate_elements(&1, validator),
        &validate_list_min(&1, opts[:min]),
        &validate_list_max(&1, opts[:max]),
        &put_default(&1, opts[:default])
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
      {:error, %{name: "is blank", age: "is less than 1"}}
      iex> validator.(nil)
      {:ok, nil}
      iex> validator.("")
      {:error, "is not a map"}

      iex> map_of(%{}, required: true).(nil)
      {:error, "is blank"}
  """
  @spec map_of(%{required(atom()) => t(any())}, Keyword.t()) :: t(%{required(atom()) => any()})
  def map_of(spec, opts \\ []) do
    fn value ->
      run_steps(value, [
        &validate_map(&1),
        &validate_required(&1, opts[:required]),
        &validate_spec(&1, spec),
        &put_default(&1, opts[:default])
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
  @spec compose([t(a)]) :: t(a) when a: var
  def compose(validators) do
    fn value -> run_steps(value, validators) end
  end

  @doc """
  Checks if any of the given validators allows the value.

  ## Examples

      iex> validator = any_of([integer(required: true), string(required: true, matches: ~r/^foo/)])
      iex> validator.(1)
      {:ok, 1}
      iex> validator.("fooz")
      {:ok, "fooz"}
      iex> validator.("baaz")
      {:error, ["is not a number", "does not match"]}
      iex> validator.(nil)
      {:error, ["is blank", "is blank"]}
  """
  @spec any_of([t(any())]) :: t(any())
  def any_of(validators) do
    fn value ->
      run_steps(value, [
        &check_any_of(&1, validators)
      ])
    end
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

  defp put_default(nil, default), do: {:ok, default}
  defp put_default(value, _default), do: {:ok, value}

  defp validate_one_of(nil, _enum), do: {:ok, nil}
  defp validate_one_of(value, nil), do: {:ok, value}

  defp validate_one_of(value, enum) do
    if value in enum do
      {:ok, value}
    else
      {:error, "is not allowed"}
    end
  end

  # String parsing and validation

  defp validate_string_min(nil, _min), do: {:ok, nil}
  defp validate_string_min(str, nil), do: {:ok, str}

  defp validate_string_min(str, min) do
    if String.length(str) >= min do
      {:ok, str}
    else
      {:error, "is less than #{min} chars long"}
    end
  end

  defp validate_string_max(nil, _max), do: {:ok, nil}
  defp validate_string_max(str, nil), do: {:ok, str}

  defp validate_string_max(str, max) do
    if String.length(str) <= max do
      {:ok, str}
    else
      {:error, "is more than #{max} chars long"}
    end
  end

  defp validate_string_matches(nil, _pattern), do: {:ok, nil}
  defp validate_string_matches(str, nil), do: {:ok, str}

  defp validate_string_matches(str, pattern) do
    if str =~ pattern do
      {:ok, str}
    else
      {:error, "does not match"}
    end
  end

  defp parse_string(v) when is_binary(v), do: {:ok, v}

  defp parse_string(v) do
    {:ok, to_string(v)}
  rescue
    Protocol.UndefinedError -> {:error, "is not a string"}
  end

  defp trim_string(str) do
    case String.trim(str) do
      "" -> {:ok, nil}
      str -> {:ok, str}
    end
  end

  # Number parsing and validation

  defp validate_number_min(nil, _min), do: {:ok, nil}
  defp validate_number_min(n, nil), do: {:ok, n}
  defp validate_number_min(n, min) when n >= min, do: {:ok, n}
  defp validate_number_min(_, min), do: {:error, "is less than #{min}"}

  defp validate_number_max(nil, _max), do: {:ok, nil}
  defp validate_number_max(n, nil), do: {:ok, n}
  defp validate_number_max(n, max) when n <= max, do: {:ok, n}
  defp validate_number_max(_, max), do: {:error, "is greater than #{max}"}

  defp parse_number(v, _parser) when is_number(v), do: {:ok, v}

  defp parse_number(nil, _parser), do: {:ok, nil}

  defp parse_number(v, parser) when is_binary(v) do
    run_steps(v, [
      string(),
      parse_number_from_string(parser)
    ])
  end

  defp parse_number(_, _parser), do: {:error, "is not a number"}

  defp parse_number_from_string(parser) do
    fn
      nil ->
        {:ok, nil}

      str ->
        case parser.(str) do
          {n, ""} -> {:ok, n}
          _ -> {:error, "is not a number"}
        end
    end
  end

  # Boolean parsing

  defp parse_boolean(value) when is_boolean(value), do: {:ok, value}

  defp parse_boolean(value) do
    validator = any_of([integer(one_of: [0, 1]), string(one_of: ["true", "false"])])

    case validator.(value) do
      {:ok, 1} -> {:ok, true}
      {:ok, "true"} -> {:ok, true}
      {:ok, 0} -> {:ok, false}
      {:ok, "false"} -> {:ok, false}
      {:ok, nil} -> {:ok, nil}
      _ -> {:error, "is not a boolean"}
    end
  end

  # List validation

  defp ensure_list(nil), do: {:ok, nil}
  defp ensure_list(list) when is_list(list), do: {:ok, list}
  defp ensure_list(_), do: {:error, "is not a list"}

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

  defp validate_list_min(nil, _min), do: {:ok, nil}
  defp validate_list_min(list, nil), do: {:ok, list}
  defp validate_list_min(list, min) when length(list) >= min, do: {:ok, list}
  defp validate_list_min(_list, min), do: {:error, "is smaller than #{min} elements"}

  defp validate_list_max(nil, _max), do: {:ok, nil}
  defp validate_list_max(list, nil), do: {:ok, list}
  defp validate_list_max(list, max) when length(list) <= max, do: {:ok, list}
  defp validate_list_max(_list, max), do: {:error, "is longer than #{max} elements"}

  # Map validation

  defp validate_map(nil), do: {:ok, nil}
  defp validate_map(map) when is_map(map), do: {:ok, map}
  defp validate_map(_), do: {:error, "is not a map"}

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

  # Any of validation

  defp check_any_of(value, validators) do
    result =
      Enum.reduce_while(validators, {:error, []}, fn validator, {:error, errors} ->
        case validator.(value) do
          {:ok, new_value} ->
            {:halt, {:ok, new_value}}

          {:error, error} ->
            {:cont, {:error, [error | errors]}}
        end
      end)

    case result do
      {:ok, value} -> {:ok, value}
      {:error, errors} -> {:error, Enum.reverse(errors)}
    end
  end
end
