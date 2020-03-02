defmodule Passme.ChatStorageTest do
  use ExUnit.Case

  alias Passme.Chat.Storage

  @record_1 %{
    id: 100,
    name: "record 1",
    value: "1",
    archived: false
  }
  @record_2 %{
    id: 200,
    name: "record 2",
    value: "2",
    archived: false
  }
  @record_3 %{
    id: 300,
    name: "record 3",
    value: "3",
    archived: true
  }
  @record_4 %{
    value: "4",
    archived: nil
  }

  @records [@record_1, @record_2, @record_3]
  @with_incorrect_record [@record_1, @record_4]

  describe "Chat.Storage" do
    test "new/1 return new Storage struct with given records in entries" do
      storage = Storage.new(@records)

      assert Enum.all?(@records, fn x ->
               {_, _} = Storage.get_record(storage, x.id)
               true
             end)
    end

    test "put_record/2 push given record to entries" do
      storage =
        Storage.new([@record_1, @record_3])
        |> Storage.put_record(@record_2)

      entries = Storage.entries(storage)
      Enum.any?(entries, &(@record_2 == &1))
      assert Enum.count(entries) == 3
    end

    test "get_record/2 must return tuple with index in storage and entry" do
      storage = Storage.new(@records)
      {_index, record} = Storage.get_record(storage, @record_3.id)
      assert record.name == @record_3.name
    end

    test "get_record/2 return nil with unknown requested id" do
      assert Storage.new(@records)
             |> Storage.get_record(9_999_199)
             |> is_nil()
    end

    test "entries/1 return list with record as tuples with their indexes in storage" do
      assert Storage.new(@records)
             |> Storage.entries()
             |> Enum.all?(fn
               {_index, _record} ->
                 true
             end)
    end

    test "entries_list/1 return list of records" do
      assert Storage.new(@records)
             |> Storage.entries_list()
             |> is_list()
    end

    test "active_entries/1 returns records only with key archived: false" do
      Storage.new(@records)
      |> Storage.active_entries()
      |> Enum.each(fn {_, record} ->
        refute record.archived
      end)
    end
  end
end
