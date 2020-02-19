defmodule Passme.Chat.Registry do

  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @spec via_tuple(any) :: {:via, Registry, {Passme.Chat.Registry, any}}
  def via_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  def child_spec(_) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
 end
