defmodule Passme.Chat.Script.Step do
  @moduledoc """
  Script step structure
  """
  @type t :: %__MODULE__{
          message: binary() | Map.t(),
          next: atom(),
          validate: fun(any()) | nil,
          can_be_empty: fun(Passme.Chat.Script.t()) | boolean(),
          field: atom() | nil
        }

  defstruct message: nil,
            next: nil,
            validate: nil,
            can_be_empty: false,
            field: nil,
            type: :string

  def new(message, next, opts \\ []) do
    %__MODULE__{
      message: message,
      next: next
    }
    |> Map.merge(Enum.into(opts, %{}))
  end
end
