defmodule TestApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {SynSupervisor, name: TestApp.DistributedSupervisor, scope: :test, sync_interval: 5}
    ]

    opts = [strategy: :one_for_one, name: TestApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
