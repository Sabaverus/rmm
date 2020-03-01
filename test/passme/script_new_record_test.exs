defmodule Passme.ScriptNewRecordTest do
  use Passme.DataCase

  alias Passme.Chat.State
  alias Passme.Chat.Script
  alias Passme.Chat.Storage
  alias Passme.Chat.Script.NewRecord

  @chat %{
    id: 1
  }
  @user %{
    id: 42,
    username: "TestUser"
  }
  @record %{
    name: "record name",
    value: "record value"
  }

  describe "New record" do

    test "end_script/1 must add new record and push record to Chat.Server" do

      {:ok, pid} = Passme.Chat.Server.start_link(@chat.id)

      :erlang.trace(pid, true, [:receive])

      {:ok, script} =
        script_new_record()
        |> Script.set_step_result(@record.name)
      {:ok, script} =
        script
        |> Script.next_step()
        |> Script.set_step_result(@record.value)
      script =
        script
        |> Script.next_step()
        |> Script.end_script()

      assert_receive {:trace, ^pid, :receive, {_, {:add_record, record, user}}}

      state = Passme.Chat.Server.get_state(@chat.id)
      {_, record} = Storage.get_record(Map.get(state, :storage), record.id)

      refute is_nil(record)
      refute is_nil(record.id)
      assert record.name == @record.name
      assert record.value == @record.value
    end
  end

  def script_new_record() do
    Script.start_script(
      NewRecord,
      @user,
      @chat
    )
  end
end
