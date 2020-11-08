defmodule Vaxin.Enum do
  @moduledoc false

  def validate([], _, acc, _, into, _) do
    {:ok, acc |> Enum.reverse() |> Enum.into(into)}
  end

  def validate([{value, index} | entries], each_validator, acc, skip_invalid?, into, message) do
    case Vaxin.validate(each_validator, value) do
      {:ok, value} ->
        validate(entries, each_validator, [value | acc], skip_invalid?, into, message)

      {:error, _} when skip_invalid? ->
        validate(entries, each_validator, acc, skip_invalid?, into, message)

      {:error, error} ->
        error =
          error
          |> Vaxin.Error.add_position({:index, index})
          |> Vaxin.Error.maybe_update_message(message)

        {:error, error}
    end
  end
end
