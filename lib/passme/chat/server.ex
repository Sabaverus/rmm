defmodule Passme.Chat.Server do
  @moduledoc """
  Module represents process for telegram chat
  """
  use GenServer, restart: :temporary

  import Logger

  alias Passme.Chat.Script.RecordFieldEdit
  alias Passme.Chat.Storage
  alias Passme.Chat.Storage.Record
  alias Passme.Chat.Script
  alias Passme.Chat.State
  alias Passme.Chat.Permissions
  alias Passme.Chat.Permissions.Request
  alias Passme.Bot

  @expiry_idle_timeout :timer.seconds(60)

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

  @doc """
  Synchronously requested chat state
  """
  def state(chat_id) do
    get_chat_process(chat_id)
    |> GenServer.call(:state)
  end

  def print_list(chat_id) do
    get_chat_process(chat_id)
    |> GenServer.cast(:list)
  end

  def handle_command(chat_id, command, data) do
    get_chat_process(chat_id)
    |> GenServer.cast({:command, command, data})
  end

  @doc """
  Send to telegram chat detailed record by given id
  """
  def print_record(chat_id, id) do
    get_chat_process(chat_id)
    |> GenServer.cast({:action, {:record, id}})
  end

  @doc """
  Process given input
  """
  def handle_input(chat_id, text) do
    get_chat_process(chat_id)
    |> GenServer.cast({:action, {:input, text}})
  end

  ## Scripts actions ##

  @doc """
  Request for start script `Chat.Script.NewRecord` in user-caller process
  """
  @spec script_new_record(integer(), map(), map()) :: :ok
  def script_new_record(chat_id, user, chat) do
    get_chat_process(chat_id)
    |> GenServer.cast({:script, {:new_record, user, chat}})
  end

  @doc """
  Request for start script `Chat.Script.RecordFieldEdit` in user-caller process\n
  Checks given Record id for avaliablity for given chat and user must be related
  """
  @spec script_edit_record(integer(), non_neg_integer(), atom(), map(), map()) :: :ok
  def script_edit_record(chat_id, id, field, user, chat) do
    get_chat_process(chat_id)
    |> GenServer.cast({:script, {:edit_record, id, field, user, chat}})
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

  # get_record

  @doc """
  Accepts `%Record{}` or map with Record fields.

  Creating new record in database with linking to chat process and user.

  User can be nil and Record would be linked only to chat
  """
  @spec create_record(integer(), map(), map() | nil) :: :ok
  def create_record(chat_id, fields, user \\ nil) do
    get_chat_process(chat_id)
    |> GenServer.cast({:record, {:create, fields, user}})
  end

  @doc """
  Checking given Record `id` for avaliablity in chat and updating them if found with given fields
  """
  @spec update_record(integer(), non_neg_integer(), map()) :: :ok
  def update_record(chat_id, id, fields) do
    get_chat_process(chat_id)
    |> GenServer.cast({:record, {:update, id, fields}})
  end

  @doc """
  Push record by id into "archive"

  Record must be related to chat process, also ignored
  """
  @spec archive_record(integer(), non_neg_integer()) :: :ok
  def archive_record(chat_id, id) do
    get_chat_process(chat_id)
    |> GenServer.cast({:record, {:archive, id}})
  end

  ########### Server ###########

  def handle_call(:script_abort, _from, %{script: script} = state) when is_nil(script) do
    {:reply, :error, state, @expiry_idle_timeout}
  end

  def handle_call(:script_abort, _from, state) do
    {:reply, :ok, State.script_abort(state), @expiry_idle_timeout}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state, @expiry_idle_timeout}
  end

  # Print record to chat
  @spec handle_cast({:action, {:record, non_neg_integer()}}, State.t()) ::
          {:noreply, State.t(), non_neg_integer()}
  def handle_cast({:action, {:record, id}}, state) do
    case Passme.Chat.chat_record_not_archived(id, state.chat_id) do
      %Record{} = record ->
        # Проверка на доступность
        if record.private do
          {text, opts} = Passme.Chat.Interface.record_private(record)
          Bot.msg(state.chat_id, text, opts)
        else
          {text, opts} = Passme.Chat.Interface.record(record)
          Bot.msg(state.chat_id, text, opts)
        end

      _ ->
        Bot.msg(state.chat_id, "Record not found")
    end

    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:record, {:update, id, fields}}, state) do
    storage =
      state
      |> State.get_storage()
      |> Storage.get_record(id)
      |> case do
        {entry_id, record} ->
          record
          |> Passme.Chat.update_record(fields)
          |> case do
            {:ok, record} ->
              {link, opts} = Passme.Chat.Interface.record_link(record)
              Bot.msg(state.chat_id, "Record #{link} was updated", opts)

              state
              |> State.get_storage()
              |> Storage.update(entry_id, record)

            {:error, _changeset} ->
              Bot.msg(state.chat_id, "Error on updating record")
              State.get_storage(state)
          end

        nil ->
          Bot.msg(state.chat_id, "Record not found in this chat")
          State.get_storage(state)
      end

    state = Map.put(state, :storage, storage)

    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:record, {:archive, id}}, state) do
    storage = State.get_storage(state)

    {storage_id, entry} =
      storage
      |> Storage.get_record(id)

    new_storage =
      if entry do
        case Passme.Chat.archive_record(entry) do
          {:ok, entry} ->
            # Because user can't delete entry, only set flag "archived"
            Bot.msg(state.chat_id, "Record deleted")
            Storage.update(storage, storage_id, entry)

          {:error, changeset} ->
            Bot.msg(state.chat_id, "Error on deleting record")
            debug(changeset)
            storage
        end
      else
        raise "Record doesn't exists in chat storage!"
        storage
      end

    {:noreply, Map.put(state, :storage, new_storage), @expiry_idle_timeout}
  end

  def handle_cast({:script, {:new_record, user, chat}}, state) do
    {
      :noreply,
      Map.put(
        state,
        :script,
        Script.start_script(
          Passme.Chat.Script.NewRecord,
          user,
          chat,
          %Record{}
        )
      ),
      @expiry_idle_timeout
    }
  end

  @spec handle_cast(
          {:record, {:create, Record.t(), map() | nil}},
          State.t()
        ) :: {:noreply, State.t(), non_neg_integer()}
  def handle_cast({:record, {:create, record, user}}, state) do
    record =
      case user do
        nil -> record
        _ -> Map.put(record, :author, user.id)
      end
      |> Map.put(:chat_id, state.chat_id)

    storage =
      record
      |> Passme.Chat.create_chat_record()
      |> case do
        {:ok, entry} ->
          send_record_added(user, entry, state.chat_id)

          State.get_storage(state)
          |> Passme.Chat.Storage.put_record(entry)

        {:error, _changeset} ->
          Bot.msg(user, "Error while adding new record")
          State.get_storage(state)
      end

    {:noreply, Map.put(state, :storage, storage), @expiry_idle_timeout}
  end

  def handle_cast({:script, {:edit_record, _, _, _, _}}, %{script: script} = state)
      when not is_nil(script) do
    Bot.msg(state.chat_id, "Currently working another script")
    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:script, {:edit_record, record_id, field, user, chat}}, state) do
    script =
      Passme.Chat.chat_record_not_archived(record_id, chat.id)
      |> case do
        nil ->
          Bot.msg(chat.id, "Record doesn't exists")
          nil

        record ->
          with true <- Record.has_field?(field),
               true <- State.user_in_chat?(record.chat_id, user.id) do
            # Check here user can edit this record

            Script.start_script(
              RecordFieldEdit,
              user,
              chat,
              RecordFieldEdit.initial_data(record, field)
            )
          else
            _ ->
              Bot.msg(state.chat_id, "Not allowed to edit this record")
              |> Bot.private_chat_requested(chat.id, user)

              nil
          end
      end

    {:noreply, Map.put(state, :script, script), @expiry_idle_timeout}
  end

  def handle_cast({:record_action, {:delete, record_id}, context}, state) do
    user = context.from
    chat = context.message.chat

    Passme.Chat.chat_record_not_archived(record_id, chat.id)
    |> case do
      nil ->
        Bot.msg(chat.id, "Record doesn't exists")

      record ->
        # Check here user can edit this record
        with chat_state <- state(record.chat_id),
             true <- State.user_in_chat?(chat_state, user.id),
             {_, record} <-
               chat_state
               |> State.get_storage()
               |> Storage.get_record(record_id) do
          archive_record(record.chat_id, record.id)
        else
          _ -> Bot.msg(state.chat_id, "Not allowed to delete this record")
        end
    end

    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:record_action, {:getperm, record_id}, context}, state) do
    user = context.from

    record = Passme.Chat.record(record_id)
    author_id = record.author

    if record do
      spawn(fn ->
        case Passme.Chat.Permissions.record_permission(record, user.id) do
          :allowed ->
            {text, opts} = Passme.Chat.Interface.record(record)
            Bot.msg(user.id, text, opts)

          :pending ->
            {text, opts} = Passme.Chat.Interface.record_perm_pending()
            Bot.msg(user.id, text, opts)

          :private ->
            {:ok, %{id: perm_id}} = Passme.Chat.Permissions.request_permission(record, user.id)
            {text, opts} = Passme.Chat.Interface.record_getperm_request(user, record, perm_id)
            Bot.msg(author_id, text, opts)
        end
      end)
    else
      Bot.msg(user.id, "Record not found")
    end

    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:record_action, {:allow, permission_id}, context}, state) do
    user = context.from

    request = Permissions.request(permission_id)

    case request do
      nil ->
        Bot.msg(user.id, "Undefined action")

      %Request{end_time: nil} ->
        record = Passme.Chat.record(request.record_id)

        Request.update(request, %{
          end_time: DateTime.utc_now()
        })

        # Check ^ is success and sent 3 messages.
        # To author - record is permitted
        {text, opts} = Passme.Chat.Interface.record_permitted_admin()
        Bot.msg(user.id, text, opts)

        # To user - record is permitted
        {text, opts} = Passme.Chat.Interface.record_permitted_requisting(request.user_id, record)
        Bot.msg(request.user_id, text, opts)

        # To user - record in detail
        print_record(request.user_id, record.id)

      %Request{} ->
        Bot.msg(user.id, "Permission is not valid")
    end

    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast({:record_action, _action, _context}, state) do
    Bot.msg(state.chat_id, "Action is not defined")
    {:noreply, state, @expiry_idle_timeout}
  end

  def handle_cast(:list, state) do
    message =
      state
      |> State.get_storage()
      |> Storage.active_entries()
      |> Passme.Chat.Interface.list()

    Bot.msg(state.chat_id, message)
    {:noreply, state, @expiry_idle_timeout}
  end

  # Enter if awaiter (script) is not null
  def handle_cast({:action, {:input, _}}, %{script: nil} = state) do
    {:noreply, state}
  end

  def handle_cast({:action, {:input, text}}, %{script: script} = state) do
    new_state =
      case Script.set_step_result(script, text) do
        {:ok, script} ->
          script =
            script
            |> Script.next_step()
            |> Script.start_step()

          if Script.end?(script) do
            script
            |> Script.end_script()

            State.script_flush(state)
          else
            Map.put(state, :script, script)
          end

        {:error, message, value} ->
          Bot.msg(state.chat_id, message <> "\nYour value is: #{value}")
          state
      end

    {:noreply, new_state, @expiry_idle_timeout}
  end

  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  def handle_info(:script_input_timeout, state) do
    Bot.msg(state.chat_id, "Input timeout. Action was cancelled.")
    {:noreply, State.script_flush(state)}
  end

  #######

  @spec get_chat_process(integer()) :: pid()
  defp get_chat_process(chat_id) do
    Passme.Chat.Supervisor.get_chat_process(chat_id)
  end

  defp send_record_added(user, entry, chat_id) do
    if user do
      %{id: user_id, username: name} = user
      {text, opts} = Passme.Chat.Interface.record_link(entry)

      Bot.msg(
        user_id,
        "Record\n#{entry.name} => #{text}\nwas added ✅",
        opts
      )

      if chat_id !== user_id do
        Bot.msg(
          chat_id,
          "Record\n#{entry.name} => #{text}\nwas added by user @#{name}",
          opts
        )
      end
    end

    :ok
  end
end
