defmodule DogStat do
  @moduledoc """
  This module provides helper functions to persist meaningful metrics to StatsD or DogstatsD servers.

  Code is based on [Statix](https://github.com/lexmag/statix) library.
  """
  use GenServer
  alias DogStat.Packet

  @type key :: iodata
  @type options :: [sample_rate: float, tags: [String.t]]
  @type on_send :: :ok | {:error, term}

  @doc """
  Starts a metric collector process.

  `opts` accepts connection arguments:
    * `enabled?` - enables or disables metrics reporting;
    * `host` - StatsD server host;
    * `port` - StatsD server port;
    * `namespace` - will be used as prefix to collected metrics;
    * `send_tags?` - allows to disable tags for StatsD servers that don't support them;
    * `sink` - if set to list, all metrics will be stored in a process state, useful for testing;
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  def init(opts) do
    {:ok, socket} = :gen_udp.open(0, [active: false])

    state =
      opts
      |> get_config()
      |> Map.put(:socket, socket)

    {:ok, state}
  end

  @doc """
  Changes DogStat configuration at run-time. Accepts `opts` is identical to a `start_link/1`.
  """
  def configure(opts) do
    GenServer.call(__MODULE__, {:configure, opts})
  end

  defp get_config(opts) do
    enabled? = Keyword.get(opts, :enabled?, true)
    host = opts |> Keyword.get(:host, "127.0.0.1") |> String.to_char_list()
    port = Keyword.get(opts, :port, 8125)
    sink = Keyword.get(opts, :sink, nil)
    send_tags? = Keyword.get(opts, :send_tags?, true)
    namespace = Keyword.get(opts, :namespace, nil)
    namespace = if namespace, do: [namespace, ?.], else: ""

    {:ok, address} = :inet.getaddr(host, :inet)
    header = Packet.header(address, port)

    %{
      enabled?: enabled?,
      send_tags?: send_tags?,
      header: [header | namespace],
      sink: sink
    }
  end

  @doc """
  Increments the StatsD counter identified by `key` by the given `value`.

  `value` is supposed to be zero or positive and `c:decrement/3` should be
  used for negative values.

  ## Examples

      iex> increment("hits", 1, [])
      :ok

  """
  @spec increment(key, value :: number, options) :: on_send
  def increment(key, val \\ 1, options \\ []) when is_number(val) do
    transmit(:counter, key, val, options)
  end

  @doc """
  Decrements the StatsD counter identified by `key` by the given `value`.

  Works same as `c:increment/3` but subtracts `value` instead of adding it. For
  this reason `value` should be zero or negative.

  ## Examples

      iex> decrement("open_connections", 1, [])
      :ok

  """
  @spec decrement(key, value :: number, options) :: on_send
  def decrement(key, val \\ 1, options \\ []) when is_number(val) do
    transmit(:counter, key, [?-, to_string(val)], options)
  end

  @doc """
  Writes to the StatsD gauge identified by `key`.

  ## Examples

      iex> gauge("cpu_usage", 0.83, [])
      :ok

  """
  @spec gauge(key, value :: String.Chars.t, options) :: on_send
  def gauge(key, val, options \\ []) do
    transmit(:gauge, key, val, options)
  end

  @doc """
  Writes `value` to the histogram identified by `key`.

  Not all StatsD-compatible servers support histograms. An example of a such
  server [statsite](https://github.com/statsite/statsite).

  ## Examples

      iex> histogram("online_users", 123, [])
      :ok

  """
  @spec histogram(key, value :: String.Chars.t, options) :: on_send
  def histogram(key, val, options \\ []) do
    transmit(:histogram, key, val, options)
  end

  @doc """
  Writes the given `value` to the StatsD timing identified by `key`.

  `value` is expected in milliseconds.

  ## Examples

      iex> timing("rendering", 12, [])
      :ok

  """
  @spec timing(key, value :: String.Chars.t, options) :: on_send
  def timing(key, val, options \\ []) do
    transmit(:timing, key, val, options)
  end

  @doc """
  Writes the given `value` to the StatsD set identified by `key`.

  ## Examples

      iex> set("unique_visitors", "user1", [])
      :ok

  """
  @spec set(key, value :: String.Chars.t, options) :: on_send
  def set(key, val, options \\ []) do
    transmit(:set, key, val, options)
  end

  @doc """
  Measures the execution time of the given `function` and writes that to the
  StatsD timing identified by `key`.

  This function returns the value returned by `function`, making it suitable for
  easily wrapping existing code.

  ## Examples

      iex> measure("integer_to_string", [], fn -> Integer.to_string(123) end)
      "123"

  """
  @spec measure(key, options, function :: (() -> result)) :: result when result: var
  def measure(key, options \\ [], fun) when is_function(fun, 0) do
    {elapsed, result} = :timer.tc(fun)

    timing(key, div(elapsed, 1000), options)

    result
  end


  @doc false
  def transmit(type, key, val, options) when (is_binary(key) or is_list(key)) and is_list(options) do
    sample_rate = Keyword.get(options, :sample_rate)

    if is_nil(sample_rate) or sample_rate >= :rand.uniform() do
      GenServer.cast(__MODULE__, {:transmit, type, key, to_string(val), options})
    end

    :ok
  end

  @doc false
  def handle_cast({:transmit, _type, _key, _value, _options}, %{enabled?: false} = state),
    do: {:noreply, state}

  # Transmits message to a sink
  @doc false
  def handle_cast({:transmit, type, key, value, options}, %{sink: sink} = state) when is_list(sink) do
    %{header: header} = state
    packet = %{type: type, key: key, value: value, options: options, header: header}
    {:noreply, %{state | sink: [packet | sink]}}
  end

  # Transmits message to a StatsD server
  @doc false
  def handle_cast({:transmit, type, key, value, options}, state) do
    %{header: header, socket: socket, send_tags?: send_tags?} = state

    packet = Packet.build(header, type, key, value, send_tags?, options)
    Port.command(socket, packet)

    receive do
      {:inet_reply, _port, status} -> status
    end

    {:noreply, state}
  end

  @doc false
  def handle_call({:configure, opts}, _from, state) do
    state = Map.merge(state, get_config(opts))
    {:reply, {:ok, state}, state}
  end
end
