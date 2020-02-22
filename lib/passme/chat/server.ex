defmodule Passme.Chat.Server do
  @moduledoc """
  Module represents process for telegram chat
  """
  use GenServer, restart: :temporary

  import Logger

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

  ########### Client ###########

  def get_state(chat_id) do
    get_chat_process(chat_id)
    |> GenServer.call(:get_state)
  end

  def print_list(chat_id) do
    get_chat_process(chat_id)
    |> GenServer.cast(:list)
  end

  def handle_command(chat_id, command, data) do
    get_chat_process(chat_id)
    |> GenServer.cast({:command, command, data})
  end

  ## Scripts actions ##

  def input_handler(chat_id, text, context) do
    get_chat_process(chat_id)
    |> GenServer.cast({:input, text, context})
  end

  def next_step(chat_id, step, context) do
    get_chat_process(chat_id)
    |> GenServer.cast({:next_step, step, context})
  end

  def script_new_record(chat_id, context) do
    get_chat_process(chat_id)
    |> GenServer.cast({:new_record, context})
  end

  def script_record_edit(chat_id, context, type, record_id) do
    get_chat_process(chat_id)
    |> GenServer.cast({:record_edit, type, record_id, context})
  end

  def script_record_action(chat_id, context, type, record_id) do
    get_chat_process(chat_id)
    |> GenServer.cast({:record_action, type, record_id, context})
  end

  def script_abort(chat_id) do
    get_chat_process(chat_id)
    |> GenServer.call(:script_abort)
  end

  ## Records actions ##

  def show_record(chat_id, rec_id, context) do
    get_chat_process(chat_id)
    |> GenServer.cast({:show_record, rec_id, context})
  end

  def add_record_to_chat(chat_id, script, context) do
    get_chat_process(chat_id)
    |> GenServer.cast({:add_record, script, context})
  end

  def update_chat_record(chat_id, fields) do
    get_chat_process(chat_id)
    |> GenServer.cast({:update_record, fields})
  end

  ########### Server ###########

  def handle_call(:script_abort, _from, {_, _, script} = state) when is_nil(script) do
    {:reply, :error, state}
  end

  def handle_call(:script_abort, _from, {chat_id, storage, script}) do
    Script.abort_wr(script)
    {:reply, :ok, {chat_id, storage, nil}}
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

  def handle_call({:get_record, record_id}, _from, state) do
    record =
      Enum.find(nil, fn {_storage_id, entry} ->
        entry.id == record_id
      end)

    {:reply, record, state}
  end

  def handle_cast({:update_record, fields}, state) do
    {chat_id, storage, script} = state

    new_entries =
      storage.entries
      |> Enum.find(nil, fn {_storage_id, entry} ->
        entry.id == fields.record_id
      end)
      |> case do
        {storage_id, storage_record} ->
          storage_record
          |> Passme.update_record(fields)
          |> case do
            {:ok, record} ->
              ExGram.send_message(chat_id, "RMM.Chat: Record updated")
              Map.put(storage.entries, storage_id, record)

            {:error, changeset} ->
              debug(changeset)
              ExGram.send_message(chat_id, "RMM.Chat: Error on updating record")
              storage.entries
          end

        nil ->
          ExGram.send_message(chat_id, "RMM.Chat: Record not found in this chat")
      end

    {:noreply, {chat_id, Map.put(storage, :entries, new_entries), script}}
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

  def handle_cast({:show_record, record_id, _data}, state) do
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

  def handle_cast({:record_edit, _, _, _}, {chat_id, _, script} = state)
      when not is_nil(script) do
    ExGram.send_message(chat_id, "Error: currently working another script")
    {:noreply, {chat_id, state}}
  end

  def handle_cast({:record_edit, key, record_id, data}, state) do
    {chat_id, storage, _} = state

    # Record in chat storage
    new_script =
      if data.message.chat.id == data.from.id do
        storage.entries
      else
        {_, chat_storage, _} = Passme.Chat.Server.get_state(data.message.chat.id)
        chat_storage.entries
      end
      |> Enum.find(nil, fn {_storage_id, entry} ->
        entry.id == record_id
      end)
      # Check for record field availability
      |> case do
        {_, _} -> Passme.Chat.Storage.Record.has_field?(key)
        nil -> false
      end
      # TODO Check user can edit this record
      |> if do
        # Start edit script, what waiting for input
        struct =
          Map.put(%{}, key, nil)
          |> Map.put(:record_id, record_id)
          |> Map.put(:_field, key)

        start_script(Passme.Chat.Script.RecordFieldEdit, data.from, data.message.chat, struct)
      end

    {:noreply, {chat_id, storage, new_script}}
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
    new_state =
      case Script.set_step_result(script, text) do
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
    {chat_id, storage, _script} = state
    ExGram.send_message(chat_id, "Input timeout. Action was cancelled.")
    {:noreply, {chat_id, storage, nil}}
  end

  #######

  defp get_chat_process(chat_id) do
    Passme.Chat.Supervisor.get_chat_process(chat_id)
  end

  def start_script(module, user, chat) do
    script = apply(module, :new, [user, chat])
    {:ok, script} = Script.start_step(script)
    script
  end

  def start_script(module, user, chat, struct) do
    script = apply(module, :new, [user, chat, struct])
    {:ok, script} = Script.start_step(script)
    script
  end
end
