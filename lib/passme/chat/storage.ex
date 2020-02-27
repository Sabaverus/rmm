defmodule Passme.Chat.Storage do
  @moduledoc false
  defstruct auto_id: 0, entries: %{}

  alias Passme.Chat.Storage.Record

  def new(records \\ []) do
    Enum.reduce(
      records,
      %__MODULE__{},
      &put_record(&2, &1)
    )
  end

  @spec put_record(__MODULE__.t(), Record.t()) :: __MODULE__.t()
  def put_record(storage, record) do
    entry = Map.put(record, :storage_id, storage.auto_id)
    entries = Map.put(storage.entries, storage.auto_id, entry)

    %__MODULE__{
      auto_id: storage.auto_id + 1,
      entries: entries
    }
  end

  @spec get_record(__MODULE__.t(), integer()) :: {integer(), Record.t()} | nil
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
