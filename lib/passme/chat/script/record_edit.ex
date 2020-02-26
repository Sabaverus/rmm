defmodule Passme.Chat.Script.RecordFieldEdit do
  @moduledoc false

  import Passme.Chat.Util

  defp get_field_key(%{data: %{_field: field}}) do
    field
  end

  use Passme.Chat.Script.Base,
    steps: [
      {:field,
       %{
         text: "Enter new value for selected field",
         next: :end,
         validate: &validate(&1)
       }},
      {:end,
       %{
         text: "Field updated!"
       }}
    ]

  def abort(script) do
    %{
      parent_user: pu,
      parent_chat: pc
    } = script

    reply(pu, pc, "Record field edit has been cancelled")
  end

  def end_script(state) do
    Passme.Chat.Server.update_chat_record(state.script.parent_chat.id, state.script.data)
    state
    |> Map.put(:script, nil)
  end

  defp validate(value) do
    if is_bitstring(value) do
      :ok
    else
      {:error, "Given value must be type of String"}
    end
  end
end
