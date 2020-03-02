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

  @doc """
  Looking for record in storage entries list and if found return them with storage entry position, also return `nil`
  """
  @spec get_record(__MODULE__.t(), integer()) :: {integer(), Record.t()} | nil
  def get_record(%Passme.Chat.Storage{entries: entries}, record_id) do
    entries
    |> Enum.find(nil, fn {_entry_id, entry} ->
      entry.id == record_id
    end)
  end

  @doc """
  Replace entry in storage by `entry_id` (not record id), wich сan be obtained from `get_record/2`
  """
  def update(%Passme.Chat.Storage{entries: entries} = storage, entry_id, entry) do
    new_entries = Map.put(entries, entry_id, entry)
    Map.put(storage, :entries, new_entries)
  end

  def entries(%__MODULE__{} = storage) do
    Map.get(storage, :entries)
  end

  def entries_list(%__MODULE__{} = storage) do
    storage
    |> Map.get(:entries)
    |> Map.values()
  end

  def active_entries(storage) do
    storage
    |> entries()
    |> Enum.filter(fn {_, x} ->
      not Record.archived?(x)
    end)
  end
end
