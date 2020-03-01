defmodule Passme.ScriptTest do
  use Passme.DataCase

  alias Passme.Chat.State
  alias Passme.Chat.Script
  alias Passme.Chat.Script.Step
  alias Passme.Chat.Storage
  alias Passme.Chat.Script.RecordFieldEdit

  @chat %{
    id: 1
  }
  @user %{
    id: 42,
    username: "TestUser"
  }
  @step_one Step.new("Step one text", :step_two)
  @step_two Step.new("Step two text", :end, field: :some_field)

  describe "scripts" do

    test "If script at end they must know it" do
      assert true == script_test()
      |> Script.next_step()
      |> Script.next_step()
      |> Script.end?
    end

    test "check_next_step" do
      script = script_test()
      |> Script.next_step()

      {step_key, step} = script.step
      assert step_key == :step_two
      assert step == @step_two

      script = Script.next_step(script)
      assert :end == script.step
    end

    test "Check creating new script" do
      script = script_test()
      {step_key, step} = script.step

      # Timer for script input timeout must be started
      assert 0 <= Process.read_timer(script.timer)

      # And on start script must contain first step as current
      assert step == @step_one
      assert step_key == :step_one
    end

    test "Set step result for two steps" do
      {:ok, script} =
        script_test()
        |> Script.set_step_result("some value")

      assert Map.get(script.data, :step_one) == "some value"

      {:ok, script} =
        script
        |> Script.next_step()
        |> Script.set_step_result("step value 2")

      assert Map.get(script.data, :some_field) == "step value 2"
    end

    test "Script on abort must cancel timer" do
      script =
        script_test()
        |> Script.abort_wr()

      assert false == Process.read_timer(script.timer)
    end

  end



  def test_state(script) do
    State.new(
      @chat.id,
      Storage,
      script
    )
  end

  def script_test() do
    Script.start_script(Passme.Test.ChatScriptCorrect, @user, @chat, %{
      step_one: nil,
      some_field: "some value"
    })
  end

  def script_new_record() do
    Script.start_script(
      Passme.Chat.Script.NewRecord,
      @user,
      @chat
    )
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

defmodule Passme.Test.ChatScriptCorrect do

  alias Passme.Chat.Script.Step

  use Passme.Chat.Script.Base,
    steps: [
      {:step_one, Step.new("Step one text", :step_two)},
      {:step_two, Step.new("Step two text", :end, field: :some_field)}
    ]

  def abort(script), do: script

  def end_script(script), do: script
end
