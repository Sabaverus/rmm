defmodule Passme.Chat.Storage do
  @moduledoc false
  defstruct auto_id: 0, entries: %{}

  def new(records \\ []) do
    Enum.reduce(
      records,
      %Passme.Chat.Storage{},
      &put_record(&2, &1)
    )
  end

  def put_record(storage, record) do
    entry = Map.put(record, :storage_id, storage.auto_id)
    entries = Map.put(storage.entries, storage.auto_id, entry)

    %Passme.Chat.Storage{
      auto_id: storage.auto_id + 1,
      entries: entries
    }
  end

  @spec get_record(%Passme.Chat.Storage{}, integer()) :: {integer(), %Passme.Chat.Storage.Record{}} | nil
  def get_record(%Passme.Chat.Storage{entries: entries}, record_id) do
    entries
    |> Enum.find(nil, fn {_storage_id, entry} ->
      entry.id == record_id
    end)
  end

  def update(%Passme.Chat.Storage{entries: entries} = storage, entry_id, entry) do
    new_entries = Map.put(entries, entry_id, entry)
    Map.put(storage, :entries, new_entries)
  end
end
