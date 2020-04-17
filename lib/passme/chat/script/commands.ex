defmodule Passme.Chat.Script.Commands do
  @moduledoc false

  def get(cmd) when is_atom(cmd) do
    case cmd do
      :callback ->
        "script_cb"

      :abort ->
        "script_abort"

      :clean ->
        "script_clean"
    end
  end

  def route(%{data: "script_" <> cmd} = data) do
    case cmd do
      "cb_" <> input ->
        Passme.Chat.Server.handle_input(data.from.id, input)

      "clean" ->
        Passme.Chat.Server.handle_input(data.from.id, nil)

      "abort" ->
        Passme.Chat.Server.script_abort(data.from.id)
    end
  end
end
