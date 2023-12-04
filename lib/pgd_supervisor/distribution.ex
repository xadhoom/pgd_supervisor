defmodule PgdSupervisor.Distribution do
  @moduledoc """
  Module to store and retrieve PgdSupervisor's distribution information
  """

  @type scope_t() :: atom()

  @type group_t() :: any()

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

  @spec resource_join(scope_t(), Node.t(), pid(), pid()) :: :ok
  def resource_join(scope, node, supervisor, resource_pid) do
    :pg.join(scope, resource_group(node, supervisor), resource_pid)
  end

  @spec find_resource(scope_t(), pid()) :: {:ok, {Node.t(), pid()}} | {:error, :not_found}
  def find_resource(scope, pid) do
    scope
    |> resource_groups()
    |> Enum.find_value(
      {:error, :not_found},
      fn
        {:resource, {node, supervisor}} = group ->
          if pid in :pg.get_members(scope, group), do: {:ok, {node, supervisor}}

        _ ->
          false
      end
    )
  end

  defp resource_groups(scope) do
    scope
    |> :pg.which_groups()
    |> Enum.filter(fn
      {:resource, _node} -> true
      _ -> false
    end)
  end

  @spec node_for_resource(scope :: scope_t(), resource_id :: any()) :: Node.t()
  def node_for_resource(scope, resource_id) do
    scope
    |> create_ring()
    |> HashRing.key_to_node(resource_id)
  end

  @spec member_for_node(scope_t(), Node.t()) :: nil | pid()
  def member_for_node(scope, node) do
    case :pg.get_members(scope, member_group(node)) do
      [member | _] -> member
      _ -> nil
    end
  end

  @spec member_for_resource(scope :: scope_t(), resource_id :: any()) :: {Node.t(), nil | pid()}
  def member_for_resource(scope, resource_id) do
    node = node_for_resource(scope, resource_id)
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

  defp member_group(node) do
    {:member, node}
  end

  defp resource_group(node, supervisor) do
    {:resource, {node, supervisor}}
  end
end
