defmodule Vaxin.ErrorTest do
  use ExUnit.Case, async: true

  alias Vaxin.Error

  describe "message/1" do
    test "handles positions" do
      error = %Error{
        message: "is invalid",
        metadata: [
          kind: :less_than,
          number: 1,
          position: {:key, :data},
          position: {:index, 3},
          position: {:key, :foo}
        ],
        validator: :number
      }

      assert Error.message(error) == "data[3].foo is invalid"
    end

    test "handles interpolation" do
      error = %Error{
        message: "should be greater than %{value}",
        metadata: [value: 1, foo: :bar],
        validator: :number
      }

      assert Error.message(error) == "should be greater than 1"
    end
  end
end
