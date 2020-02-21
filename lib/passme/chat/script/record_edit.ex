defmodule Passme.Chat.ChatScript.EditRecord do
  @moduledoc false

  import Passme.Chat.Util

  use Passme.Chat.Script.Base,
    steps: [
      {:field,
       %{
         text: "Enter new value for selected field",
         next: :value
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
    reply(pu, pc, "Cancelled")
  end

  def end_script({chat_id, storage, _script}) do
    {chat_id, storage, nil}
  end
end
