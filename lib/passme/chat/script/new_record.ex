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
    %{
      storage: storage,
      script: script
    } = state
    %{
      parent_user: pu,
      parent_chat: pc
    } = script

    new_storage =
      script.record
      |> Map.put(:author, script.parent_user.id)
      |> Map.put(:chat_id, script.parent_chat.id)
      |> Passme.Chat.create_chat_record()
      |> case do
        {:ok, entry} ->
          reply(pu, pc, "Record was added")

          if pc.id !== pu.id do
            reply(pc, pu, "Record was added by user @#{pu.username}")
          end
          # Record need put to chat state, not current!
          Passme.Chat.Storage.put_record(storage, entry)

        {:error, _changeset} ->
          reply(pu, pc, "Error while adding new record")
          storage
      end

    # Return new chat state
    state
    |> Map.put(:storage, new_storage)
    |> Map.put(:script, nil)
  end
end
