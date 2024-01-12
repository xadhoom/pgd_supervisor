defmodule SynSupervisor.Distribution.Child do
  @moduledoc """
  Distributed child structure
  """

  @type id_t :: any()
  @type spec_t :: any()

  @type t :: %__MODULE__{
          id: id_t(),
          pid: pid(),
          node: Node.t(),
          supervisor_pid: pid(),
          spec: spec_t()
        }

  @enforce_keys [:id, :pid, :node, :supervisor_pid, :spec]
  defstruct [:id, :pid, :node, :supervisor_pid, :spec]
end
