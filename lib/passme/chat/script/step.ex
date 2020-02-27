defmodule Passme.Chat.Script.Step do
  @moduledoc """
  Script step structure
  """
  @type t :: %__MODULE__{
          text: binary(),
          next: atom(),
          validate: fun(any()) | nil,
          can_be_empty: fun(Passme.Chat.Script.t()) | boolean(),
          field: atom() | nil
        }

  defstruct text: nil, next: nil, validate: nil, can_be_empty: false, field: nil

  @spec new(binary(), atom(), Keyword.t()) :: __MODULE__
  def new(text, next, opts \\ []) do
    %__MODULE__{
      text: text,
      next: next
    }
    |> Map.merge(Enum.into(opts, %{}))
  end
end
