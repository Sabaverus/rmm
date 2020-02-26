defmodule Passme.Chat.Server do
  @moduledoc """
  Module represents process for telegram chat
  """
  use GenServer, restart: :temporary

  import Logger

  alias Passme.Chat.Storage.Record, as: Record
  alias Passme.Chat.ChatActivity, as: Metrica
  alias Passme.Chat.Script, as: Script
  alias Passme.Chat.State, as: State

  @expiry_idle_timeout :timer.seconds(30)

  @spec init(any) :: {:ok, Passme.Chat.State.t(), 30_000}
  def init(chat_id) do
    storage =
      Passme.Chat.chat_records(chat_id)
      |> Passme.Chat.Storage.new()

    {:ok, State.new(chat_id, storage), @expiry_idle_timeout}
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
    |> GenServer.cast({:record_action, {type, record_id}, context})
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

  def add_record_to_chat(chat_id, record, user \\ nil) do
    get_chat_process(chat_id)
    |> GenServer.cast({:add_record, record, user})
  end

  def update_chat_record(chat_id, fields) do
    get_chat_process(chat_id)
    |> GenServer.cast({:update_record, fields})
  end

  def archive_record(chat_id, storage_id) do
    get_chat_process(chat_id)
    |> GenServer.cast({:archive_record, storage_id})
  end

  ########### Server ###########

  def handle_call(:script_abort, _from, %{script: script} = state) when is_nil(script) do
    {:reply, :error, state, @expiry_idle_timeout}
  end

  def handle_call(:script_abort, _from, state) do
    {:reply, :ok, State.script_abort(state), @expiry_idle_timeout}
  end

  def handle_call({:command, _cmd, data}, _from, state) do
    ExGram.send_message(data[:chat][:id], "Test MarkdownV2 /r\\_2 [Record](/r_2)",
      parse_mode: "MarkdownV2"
    )

    ExGram.send_message(data[:chat][:id], "Test HTML /r_2 <a href=\"/r_2\">Record</a>",
      parse_mode: "HTML"
    )

    {:reply, [], state, @expiry_idle_timeout}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state, @expiry_idle_timeout}
  end

  def handle_cast({:update_record, fields}, state) do
    IO.inspect(fields)
    new_entries =
      state.storage
      |> Passme.Chat.Storage.get_record(fields.record_id)
      |> case do
        {storage_id, storage_record} ->
          storage_record
          |> Passme.Chat.update_record(fields)
          |> case do
            {:ok, record} ->
              ExGram.send_message(state.chat_id, "RMM.Chat: Record updated")
              Map.put(state.storage.entries, storage_id, record)

            {:error, changeset} ->
              IO.inspect(changeset)
              ExGram.send_message(state.chat_id, "RMM.Chat: Error on updating record")
              state.storage.entries
          end

        nil ->
          ExGram.send_message(state.chat_id, "RMM.Chat: Record not found in this chat")
      end
    new_storage = Map.put(state.storage, :entries, new_entries)
    {:noreply, Map.put(state, :storage, new_storage), @expiry_idle_timeout}
  end

  def handle_cast({:archive_record, storage_id}, state) do

    %{storage: storage} = state

    entry = Map.get(storage.entries, storage_id)

    new_storage =
      if entry do
        case Passme.Chat.archive_record(entry) do
          {:ok, entry} ->
            ExGram.send_message(state.chat_id, "Record deleted")
            # Because user can't delete entry, only set flag "archived"
            Passme.Chat.Storage.update(storage, storage_id, entry)
          {:error, changeset} ->
            ExGram.send_message(state.chat_id, "Error on deleting record")
            debug(changeset)
            storage
        end
      else
        storage
      end

    {:noreply, Map.put(state, :storage, new_storage), @expiry_idle_timeout}
  end

  def handle_cast({:new_record, context}, state) do
    Metrica.request(context, state)
    {
      :noreply,
      Map.put(
        state,
        :script,
        start_script(Passme.Chat.Script.NewRecord, context.from, context.message.chat, %Record{})
      ),
      @expiry_idle_timeout
    }
  end

  @spec handle_cast({:add_record, Passme.Chat.Storage.Record.t(), map() | nil}, Passme.Chat.State.t())
        :: {:noreply, Passme.Chat.State.t(), non_neg_integer()}
  def handle_cast({:add_record, record, user}, state) do
    case user do
      %{id: user_id, username: name} ->
        {text, opts} = Passme.Chat.Interface.record_link(record)
        ExGram.send_message(
          user_id,
          "Record\n#{record.name} => #{text}\nwas added ✅",
          opts
        )

        if state.chat_id !== user_id do
          ExGram.send_message(
            state.chat_id,
            "Record\n#{record.name} => #{text}\nwas added by user @#{name}",
            opts
          )
        end
      _ -> nil
    end

    new_storage =
      Passme.Chat.State.get_storage(state)
      |> Passme.Chat.Storage.put_record(record)
    {:noreply, Map.put(state, :storage, new_storage), @expiry_idle_timeout}
  end

  @spec handle_cast({:show_record, non_neg_integer(), map()}, Passme.Chat.State.t())
        :: {:noreply, Passme.Chat.State.t(), non_neg_integer()}
  def handle_cast({:show_record, record_id, context}, state) do
    Metrica.request(context, state)
    spawn(fn ->
      case Passme.Chat.chat_record(record_id, state.chat_id) do
        %Record{} = record ->
          {text, opts} = Passme.Chat.Interface.record(record)
          ExGram.send_message(state.chat_id, text, opts)

        _ ->
          ExGram.send_message(state.chat_id, "Message not found")
      end
    end)
    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:record_edit, _, _, _}, %{script: script} = state)
      when not is_nil(script) do
    ExGram.send_message(state.chat_id, "Error: currently working another script")
    {:noreply, state, @expiry_idle_timeout}
  end

  @spec handle_cast({:record_edit, atom(), non_neg_integer(), map()}, Passme.Chat.State.t())
        :: {:noreply, Passme.Chat.State.t(), non_neg_integer()}
  def handle_cast({:record_edit, key, record_id, data}, state) do
    pu = data.from
    pc = data.message.chat

    Metrica.request(data, state)

    script =
      Passme.Chat.record(record_id)
      |> case do
        nil ->
          ExGram.send_message(state.chat_id, "Record doesn't exists")
          nil

        record ->
          with  true <- Passme.Chat.Storage.Record.has_field?(key),
                true <- State.user_in_chat?(record.chat_id, pu.id) do
                # Check here user can edit this record
            data =
              Map.put(%{}, key, nil)
              |> Map.put(:record_id, record_id)
              |> Map.put(:_field, key)

            start_script(Passme.Chat.Script.RecordFieldEdit, pu, pc, data)
          else
            _ ->
              ExGram.send_message(state.chat_id, "Not allowed to edit this record")
              nil
          end
      end

    {:noreply, Map.put(state, :script, script), @expiry_idle_timeout}
  end

  def handle_cast({:record_action, {:delete, record_id}, data}, state) do
    Metrica.request(data, state)
    pu = data.from

    Passme.Chat.record(record_id)
    |> case do
      nil -> ExGram.send_message(state.chat_id, "Record doesn't exists")

      record ->
        with state <- Passme.Chat.Server.get_state(record.chat_id),
             true <- State.user_in_chat?(state, pu.id),
             {storage_id, _} <- Passme.Chat.Storage.get_record(state.storage, record_id) do
              # Check here user can edit this record

          Passme.Chat.Server.archive_record(record.chat_id, storage_id)
        else
          _ -> ExGram.send_message(state.chat_id, "Not allowed to edit this record")
        end
    end

    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:record_action, _, _}, state) do
    ExGram.send_message(state.chat_id, "Action is not defined")
    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast(:list, state) do
    {text, opts} = Passme.Chat.Interface.list(state.storage.entries)
    ExGram.send_message(state.chat_id, text, opts)
    {:noreply, state, @expiry_idle_timeout}
  end

  # Enter if awaiter (script) is not null
  def handle_cast({:input, text, context}, %{script: script} = state)
      when not is_nil(script) do

    Metrica.request(context, state)

    new_state =
      case Script.set_step_result(script, text) do
        {:ok, script} ->

          {status, script} =
            script
            |> Script.next_step()
            |> Script.start_step()

          if status == :end do
            state
            |> Map.put(:script, script)
            |> Script.end_script()
          else
            state
            |> Map.put(:script, script)
          end

        {:error, message} ->
          ExGram.send_message(state.chat_id, message)
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
    ExGram.send_message(state.chat_id, "Input timeout. Action was cancelled.")
    {:noreply, Map.put(state, :script, nil)}
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
