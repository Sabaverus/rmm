defmodule Passme.Chat.Script.NewRecord do
  @moduledoc false

  import Passme.Chat.Util

  use Passme.Chat.Script.Base,
    steps: [
      {:key,
       %{
         text: "Enter record key",
         next: :value
       }},
      {:value,
       %{
         text: "Enter record value",
         next: :desc
       }},
      {:desc,
       %{
         text: "Enter description of record",
         next: :end
       }}
    ]

  def abort(script) do
    %{
      parent_user: pu,
      parent_chat: pc
    } = script

    reply(pu, pc, "Adding new record has been cancelled")
  end

  def end_script(state) do
    new_storage =
      state.script.record
      |> Map.put(:author, state.script.parent_user.id)
      |> Map.put(:chat_id, state.script.parent_chat.id)
      |> Passme.Chat.create_chat_record()
      |> case do
        {:ok, entry} ->
          # Add record to chat where script is started
          Passme.Chat.Server.add_record_to_chat(state.script.parent_chat.id, entry, state.script.parent_user)

        {:error, _changeset} ->
          reply(state.script.parent_user, state.script.parent_chat, "Error while adding new record")
          state.storage
      end

    # Return new chat state
    state
    |> Map.put(:storage, new_storage)
    # Script cleanup
    |> Map.put(:script, nil)
  end
end
