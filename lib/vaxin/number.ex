defmodule Vaxin.Number do
  @moduledoc false

  @number_validators %{
    less_than: {&</2, "must be less than %{number}"},
    greater_than: {&>/2, "must be greater than %{number}"},
    less_than_or_equal_to: {&<=/2, "must be less than or equal to %{number}"},
    greater_than_or_equal_to: {&>=/2, "must be greater than or equal to %{number}"},
    equal_to: {&==/2, "must be equal to %{number}"},
    not_equal_to: {&!=/2, "must be not equal to %{number}"}
  }

  def validate(number, options, message \\ nil)

  def validate(number, [], _message), do: {:ok, number}

  def validate(number, [{spec_key, target_value} | rest], message) do
    {comparator, default_message} = Map.fetch!(@number_validators, spec_key)

    if comparator.(number, target_value) do
      validate(number, rest, message)
    else
      {:error,
       Vaxin.Error.new(:number, message || default_message, kind: spec_key, number: target_value)}
    end
  end
end
