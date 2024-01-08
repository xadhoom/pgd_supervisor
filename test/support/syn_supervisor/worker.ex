defmodule SynSupervisor.Test.Support.Worker do
  @moduledoc false
  use GenServer

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args)
  end

  def child_spec(init_arg) do
    default = %{
      id: {__MODULE__, init_arg},
      start: {__MODULE__, :start_link, [init_arg]}
    }

    Supervisor.child_spec(default, [])
  end

  @impl true
  def init(init_args) do
    {:ok, init_args}
  end
end
