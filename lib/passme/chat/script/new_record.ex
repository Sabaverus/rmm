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

  def end_script({chat_id, storage, script}) do

    %{
      parent_user: pu,
      parent_chat: pc
    } = script

    new_storage =
      script.record
      |> Map.put(:author, script.parent_user.id)
      |> Map.put(:chat_id, script.parent_chat.id)
      |> Passme.create_chat_record()
      |> case do
        {:ok, entry} ->

          reply(pu, pc, "Record was added")

          if pc.id !== pu.id do
            reply(pc, pc, "Record was added by user @#{pu.username}")
          end

          Passme.Chat.Storage.put_record(storage, entry)

        {:error, _changeset} ->
          reply(pu, pc, "Error while adding new record")
          storage
      end
    # Return new chat state
    {
      chat_id, new_storage, nil
    }
  end
end
