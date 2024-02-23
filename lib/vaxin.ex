defmodule Vaxin do
  @moduledoc """
  Contains the core functionality to work with Vaxin.

  Vaxin at its core is a data validator combinator library. It tries to solve
  the problem of validating the shape and content of some data (most useful
  when such data come from an external source) and of conforming those data
  to arbitrary formats.

  Vaxin is based on the concept of validators: a validator is something that
  knows how to validate a term and transform it to something else if necessary.
  A good example of a validator could be something that validates that a term is
  a string representation of an integer and that converts such string to the
  represented integer.

  ## Validators

  A validator is a function that takes one argument and returns either:

    * `{:ok, transformed}` - indicating the validation has succeeded (the input
      term is considered valid) and `transformed` is the conformed value for the
      input term.

    * `{:error, reason}` - indicating means the validation has failed (the input
      term is invalid). `reason` can be a string representing the error message
      or a `Vaxin.Error`. Note that `validate/2` will eventually wrap the error
      message into a `Vaxin.Error`.

    * `true` - indicating the validation has succeeded. It has the same effect
      as `{:ok, transformed}`, but it can be used when the transformed value
      is the same as the input value. This is useful for "predicate" validators
      (functions that take one argument and return a boolean).

    * `false` - it means validation failed. It is the same as `{:error, reason}`,
      except the reason only mentions that a "predicate failed".

  Returning a boolean value is supported so that existing predicate functions
  can be used as validators without modification. Examples of such functions are
  type guards (`is_binary/1` or `is_list/1`), functions like `String.valid?/1`,
  and many others.

  The concept of validators is very powerful as they can be easily combined: for
  example, the `Vaxin.all_of/1` function takes a list of validators and returns
  a validator that passes if all of the given validators pass. Vaxin provides both
  "basic" validators as well as validator combinators.

  ## Built-in validators

    On top of powerful built-in Elixir predicate functions, Vaxin also provides
    a few built-in validators. You might notice that they are very similar to
    the `Ecto.Changeset` API. The intention is to enable developers who are familiar
    with Ecto to be immediately productive with Vaxin. However, there is a few
    fundamental difference between two libraries:

    * Vaxin built-in validators take in options and return a **validator** which
    can be used with `Vaxin.validate/2` later.

    * Vaxin does **not** have the concept of "empty" values. `nil` or empty strings
    are treated the same way as other Elixir data.

    Consider the following example: `nil` will be validated with Vaxin while Ecto
    would skip it.

      iex> import Vaxin
      iex> validator = validate_number(greater_than: 0)
      iex> {:error, error} = validate(validator, nil)
      iex> Exception.message(error)
      "must be a number"

  ## Examples

  Let's say S.H.I.E.L.D are looking for a replacement for Captain America and receive
  thousands of applications, they could use Vaxin to build a profile validator.

      iex> import Vaxin
      iex>
      iex> age_validator =
      ...>   validate_number(
      ...>     &is_integer/1,
      ...>     greater_than: 18,
      ...>     message: "is too young to be a superhero"
      ...>   )
      iex>
      iex> superpower_validator =
      ...>   validate_inclusion(
      ...>     &is_binary/1,
      ...>     ["fly", "strength", "i-can-do-this-all-day"],
      ...>     message: "is unfortunately not the super-power we are looking for"
      ...>   )
      iex> superhero_validator =
      ...>   (&is_map/1)
      ...>   |> validate_key("age", :required, age_validator)
      ...>   |> validate_key("superpower", :required, superpower_validator)
      iex>
      iex> peter_parker = %{"age" => 16, "superpower" => "speed"}
      iex> {:error, error} = Vaxin.validate(superhero_validator, peter_parker)
      iex> Exception.message(error)
      ~s("age" is too young to be a superhero)
      iex>
      iex> falcon = %{"age" => 40, "superpower" => "fly"}
      iex> Vaxin.validate(superhero_validator, falcon)
      {:ok, %{"age" => 40, "superpower" => "fly"}}

  """

  alias Vaxin.Error

  @type validator() ::
          (any() ->
             {:ok, any()}
             | {:error, String.t()}
             | {:error, Error.t()}
             | boolean())

  @doc """
  Validates `value` against `validator`.

  ### Examples

      iex> Vaxin.validate(&is_atom/1, :foo)
      {:ok, :foo}
      iex> Vaxin.validate(&is_atom/1, "foo")
      {:error, %Vaxin.Error{validator: &is_atom/1, message: "must be an atom", metadata: [kind: :is_atom]}}

  """
  @spec validate(validator(), any()) :: {:ok, any()} | {:error, Error.t()}
  def validate(validator, value) do
    case validator.(value) do
      true ->
        {:ok, value}

      false ->
        {:error, Error.new(validator)}

      {:ok, value} ->
        {:ok, value}

      {:error, message} when is_binary(message) ->
        {:error, Error.new(validator, message)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Returns a validator that passes when all the given validators pass.

  ### Examples

      iex> validator = Vaxin.all_of([&is_integer/1, &(&1 >= 1)])
      iex> Vaxin.validate(validator, 1)
      {:ok, 1}
      iex> {:error, %Vaxin.Error{message: "is invalid"}} = Vaxin.validate(validator, 0)

  """
  @spec all_of([validator(), ...]) :: validator()
  def all_of([_ | _] = validators) do
    Enum.reduce(validators, &combine(&2, &1))
  end

  @doc """
  Combines `validator1` with `validator2`. Note that `validator2` will only be executed
  if `validator1` succeeds.

  ### Examples

      iex> validator = Vaxin.combine(&is_integer/1, &(&1 >= 1))
      iex> Vaxin.validate(validator, 1)
      {:ok, 1}
      iex> {:error, %Vaxin.Error{message: "is invalid"}} = Vaxin.validate(validator, 0)

  """
  @spec combine(validator(), validator()) :: validator()
  def combine(validator1, validator2)
      when is_function(validator1, 1)
      when is_function(validator2, 1) do
    &with {:ok, term} <- validate(validator1, &1) do
      validate(validator2, term)
    end
  end

  @doc """
  Returns a validator that always passes. It is useful placing in the beginning of the validator chain.

  ### Examples

      iex> validator = Vaxin.noop() |> Vaxin.validate_inclusion([:foo, "foo"])
      iex> Vaxin.validate(validator, :foo)
      {:ok, :foo}
      iex> Vaxin.validate(validator, "foo")
      {:ok, "foo"}

  """
  @spec noop() :: (any() -> {:ok, any()})
  @compile {:inline, [noop: 0]}
  def noop(), do: &{:ok, &1}

  @doc """
  Combines `combinator` with a validator that checks the value of `key` in a map.

  ## Options

  * `message` - the message on failure. Defaults to "is required" or the error returned
    by `value_validator`.

  ## Examples

      iex> tinyint_validator = validate_number(greater_than_or_equal_to: -128, less_than: 128, message: "must be a tinyint")
      iex> validator = Vaxin.validate_key(:id, :required, tinyint_validator)
      iex> Vaxin.validate(validator, %{id: 1})
      {:ok, %{id: 1}}
      iex> {:error, error} = Vaxin.validate(validator, %{id: 129})
      iex> Exception.message(error)
      "id must be a tinyint"

      iex> number_validator = validate_number(greater_than_or_equal_to: 1)
      iex> validator = Vaxin.validate_key(:page, {:optional, default: 1}, number_validator)
      iex> Vaxin.validate(validator, %{})
      {:ok, %{page: 1}}

  """
  @spec validate_key(
          validator(),
          any(),
          :required | :optional | {:optional, default: any()},
          validator(),
          Keyword.t()
        ) ::
          validator()
  def validate_key(
        combinator \\ &is_map/1,
        key,
        condition,
        value_validator,
        options \\ []
      )

  def validate_key(combinator, key, condition, value_validator, options) do
    combine(combinator, fn map ->
      message = options[:message]

      case Map.fetch(map, key) do
        {:ok, value} ->
          case validate(value_validator, value) do
            {:ok, value} ->
              {:ok, Map.replace!(map, key, value)}

            {:error, error} ->
              error =
                error
                |> Error.maybe_update_message(message)
                |> Error.add_position({:key, key})

              {:error, error}
          end

        :error ->
          case condition do
            {:optional, options} ->
              default_value = Keyword.fetch!(options, :default)

              {:ok, Map.put_new(map, key, default_value)}

            :required ->
              {:error, Error.new(:required, message || "is required", position: {:key, key})}

            :optional ->
              {:ok, map}
          end
      end
    end)
  end

  @doc """
  Combines `combinator` with a validator that validates string length.

  ## Options

  * `exact` - the length must be exact this value.
  * `min` - the length must be greater than or equal to this value.
  * `max` - the length must be less than or equal to this value.
  * `message` - the message on failure. Defaults to either:
    * must be %{length} byte(s)
    * must be at least %{length} byte(s)
    * must be at most %{length} byte(s)

  ## Examples

      iex> validator = Vaxin.validate_string_length(min: 1, max: 20)
      iex> Vaxin.validate(validator, "Hello World!")
      {:ok, "Hello World!"}
      iex> {:error, error} = Vaxin.validate(validator, "")
      iex> Exception.message(error)
      "must be at least 1 byte(s)"

  """
  @spec validate_string_length(validator(), Keyword.t()) :: validator()
  def validate_string_length(validator \\ &String.valid?/1, options)

  def validate_string_length(validator, options) do
    combine(validator, fn value ->
      {message, options} = Keyword.pop(options, :message)

      with :ok <- do_validate_length(options, byte_size(value), message), do: {:ok, value}
    end)
  end

  @length_validators %{
    exact: {&==/2, "must be %{length} byte(s)"},
    min: {&>=/2, "must be at least %{length} byte(s)"},
    max: {&<=/2, "must be at most %{length} byte(s)"}
  }

  defp do_validate_length([], _, _), do: :ok

  defp do_validate_length([{spec, target} | rest], count, message) do
    {comparator, default_message} = Map.fetch!(@length_validators, spec)

    if comparator.(count, target) do
      do_validate_length(rest, count, message)
    else
      {:error, Error.new(:string_length, message || default_message, kind: spec, length: target)}
    end
  end

  @doc """
  Combines `combinator` with a validator that validates the term as a number.

  ## Options

  * `less_than` - the number must be less than this value.
  * `greater_than` - the number must be greater than this value.
  * `less_than_or_equal_to` - the number must be less than or equal to this value.
  * `greater_than_or_equal_to` - the number must be greater than or equal to this value.
  * `equal_to` - the number must be equal to this value.
  * `not_equal_to` - the number must be not equal to this value.
  * `message` - the error message when the number validator fails. Defaults to either:
    * must be less than %{number}
    * must be greater than %{number}
    * must be less than or equal to %{number}
    * must be greater than or equal to %{number}
    * must be equal to %{number}
    * must be not equal to %{number}

  ## Examples

      iex> validator = Vaxin.validate_number(greater_than: 1, less_than: 20)
      iex> Vaxin.validate(validator, 10)
      {:ok, 10}
      iex> {:error, error} = Vaxin.validate(validator, 20)
      iex> Exception.message(error)
      "must be less than 20"

  """

  @spec validate_number(validator(), Keyword.t()) :: validator()
  def validate_number(combinator \\ &is_number/1, options) do
    combine(combinator, fn value ->
      {message, options} = Keyword.pop(options, :message)
      Vaxin.Number.validate(value, options, message)
    end)
  end

  @doc """
  Combines `combinator` with a validator that validates the term matches the given regular expression.

  ## Options

  * `message` - the error message when the format validator fails. Defaults to `"has invalid format"`.

  ## Examples

      iex> import Vaxin
      iex> validator = validate_format(&String.valid?/1, ~r/@/)
      iex> validate(validator, "foo@bar.com")
      {:ok, "foo@bar.com"}

  """
  @spec validate_format(validator(), Regex.t(), Keyword.t()) :: validator()
  def validate_format(combinator \\ &String.valid?/1, format, options \\ []) do
    combine(combinator, fn value ->
      if value =~ format do
        {:ok, value}
      else
        {:error, Error.new(:format, options[:message] || "has invalid format", format: format)}
      end
    end)
  end

  @doc """
  Combines `combinator` with a validator that validates the term is included in `permitted`.

  ## Options

  * `message` - the error message on failure. Defaults to "is invalid".

  ## Examples

      iex> import Vaxin
      iex> validator = validate_inclusion(["foo", "bar"])
      iex> validate(validator, "foo")
      {:ok, "foo"}

  """
  @spec validate_inclusion(validator(), Enum.t(), Keyword.t()) :: validator()
  def validate_inclusion(validator \\ noop(), permitted, options \\ [])

  def validate_inclusion(validator, permitted, options) do
    combine(validator, fn value ->
      if value in permitted do
        {:ok, value}
      else
        {:error, Error.new(:inclusion, options[:message] || "is invalid", enum: permitted)}
      end
    end)
  end

  @doc """
  Combines `combinator` with a validator that validates the term is excluded in `permitted`.

  ## Options

  * `message` - the error message on failure. Defaults to "is reserved".

  ## Examples

      iex> import Vaxin
      iex> validator = validate_exclusion(["foo", "bar"])
      iex> {:error, error} = validate(validator, "foo")
      iex> Exception.message(error)
      "is reserved"

  """
  @spec validate_exclusion(validator(), Enum.t(), Keyword.t()) :: validator()
  def validate_exclusion(validator \\ noop(), reversed, options \\ []) do
    combine(validator, fn value ->
      if value not in reversed do
        {:ok, value}
      else
        {:error, Error.new(:exclusion, options[:message] || "is reserved", enum: reversed)}
      end
    end)
  end

  @doc """
  Combine `combinator` with a validator that validates every item in an enum against `each_validator`.

  ## Options

  * `skip_invalid?` - (boolean) if `true`, skips all invalid items. Defaults to `false`.
  * `into` - the collectable where the transformed values should end up in. Defaults to `[]`.

  ## Examples

      iex> import Vaxin
      iex> validator = validate_enum(&is_list/1, &is_integer/1)
      iex> Vaxin.validate(validator, [1, 2])
      {:ok, [1, 2]}
      iex> {:error, error} = Vaxin.validate(validator, [1, "2"])
      iex> Exception.message(error)
      "[1] must be an integer"
      iex> validator = validate_enum(&is_list/1, &is_integer/1, skip_invalid?: true)
      iex> Vaxin.validate(validator, [1, "2"])
      {:ok, [1]}

  """
  @spec validate_enum(validator(), validator(), Keyword.t()) :: validator()
  def validate_enum(combinator, each_validator, options \\ [])

  def validate_enum(combinator, each_validator, options) do
    combine(combinator, fn enum ->
      skip_invalid? = Keyword.get(options, :skip_invalid?, false)
      into = Keyword.get(options, :into, [])

      enum
      # TODO: Handle map keys better.
      |> Enum.with_index()
      |> Vaxin.Enum.validate(each_validator, [], skip_invalid?, into, options[:message])
    end)
  end

  @doc """
  Returns a validator that always passes and applies the given `transformer`.

  ## Examples

      iex> import Vaxin
      iex> validator = transform(noop(), &String.to_integer/1)
      iex> validate(validator, "1")
      {:ok, 1}
  """
  @spec transform(validator(), (any() -> any())) :: validator()
  def transform(combinator \\ noop(), transformer) do
    combine(combinator, &{:ok, transformer.(&1)})
  end
end
