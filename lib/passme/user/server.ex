defmodule Passme.User.Server do

  use GenServer, restart: :temporary
  @expiry_idle_timeout :timer.seconds(30)
  @input_await_time :timer.seconds(10)

  @new_record_script [
    {:key, %{
      text: "Enter record key",
      next: :value
    }},
    {:value, %{
      text: "Enter record value",
      next: :desc
    }},
    {:desc, %{
      text: "Enter description of record",
      next: :end
    }}
  ]

  alias Passme.User.Storage.Record, as: Record

  def init(chat_id) do
    {
      :ok,
      {
        chat_id,
        Passme.get_chat_records(chat_id) || Passme.User.Storage.new([]),
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
    Passme.User.Registry.via_tuple({__MODULE__, chat_id})
  end

  # Client

  def script_new_record(pid, context) do
    GenServer.cast(pid, {:new_record, context})
  end

  def print_list(pid) do
    GenServer.cast(pid, :list)
  end

  def is_wait_for_input(pid) do
    {_, _, awaiter} = GenServer.call(pid, :get_state)
    is_tuple(awaiter)
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
    ExGram.send_message(data[:from][:id], "Rtv #{cmd} from #{uid}")
    ExGram.send_message(data[:from][:id], "Second Rtv #{cmd} from #{uid}")
    IO.inspect(state)

    Process.send_after(self(), {:async, "Async Rtv #{cmd} from #{uid} after 3 seconds"}, 3000)

    {:reply, [], state, @expiry_idle_timeout}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state, @expiry_idle_timeout}
  end

  def handle_cast({:new_record, context}, state) do
    next_step(self(), :key, context)
    {uid, storage, _await} = state
    {
      :noreply,
      {
        uid,
        storage,
        start_awaiter()
      },
      @expiry_idle_timeout
    }
  end

  def handle_cast({:add_record, record, context}, state) do
    {uid, storage, awaiter} = state
    new_storage = record
    |> Map.put(:author, context.from.id)
    |> Map.put(:chat_id, uid)
    |> Passme.create_chat_record()
    |> case do
      {:ok, entry} ->
        ExGram.send_message(uid, "Record added!")
        Passme.User.Storage.put_record(storage, entry)
      {:error, _changeset} ->
        ExGram.send_message(uid, "Error adding new record")
        storage
    end
    {
      :noreply,
      {
        uid,
        new_storage,
        awaiter
      }
    }
  end

  def handle_cast(:list, state) do
    {uid, storage, _await} = state
    text = Enum.reduce(storage.entries, "List of entries:", fn
      {_id, v}, acc ->
        acc <> "\nKey: #{v.key}\nDescription: #{v.desc}\nValue: #{v.value}\n\n"
    end)
    ExGram.send_message(uid, text)
    {:noreply, state, @expiry_idle_timeout}
  end

  # Enter if awaiter (script) is not null
  def handle_cast({:input, text, context}, {chat_id, storage, awaiter}) when not is_nil(awaiter) do

    {timer, current, record} = awaiter

    # Process current step
    new_record = Map.put(record, current, text)

    # Start next step
    step = case get_step(current, @new_record_script) do
      {_, current_step} ->
        next_step(self(), current_step.next, context)
        current_step.next
      :end ->
        next_step(self(), :end, context)
        :end
    end

    {
      :noreply, {
        chat_id,
        storage,
        {timer, step, new_record}
      },
      @expiry_idle_timeout
    }
  end

  # TODO Refactor this
  def handle_cast({:next_step, next_step, context}, {chat_id, storage, awaiter}) do

    {new_storage, new_awaiter} = case start_step(next_step, @new_record_script, chat_id, awaiter) do
      :end when not is_nil(awaiter)->
        {_, _, record} = awaiter
        # If awaiter exists - push last record state to storage and flush script
        add_record_to_chat(self(), record, context)
        {
          storage,
          nil
        }
      :end ->
        {
          storage,
          nil
        }
      {:ok, new_awaiter} ->
        {
          storage,
          new_awaiter
        }
    end
    {
      :noreply, {
        chat_id,
        new_storage,
        new_awaiter
      },
      @expiry_idle_timeout
    }
  end

  def handle_info({:async, msg}, state) do
    {uid, _storage, _await} = state
    ExGram.send_message(uid, msg)
    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_info({_ref, {:noreply, _data}}, state) do
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    {uid, _storage, _await} = state
    ExGram.send_message(uid, "#{@expiry_idle_timeout / 1000} seconds timeout, server for user is down")
    {:stop, :normal, state}
  end

  def handle_info(:await_input_timeout, state) do
    {uid, storage, _await} = state
    ExGram.send_message(uid, "Таймаут ожидания ввода")
    {:noreply, {uid, storage, nil}}
  end

  #######

  defp cancel_timer(timer), do: Process.cancel_timer(timer, async: true, info: false)

  defp reset_input_timer(timer) do
    cancel_timer(timer)
    Process.send_after(self(), :await_input_timeout, @input_await_time)
  end

  def get_step(step, script) do
    Enum.find(script, :end, fn {x, _} ->
      x == step
    end)
  end

  def start_awaiter do
    {
      Process.send_after(self(), :await_input_timeout, @input_await_time),
      :key,
      %Record{}
    }
  end

  defp start_step(key, script, chat_id, {timer, _current, record}) do
    case get_step(key, script) do
      :end ->
        cancel_timer(timer)
        :end
      {:end, step} ->
        ExGram.send_message(chat_id, step.text)
        cancel_timer(timer)
        :end
      {stname, step} ->
        ExGram.send_message(chat_id, step.text)
        new_timer = reset_input_timer(timer)
        {
          :ok,
          {
            new_timer,
            stname,
            record
          }
        }
    end

  end
end
