defmodule PgdSupervisor.Distribution.Child do
  @moduledoc """
  Distributed child structure
  """

  @type spec_t :: any()

  @type t :: %__MODULE__{
          pid: pid(),
          node: Node.t(),
          supervisor_pid: pid(),
          spec: spec_t()
        }

  @enforce_keys [:pid, :node, :supervisor_pid, :spec]
  defstruct [:pid, :node, :supervisor_pid, :spec]
end
