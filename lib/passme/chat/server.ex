defmodule Passme.Chat.Server do
  @moduledoc """
  Module represents process for telegram chat
  """
  use GenServer, restart: :temporary

  alias Passme.Chat.Storage.Record, as: Record
  alias Passme.Chat.Script, as: Script

  @expiry_idle_timeout :timer.seconds(30)

  def init(chat_id) do
    {
      :ok,
      {
        chat_id,
        Passme.chat_records(chat_id) || Passme.Chat.Storage.new([]),
        nil
      },
      @expiry_idle_timeout
    }
  end

  def start_link(chat_id) do
    GenServer.start_link(
      __MODULE__,
      chat_id,
      name: via_tuple(chat_id)
    )
  end

  defp via_tuple(chat_id) do
    Passme.Chat.Registry.via_tuple({__MODULE__, chat_id})
  end

  # Client

  def script_new_record(pid, context) do
    GenServer.cast(pid, {:new_record, context})
  end

  def print_list(pid) do
    GenServer.cast(pid, :list)
  end

  def is_wait_for_input(pid) do
    {_, _, script} = GenServer.call(pid, :get_state)
    script !== nil
  end

  def next_step(pid, step, context) do
    GenServer.cast(pid, {:next_step, step, context})
  end

  def add_record_to_chat(pid, script, context) do
    GenServer.cast(pid, {:add_record, script, context})
  end

  def show_record(pid, rec_id, context) do
    GenServer.cast(pid, {:show_record, rec_id, context})
  end

  def script_record_edit(pid, context, type, record_id) do
    GenServer.cast(pid, {:record_edit, type, record_id, context})
  end

  def script_record_action(pid, context, type, record_id) do
    GenServer.cast(pid, {:record_edit, type, record_id, context})
  end

  def script_abort(pid) do
    GenServer.call(pid, :script_abort)
  end

  # Server

  def handle_call(:script_abort, _from, {chat_id, storage, script}) do

    Script.abort_wr(script)
    {:reply, :ok, {
      chat_id,
      storage,
      nil
    }}
  end

  def handle_call({:command, _cmd, data}, _from, state) do
    ExGram.send_message(data[:chat][:id], "Test MarkdownV2 /rec\\_2 [Record](/rec_2)",
      parse_mode: "MarkdownV2"
    )

    ExGram.send_message(data[:chat][:id], "Test HTML /rec_2 <a href=\"/rec_2\">Record</a>",
      parse_mode: "HTML"
    )

    {:reply, [], state, @expiry_idle_timeout}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state, @expiry_idle_timeout}
  end

  def handle_cast({:new_record, context}, state) do
    {chat_id, storage, _script} = state

    {
      :noreply,
      {
        chat_id,
        storage,
        start_script(Passme.Chat.Script.NewRecord, context.from, context.message.chat)
      },
      @expiry_idle_timeout
    }
  end

  def handle_cast({:show_record, record_id, _context}, state) do
    {chat_id, _storage, _await} = state

    case Passme.chat_record(record_id, chat_id) do
      %Record{} = record ->
        {text, opts} = Passme.Chat.Interface.record(record)
        ExGram.send_message(chat_id, text, opts)

      _ ->
        ExGram.send_message(chat_id, "Message not found")
    end

    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:record_edit, key, record_id, _data}, state) do
    {chat_id, storage, script} = state

    new_script =
      if script !== nil do
        ExGram.send_message(chat_id, "Error: currently working another script")
        script
      else
        ExGram.send_message(
          chat_id,
          "TODO: start ChatScript by module. Type: #{key} Record: #{record_id}"
        )

        # start_script(arg1, arg2)
        script
      end

    {
      :noreply,
      {chat_id, storage, new_script}
    }
  end

  def handle_cast(:list, state) do
    {chat_id, storage, _script} = state
    {text, opts} = Passme.Chat.Interface.list(storage.entries)
    ExGram.send_message(chat_id, text, opts)
    {:noreply, state, @expiry_idle_timeout}
  end

  # Enter if awaiter (script) is not null
  def handle_cast(
        {:input, text, _context},
        {chat_id, storage, script} = state
      )
      when not is_nil(script) do
    new_state = case Script.set_step_result(script, text) do

      {:ok, script} ->
        {status, script} =
          script
          |> Script.next_step()
          |> Script.start_step()

        if status == :end do
          {^chat_id, storage, script} = Script.end_script({chat_id, storage, script})
          {chat_id, storage, script}
        else
          {chat_id, storage, script}
        end

      {:error, message} ->
        ExGram.send_message(chat_id, message)
        state
    end

    {
      :noreply,
      new_state,
      @expiry_idle_timeout
    }
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def handle_info(:await_input_timeout, state) do
    {chat_id, storage, _await} = state
    ExGram.send_message(chat_id, "Таймаут ожидания ввода")
    {:noreply, {chat_id, storage, nil}}
  end

  #######

  def start_script(module, user, chat) do
    script = apply(module, :new, [user, chat])
    {:ok, script} = Script.start_step(script)
    script
  end
end
