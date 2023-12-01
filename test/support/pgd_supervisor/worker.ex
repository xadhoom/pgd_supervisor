defmodule PgdSupervisor.Test.Support.Worker do
  @moduledoc false
  use GenServer

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args)
  end

  @impl true
  def init(init_args) do
    {:ok, init_args}
  end
end
