defmodule TestApp.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {PgdSupervisor, name: TestApp.DistributedSupervisor, scope: :test}
    ]

    opts = [strategy: :one_for_one, name: TestApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
