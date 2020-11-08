defmodule VaxinTest do
  use ExUnit.Case, async: true

  import Vaxin

  alias Vaxin.Error

  doctest Vaxin

  describe "all_of" do
    test "combines a list of validators" do
      validator = all_of([&is_integer/1, &(&1 > 0)])

      assert validate(validator, 2) == {:ok, 2}

      assert {:error,
              %Error{
                message: "is invalid",
                metadata: [kind: :predicate],
                validator: validator
              }} = validate(validator, 0)

      assert is_function(validator, 1)
    end
  end

  describe "validate_number" do
    test ":greater_than option" do
      validator = validate_number(greater_than: 1)

      assert validate(validator, 2) == {:ok, 2}
      assert validate(validator, 1.01) == {:ok, 1.01}

      assert validate(validator, 1) ==
               {:error,
                %Error{
                  message: "must be greater than %{number}",
                  metadata: [kind: :greater_than, number: 1],
                  validator: :number
                }}
    end

    test ":less_than option" do
      validator = validate_number(less_than: 1)

      assert validate(validator, 0) == {:ok, 0}
      assert validate(validator, 0.99) == {:ok, 0.99}

      assert validate(validator, 1) ==
               {:error,
                %Error{
                  message: "must be less than %{number}",
                  metadata: [kind: :less_than, number: 1],
                  validator: :number
                }}
    end

    test ":greater_than_or_equal_to option" do
      validator = validate_number(greater_than_or_equal_to: 1)

      assert validate(validator, 1) == {:ok, 1}
      assert validate(validator, 1.01) == {:ok, 1.01}

      assert validate(validator, 0) ==
               {:error,
                %Error{
                  message: "must be greater than or equal to %{number}",
                  metadata: [kind: :greater_than_or_equal_to, number: 1],
                  validator: :number
                }}
    end

    test ":equal_to option" do
      validator = validate_number(equal_to: 1)

      assert validate(validator, 1) == {:ok, 1}
      assert validate(validator, 1.0) == {:ok, 1.0}

      assert validate(validator, 0) ==
               {:error,
                %Error{
                  message: "must be equal to %{number}",
                  metadata: [kind: :equal_to, number: 1],
                  validator: :number
                }}
    end

    test ":not_equal_to option" do
      validator = validate_number(not_equal_to: 1)

      assert validate(validator, 0) == {:ok, 0}
      assert validate(validator, 1.1) == {:ok, 1.1}

      assert validate(validator, 1) ==
               {:error,
                %Error{
                  message: "must be not equal to %{number}",
                  metadata: [kind: :not_equal_to, number: 1],
                  validator: :number
                }}
    end

    test "ensures number" do
      validator = validate_number([])

      assert validate(validator, "1") ==
               {:error,
                %Error{
                  message: "must be a number",
                  metadata: [kind: :is_number],
                  validator: &is_number/1
                }}
    end

    test ":message option" do
      validator = validate_number(greater_than: 1, message: "> 1")

      assert validate(validator, 0) ==
               {:error,
                %Error{
                  message: "> 1",
                  metadata: [kind: :greater_than, number: 1],
                  validator: :number
                }}
    end
  end

  describe "validate_string_length" do
    test ":exact option" do
      validator = validate_string_length(exact: 1)

      assert validate(validator, "1") == {:ok, "1"}

      assert validate(validator, "") ==
               {:error,
                %Error{
                  message: "must be %{length} byte(s)",
                  metadata: [kind: :exact, length: 1],
                  validator: :string_length
                }}
    end

    test ":min option" do
      validator = validate_string_length(min: 1)

      assert validate(validator, "1") == {:ok, "1"}

      assert validate(validator, "") ==
               {:error,
                %Error{
                  message: "must be at least %{length} byte(s)",
                  metadata: [kind: :min, length: 1],
                  validator: :string_length
                }}
    end

    test ":max option" do
      validator = validate_string_length(max: 1)

      assert validate(validator, "1") == {:ok, "1"}

      assert validate(validator, "12") ==
               {:error,
                %Error{
                  message: "must be at most %{length} byte(s)",
                  metadata: [kind: :max, length: 1],
                  validator: :string_length
                }}
    end

    test ":message option" do
      validator = validate_string_length(max: 1, message: "length <= 1")

      assert validate(validator, "12") ==
               {:error,
                %Error{
                  message: "length <= 1",
                  metadata: [kind: :max, length: 1],
                  validator: :string_length
                }}
    end
  end

  describe "validate_format" do
    test "works with regular expressions" do
      validator = validate_format(~r/foo/)

      assert validate(validator, "ooffoo") == {:ok, "ooffoo"}

      assert validate(validator, "oof") ==
               {:error,
                %Error{
                  message: "has invalid format",
                  metadata: [format: ~r/foo/],
                  validator: :format
                }}
    end

    test ":message option" do
      validator = validate_format(&is_binary/1, ~r/foo/, message: ~s(should contain "foo"))

      assert validate(validator, "oof") ==
               {:error,
                %Error{
                  message: ~s(should contain "foo"),
                  metadata: [format: ~r/foo/],
                  validator: :format
                }}
    end
  end

  describe "validate_inclusion" do
    test "supports list" do
      validator = validate_inclusion([1, 2])

      assert validate(validator, 1) == {:ok, 1}
      assert validate(validator, 2) == {:ok, 2}

      assert validate(validator, 3) ==
               {:error,
                %Error{
                  message: "is invalid",
                  metadata: [enum: [1, 2]],
                  validator: :inclusion
                }}
    end

    test "supports MapSet" do
      validator = validate_inclusion(MapSet.new([1, 2]))

      assert validate(validator, 1) == {:ok, 1}
      assert validate(validator, 2) == {:ok, 2}

      assert validate(validator, 3) ==
               {:error,
                %Error{
                  message: "is invalid",
                  metadata: [enum: MapSet.new([1, 2])],
                  validator: :inclusion
                }}
    end

    test ":message option" do
      validator = validate_inclusion(&is_integer/1, [1, 2], message: "should be either 1 or 2")

      assert validate(validator, 3) ==
               {:error,
                %Error{
                  message: "should be either 1 or 2",
                  metadata: [enum: [1, 2]],
                  validator: :inclusion
                }}
    end
  end

  describe "validate_exclusion" do
    test "supports list" do
      validator = validate_exclusion([1, 2])

      assert validate(validator, 3) == {:ok, 3}

      assert validate(validator, 1) ==
               {:error,
                %Error{
                  message: "is reserved",
                  metadata: [enum: [1, 2]],
                  validator: :exclusion
                }}
    end

    test "supports MapSet" do
      validator = validate_exclusion(MapSet.new([1, 2]))

      assert validate(validator, 3) == {:ok, 3}

      assert validate(validator, 1) ==
               {:error,
                %Error{
                  message: "is reserved",
                  metadata: [enum: MapSet.new([1, 2])],
                  validator: :exclusion
                }}
    end

    test ":message option" do
      validator = validate_exclusion(&is_integer/1, [1, 2], message: "should be neither 1 nor 2")

      assert validate(validator, 1) ==
               {:error,
                %Error{
                  message: "should be neither 1 nor 2",
                  metadata: [enum: [1, 2]],
                  validator: :exclusion
                }}
    end
  end

  describe "validate_enum" do
    test "validates each entry" do
      validator = validate_enum(&is_list/1, &is_integer/1)

      assert validate(validator, [1, 2]) == {:ok, [1, 2]}

      assert validate(validator, [1, "2"]) ==
               {:error,
                %Vaxin.Error{
                  message: "must be an integer",
                  metadata: [position: {:index, 1}, kind: :is_integer],
                  validator: &is_integer/1
                }}
    end

    test ":skip_invalid? option" do
      validator = validate_enum(&is_list/1, &is_integer/1, skip_invalid?: true)

      assert validate(validator, [1, 2]) == {:ok, [1, 2]}

      assert validate(validator, [1, "2"]) == {:ok, [1]}
    end

    test ":message option" do
      validator = validate_enum(&is_list/1, &is_integer/1, message: "should be an integer")

      assert validate(validator, [1, "2"]) ==
               {:error,
                %Vaxin.Error{
                  message: "should be an integer",
                  metadata: [position: {:index, 1}, kind: :is_integer],
                  validator: &is_integer/1
                }}
    end
  end

  describe "validate_key" do
    test "validates required keys" do
      validator = validate_key(&is_map/1, "foo", :required, &is_binary/1)

      assert validate(validator, %{"foo" => "a"}) == {:ok, %{"foo" => "a"}}

      assert validate(validator, %{}) ==
               {:error,
                %Vaxin.Error{
                  message: "is required",
                  metadata: [position: {:key, "foo"}],
                  validator: :required
                }}

      assert validate(validator, %{"foo" => 1})

      {:error,
       %Vaxin.Error{
         message: "must be a binary",
         metadata: [position: {:key, "foo"}],
         validator: &is_binary/1
       }}
    end

    test "validates optional key" do
      validator = validate_key(&is_map/1, "foo", :optional, &is_binary/1)

      assert validate(validator, %{}) == {:ok, %{}}
      assert validate(validator, %{"foo" => "a"}) == {:ok, %{"foo" => "a"}}
      assert validate(validator, %{"foo" => 1})

      {:error,
       %Vaxin.Error{
         message: "must be a binary",
         metadata: [position: {:key, "foo"}],
         validator: &is_binary/1
       }}
    end

    test ":message option" do
      validator = validate_key(&is_map/1, "foo", :required, &is_binary/1, message: "is invalid")

      assert validate(validator, %{}) ==
               {:error,
                %Vaxin.Error{
                  message: "is invalid",
                  metadata: [position: {:key, "foo"}],
                  validator: :required
                }}

      assert validate(validator, %{"foo" => 1}) ==
               {:error,
                %Vaxin.Error{
                  message: "is invalid",
                  metadata: [position: {:key, "foo"}, kind: :is_binary],
                  validator: &is_binary/1
                }}
    end
  end

  describe "integration of multiple validators" do
    test "validates multi layer nested map" do
      user_validator =
        validate_key(
          "id",
          :required,
          validate_number(greater_than_or_equal_to: 1, message: "is not a valid ID")
        )
        |> validate_key(
          "name",
          :required,
          validate_string_length(min: 5, max: 20, message: "is not a valid name")
        )
        |> validate_key(
          "email",
          :optional,
          validate_format(&String.valid?/1, ~r/@/, message: "is not a valid email")
        )
        |> validate_key("birthdate", :optional, &match?(%Date{}, &1),
          message: "is not a valid date"
        )

      assert validate_error(user_validator, %{}) == ~s("id" is required)
      assert validate_error(user_validator, %{"id" => "1"}) == ~s("id" must be a number)
      assert validate_error(user_validator, %{"id" => 0}) == ~s("id" is not a valid ID)
      assert validate_error(user_validator, %{"id" => 1}) == ~s("name" is required)

      assert validate_error(user_validator, %{"id" => 1, "name" => nil}) ==
               ~s("name" must be a string)

      assert validate_error(user_validator, %{"id" => 1, "name" => "J"}) ==
               ~s("name" is not a valid name)

      assert validate_error(user_validator, %{"id" => 1, "name" => "John Cena - You Can't See Me"}) ==
               ~s("name" is not a valid name)

      assert validate_error(user_validator, %{"id" => 1, "name" => "John Cena", "email" => nil}) ==
               ~s("email" must be a string)

      assert validate_error(user_validator, %{
               "id" => 1,
               "name" => "John Cena",
               "email" => "john.cena"
             }) ==
               ~s("email" is not a valid email)

      assert validate_error(user_validator, %{
               "id" => 1,
               "name" => "John Cena",
               "email" => "john@cena.com",
               "birthdate" => nil
             }) ==
               ~s("birthdate" is not a valid date)
    end

    test "validates a list of map" do
      validator =
        validate_enum(
          &is_list/1,
          validate_key(:foo, :required, &is_integer/1)
          |> validate_key(:bar, :required, &is_binary/1)
          |> validate_key(:qwe, :required, &is_float/1)
        )

      valid_entry = %{
        foo: 1,
        bar: "1",
        qwe: 1.1
      }

      invalid_entry = %{}

      assert validate_error(validator, [invalid_entry]) == ~s([0].foo is required)

      assert validate_error(validator, [valid_entry, valid_entry, invalid_entry]) ==
               ~s([2].foo is required)
    end
  end

  defp validate_error(validator, data) do
    assert {:error, error} = validate(validator, data)
    Exception.message(error)
  end
end
