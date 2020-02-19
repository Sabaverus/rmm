defmodule Passme.Chat.Server do

  use GenServer, restart: :temporary
  @expiry_idle_timeout :timer.seconds(30)

  def init(chat_id) do
    {
      :ok,
      {
        chat_id,
        Passme.get_chat_records(chat_id) || Passme.Chat.Storage.new([]),
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

  def add_record_to_chat(pid, record, context) do
    GenServer.cast(pid, {:add_record, record, context})
  end

  # Server

  def handle_call({:command, cmd, data}, _from, state) do
    {uid, _storage, _await} = state
    ExGram.send_message(data[:chat][:id], "Rtv #{cmd} from #{uid}")
    ExGram.send_message(data[:chat][:id], "Second Rtv #{cmd} from #{uid}")
    IO.inspect(state)

    Process.send_after(self(), {:async, "Async Rtv #{cmd} from #{uid} after 3 seconds"}, 3000)

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
        start_script(context.from, context.message.chat)
      },
      @expiry_idle_timeout
    }
  end

  def handle_cast({:add_record, record, _context}, state) do
    {chat_id, storage, script} = state
    new_storage =
      record
      |> Map.put(:author, script.parent_user.id)
      |> Map.put(:chat_id, script.parent_chat.id)
      |> Passme.create_chat_record()
      |> case do
        {:ok, entry} ->
          ExGram.send_message(chat_id, "Record added!")
          Passme.Chat.Storage.put_record(storage, entry)
        {:error, _changeset} ->
          ExGram.send_message(chat_id, "Error adding new record")
          storage
    end
    {
      :noreply,
      {
        chat_id,
        new_storage,
        script
      }
    }
  end

  def handle_cast(:list, state) do
    {chat_id, storage, _script} = state
    text = Enum.reduce(storage.entries, "List of entries:", fn
      {_id, v}, acc ->
        acc <> "\nKey: #{v.key}\nValue: #{v.value}\nDescription: #{v.desc}\n"
    end)
    ExGram.send_message(chat_id, text)
    {:noreply, state, @expiry_idle_timeout}
  end

  # Enter if awaiter (script) is not null
  def handle_cast(
    {:input, text, context},
    {chat_id, storage, script}
  ) when not is_nil(script) do
    new_script = case Passme.Chat.ChatScript.set_step_result(script, text) do
      {:ok, script} ->
        {status, script} =
          script
          |> Passme.Chat.ChatScript.next_step()
          |> Passme.Chat.ChatScript.start_step()
        if status == :end do
          add_record_to_chat(self(), script.record, context)
        end
        script
      {:error, message} ->
        ExGram.send_message(chat_id, message)
        script
    end
    {
      :noreply,
      {
        chat_id,
        storage,
        new_script
      },
      @expiry_idle_timeout
    }
  end

  def handle_info({:async, msg}, state) do
    {chat_id, _storage, _await} = state
    ExGram.send_message(chat_id, msg)
    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_info({_ref, {:noreply, _data}}, state) do
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    # {chat_id, _storage, _await} = state
    # ExGram.send_message(chat_id, "#{@expiry_idle_timeout / 1000} seconds timeout, chat process is down")
    {:stop, :normal, state}
  end

  def handle_info(:await_input_timeout, state) do
    {chat_id, storage, _await} = state
    ExGram.send_message(chat_id, "Таймаут ожидания ввода")
    {:noreply, {chat_id, storage, nil}}
  end

  #######

  def start_script(user, chat) do
    {:ok, script} =
      Passme.Chat.ChatScript.new(user, chat)
      |> Passme.Chat.ChatScript.start_step()
    script
  end
end
