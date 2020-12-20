defmodule Vaxin.Error do
  defexception [
    :validator,
    :message,
    metadata: []
  ]

  @type t() :: %__MODULE__{
          validator: atom() | Vaxin.validator(),
          message: String.t(),
          metadata: Keyword.t()
        }

  @impl true
  def message(%__MODULE__{metadata: metadata, message: message}) do
    message = interpolate(message, metadata)

    positions =
      metadata
      |> Keyword.get_values(:position)
      |> List.wrap()
      |> Enum.reduce(:first, fn
        position, :first -> position_to_string(position)
        position, acc -> [acc, joiner(position) | position_to_string(position)]
      end)

    if positions == :first do
      message
    else
      IO.iodata_to_binary([positions, " ", message])
    end
  end

  def interpolate(text, binding) do
    text
    |> interpolate(0, byte_size(text), binding)
    |> IO.iodata_to_binary()
  end

  defp interpolate(text, start, length, binding) do
    case :binary.match(text, "%{", scope: {start, length - start}) do
      {before_var, _} ->
        part_before = binary_part(text, start, before_var - start)
        start_var = before_var + 2
        after_scope = {start_var, length - start_var}
        {after_var, _} = :binary.match(text, "}", scope: after_scope)
        var = binary_part(text, start_var, after_var - start_var)
        value = Keyword.fetch!(binding, String.to_existing_atom(var))
        start = after_var + 1
        [part_before, to_string(value) | interpolate(text, start, length, binding)]

      :nomatch ->
        [binary_part(text, start, length - start)]
    end
  end

  defp position_to_string({:key, key}) when is_atom(key) do
    Atom.to_string(key)
  end

  defp position_to_string({:key, key}) when is_binary(key) do
    [?", key, ?"]
  end

  defp position_to_string({:index, index}) do
    [?[, Integer.to_string(index), ?]]
  end

  defp joiner({:key, _}), do: "."
  defp joiner({:index, _}), do: ""

  @doc false
  def new(predicate) when is_function(predicate, 1) do
    {message, metadata} = message_from_predicate(predicate)

    new(predicate, message, metadata)
  end

  @doc false
  def new(validator, message, metadata \\ []) do
    %__MODULE__{
      validator: validator,
      message: message,
      metadata: metadata
    }
  end

  @doc false
  def add_position(error, position) do
    metadata = [position: position] ++ error.metadata

    %{error | metadata: metadata}
  end

  @doc false
  def maybe_update_message(%__MODULE__{} = error, nil), do: error
  def maybe_update_message(%__MODULE__{} = error, message), do: %{error | message: message}

  @doc false
  def message_from_predicate(predicate) do
    cond do
      predicate == (&String.valid?/1) ->
        {"must be a string", [kind: :is_string]}

      predicate == (&is_binary/1) ->
        {"must be a binary", [kind: :is_binary]}

      predicate == (&is_integer/1) ->
        {"must be an integer", [kind: :is_integer]}

      predicate == (&is_boolean/1) ->
        {"must be a boolean", [kind: :is_boolean]}

      predicate == (&is_float/1) ->
        {"must be a float", [kind: :is_float]}

      predicate == (&is_number/1) ->
        {"must be a number", [kind: :is_number]}

      predicate == (&is_map/1) ->
        {"must be a map", [kind: :is_map]}

      predicate == (&is_list/1) ->
        {"must be a list", [kind: :is_list]}

      predicate == (&is_atom/1) ->
        {"must be an atom", [kind: :is_atom]}

      true ->
        {"is invalid", [kind: :predicate]}
    end
  end
end
