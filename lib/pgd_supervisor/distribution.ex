defmodule PgdSupervisor.Distribution do
  @moduledoc """
  Module to store and retrieve PgdSupervisor's distribution information
  """

  alias PgdSupervisor.Distribution.Child

  @type scope_t() :: atom()

  @type group_t() :: any()

  @type child_mapper_t :: (Child.t() -> any())

  @spec start_link(scope_t()) :: {:ok, pid()} | {:error, reason :: term()}
  def start_link(scope) do
    :pg.start_link(scope)
  end

  @spec start_link_and_join(scope_t()) :: {:ok, pid()} | {:error, reason :: term()}
  def start_link_and_join(scope) do
    case start_link(scope) do
      {:ok, pid} ->
        :pg.join(scope, member_group(Node.self()), self())
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        :pg.join(scope, member_group(Node.self()), self())
        {:ok, pid}

      err ->
        err
    end
  end

  @spec child_join(scope_t(), Node.t(), pid(), pid(), Child.spec_t()) :: :ok
  def child_join(scope, node, supervisor, child_pid, child_spec) do
    child = %Child{
      node: node,
      pid: child_pid,
      spec: child_spec,
      supervisor_pid: supervisor
    }

    :pg.join(scope, child_group(child), child_pid)
    track_spec(scope, child_spec)
  end

  @spec find_child(scope_t(), pid()) :: {:ok, Child.t()} | {:error, :not_found}
  def find_child(scope, pid) do
    scope
    |> child_groups()
    |> Enum.find_value(
      {:error, :not_found},
      fn
        {:child, %Child{pid: ^pid} = c} ->
          c

        _ ->
          false
      end
    )
  end

  @spec map_children(scope_t(), (Child.t() -> arg)) :: list(arg) when arg: any
  def map_children(scope, child_mapper_fun) do
    scope
    |> child_groups()
    |> Enum.map(fn {:child, child} -> child_mapper_fun.(child) end)
  end

  @spec each_child(scope_t(), (Child.t() -> any())) :: :ok
  def each_child(scope, fun) do
    scope
    |> child_groups()
    |> Enum.each(fn {:child, child} -> fun.(child) end)
  end

  @spec reduce_child(scope_t(), acc, (Child.t(), acc -> acc)) :: acc when acc: any()
  def reduce_child(scope, acc, fun) do
    scope
    |> child_groups()
    |> Enum.reduce(acc, fn {:child, child}, acc -> fun.(child, acc) end)
  end

  @spec node_for_child(scope_t(), Child.spec_t()) :: Node.t()
  def node_for_child(scope, child_spec) do
    scope
    |> create_ring()
    |> HashRing.key_to_node(child_spec)
  end

  @spec member_for_node(scope_t(), Node.t()) :: nil | pid()
  def member_for_node(scope, node) do
    case :pg.get_members(scope, member_group(node)) do
      [member | _] -> member
      _ -> nil
    end
  end

  @spec member_for_child(scope_t(), Child.spec_t()) :: {Node.t(), nil | pid()}
  def member_for_child(scope, child_spec) do
    node = node_for_child(scope, child_spec)
    {node, member_for_node(scope, node)}
  end

  @spec create_ring(scope_t()) :: HashRing.t()
  defp create_ring(scope) do
    groups = :pg.which_groups(scope)

    # build a consistent hash ring of existing nodes to distribute
    # child processes among them
    for {:member, node} <- groups, reduce: HashRing.new() do
      acc -> HashRing.add_node(acc, node)
    end
  end

  @spec track_spec(scope_t(), Child.spec_t()) :: :ok
  defp track_spec(scope, child_spec) do
    :pg.join(scope, spec_group(child_spec), supervisors(scope))
  end

  @spec supervisors(scope_t()) :: list(pid())
  defp supervisors(scope) do
    scope
    |> :pg.which_groups()
    |> Enum.filter(fn
      {:member, _} -> true
      _ -> false
    end)
    |> Enum.flat_map(&:pg.get_members(scope, &1))
    |> Enum.uniq()
  end

  defp child_groups(scope) do
    scope
    |> :pg.which_groups()
    |> Enum.filter(fn
      {:child, _child} -> true
      _ -> false
    end)
  end

  defp spec_group(child_spec) do
    {:spec, child_spec}
  end

  defp member_group(node) do
    {:member, node}
  end

  defp child_group(%Child{} = c) do
    {:child, c}
  end
end
