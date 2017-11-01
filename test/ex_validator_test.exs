defmodule ExValidatorTest do
  use ExUnit.Case
  doctest ExValidator, import: true

  import ExValidator

  test "one of validation" do
    assert {:ok, 1} = integer(one_of: [1, 2]).(1)
    assert {:error, "not allowed"} = integer(one_of: [1, 2]).(3)
  end

  test "defaults" do
    assert {:ok, 42} = integer(default: 42).("")
  end

  test "validates integers" do
    assert {:ok, 1} = integer(min: 1).(1)
    assert {:error, "less than 1"} = integer(min: 1).(0)

    assert {:ok, 1} = integer(max: 1).(1)
    assert {:error, "greater than 1"} = integer(max: 1).(2)

    assert {:ok, nil} = integer(min: 2, max: 2).(nil)

    assert {:ok, nil} = integer(one_of: [1, 2, 3]).(nil)
  end

  test "validates floats" do
    assert {:ok, 1.0} = float(min: 1).(1.0)
    assert {:error, "less than 1"} = float(min: 1).(0.5)

    assert {:ok, 1} = float(max: 1).(1)
    assert {:error, "greater than 1"} = float(max: 1).(1.5)

    assert {:ok, nil} = float(min: 2, max: 2).(nil)
  end

  test "validates strings" do
    assert {:ok, "foo"} = string(max: 3).("foo")
    assert {:error, "more than 2 chars long"} = string(max: 2).("foo")

    assert {:ok, "foo"} = string(min: 3).("foo")
    assert {:error, "less than 4 chars long"} = string(min: 4).("foo")

    assert {:ok, nil} = string(min: 2, max: 2).(nil)
    assert {:ok, nil} = string(maches: ~r/foo/).(nil)
  end

  test "validates lists" do
    assert {:ok, [1, 2, 3]} = list_of(integer(min: 0), max: 3).([1, 2, 3, nil, ""])
    assert {:error, "longer than 3 elements"} = list_of(integer(), max: 3).([1, 2, 3, 4])
    assert {:error, "smaller than 3 elements"} = list_of(integer(), min: 3).([1, 2, nil, ""])

    assert {:ok, nil} = list_of(integer(), min: 2, max: 2).(nil)
  end

  test "complex test" do
    address =
      map_of(%{city: string(required: true), state: string(required: true, min: 2, max: 2)})

    person =
      map_of(%{
        name: string(required: true),
        age: integer(min: 1),
        gender: string(required: true, one_of: ~w[m f]),
        addresses: list_of(address)
      })

    validator = list_of(person)

    data = [
      %{
        "name" => "Jhon",
        "age" => "30",
        "gender" => "m",
        "addresses" => [
          %{"city" => "New York", "state" => "NY"},
          %{"city" => "Los Angeles", "state" => "LA"}
        ]
      },
      nil,
      %{
        "name" => "Alex",
        "gender" => "f",
        "addresses" => [
          %{"city" => "Chicago", "state" => "IL"},
          %{"city" => "San Francisco", "state" => "CA"}
        ]
      }
    ]

    assert {:ok, parsed} = validator.(data)

    assert parsed == [
             %{
               name: "Jhon",
               age: 30,
               gender: "m",
               addresses: [
                 %{city: "New York", state: "NY"},
                 %{city: "Los Angeles", state: "LA"}
               ]
             },
             %{
               name: "Alex",
               age: nil,
               gender: "f",
               addresses: [
                 %{city: "Chicago", state: "IL"},
                 %{city: "San Francisco", state: "CA"}
               ]
             }
           ]
  end
end
