defmodule Passme.ScriptNewRecordTest do
  use Passme.DataCase

  alias Passme.Chat.State
  alias Passme.Chat.Script
  alias Passme.Chat.Storage
  alias Passme.Chat.Script.NewRecord

  @chat %{
    id: :rand.uniform(1_000_000_000)
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
    test "end_script/1 must push prepared data to Chat.Server.add_record_to_chat/3" do
      {:ok, script} =
        script_new_record()
        |> Script.set_step_result(@record.name)

      {:ok, script} =
        script
        |> Script.next_step()
        |> Script.set_step_result(@record.value)

      script
      |> Script.next_step()
      |> Script.end_script()

      state = Passme.Chat.Server.state(@chat.id)
      storage = State.get_storage(state)

      assert Storage.entries(storage)
             |> Enum.any?(fn {_, x} ->
               x.name == @record.name and
                 x.value == @record.value and
                 not is_nil(x.id)
             end)
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
