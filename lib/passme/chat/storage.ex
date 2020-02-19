defmodule Passme.Chat.Storage do
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
end
