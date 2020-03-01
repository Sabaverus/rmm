defmodule Passme.EditRecordTest do
  use Passme.DataCase

  alias Passme.Chat
  alias Passme.Chat.Script
  alias Passme.Chat.Script.RecordFieldEdit

  @record %{
    name: "record name",
    value: "some value"
  }
  @chat %{
    id: 1
  }
  @user %{
    id: 42,
    username: "TestUser"
  }

  describe "Edit record" do

    test "on create must store previous value" do
      {:ok, record} = Chat.create_chat_record(@record)

      script = script_edit_record(record, :name)
      assert Map.get(script.data, :previous) == @record.name
    end

    test "set_step_result/2 must store value for dynamic key" do
      {:ok, record} = Chat.create_chat_record(@record)

      script = script_edit_record(record, :name)

      {:ok, script} = Script.set_step_result(script, "new name")
      assert Map.get(script.data, :name) == "new name"
    end

    test "end_script/1 must send request to update record" do
      {:ok, record} = Chat.create_chat_record(@record)

      script = script_edit_record(record, :name)

      {:ok, pid} = Passme.Chat.Server.start_link(@chat.id)

      :erlang.trace(pid, true, [:receive])

      {:ok, script} = Script.set_step_result(script, "new name")
      script =
        script
        |> Script.next_step()
        |> Script.end_script()

      assert_receive {:trace, ^pid, :receive, {_, {:update_record, fields}}}
      assert Map.get(fields, :name) == "new name"
    end

    test "initial_data/2 must store edited key in record to script.data[:_field]" do
      {:ok, record} = Chat.create_chat_record(@record)
      data = RecordFieldEdit.initial_data(record, :name)
      assert Map.get(data, :_field) == :name
    end

    test "overriden get_field_key/1 must return correct key for set_step_value/1" do
      {:ok, record} = Chat.create_chat_record(@record)
      script = script_edit_record(record, :name)

      assert RecordFieldEdit.get_field_key(script) == :name
    end

  end

  def script_edit_record(record, key) do
    Script.start_script(
      RecordFieldEdit,
      @user,
      @chat,
      RecordFieldEdit.initial_data(record, key)
    )
  end
end
