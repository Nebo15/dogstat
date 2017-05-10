defmodule DogStatTest do
  use ExUnit.Case
  # doctest DogStat

  defmodule Server do
    def start(test, port) do
      {:ok, sock} = :gen_udp.open(port, [:binary, active: false])
      Task.start_link(fn ->
        recv(test, sock)
      end)
    end

    defp recv(test, sock) do
      send(test, {:server, recv(sock)})
      recv(test, sock)
    end

    defp recv(sock) do
      case :gen_udp.recv(sock, 0) do
        {:ok, {_, _, packet}} ->
          packet
        {:error, _} = error ->
          error
      end
    end
  end

  setup do
    {:ok, _} = Server.start(self(), 8125)
    DogStat.start_link([])
    :ok
  end

  test "sink" do
    DogStat.configure([sink: []])
    DogStat.increment("sample", 1, tags: ["foo", "bar"])
    DogStat.decrement("sample", 1, tags: ["foo", "bar"])

    assert [
      %{
        header: [_ | ""],
        key: "sample",
        options: [tags: ["foo", "bar"]],
        type: :counter,
        value: "-1"
      },
      %{
        header: [_ | ""],
        key: "sample",
        options: [tags: ["foo", "bar"]],
        type: :counter,
        value: "1"
      }
    ] = :sys.get_state(DogStat).sink

    refute_received _any
  end

  test "configure/1" do
    DogStat.configure([namespace: "test"])
    DogStat.increment("sample", 1, tags: ["foo", "bar"])
    assert_receive {:server, "test.sample:1|c|#foo,bar"}

    DogStat.configure([enabled?: false])
    DogStat.increment("sample", 1, tags: ["foo", "bar"])
    refute_received {:server, "test.sample:1|c|#foo,bar"}

    DogStat.configure([send_tags?: false])
    DogStat.increment("sample", 1, tags: ["foo", "bar"])
    assert_receive {:server, "sample:1|c"}

    refute_received _any
  end

  test "increment/1,2,3" do
    DogStat.increment("sample")
    assert_receive {:server, "sample:1|c"}

    DogStat.increment(["sample"], 2)
    assert_receive {:server, "sample:2|c"}

    DogStat.increment("sample", 2.1)
    assert_receive {:server, "sample:2.1|c"}

    DogStat.increment("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|c|#foo:bar,baz"}

    DogStat.increment("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|c|@1.0|#foo,bar"}

    DogStat.increment("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "decrement/1,2,3" do
    DogStat.decrement("sample")
    assert_receive {:server, "sample:-1|c"}

    DogStat.decrement(["sample"], 2)
    assert_receive {:server, "sample:-2|c"}

    DogStat.decrement("sample", 2.1)
    assert_receive {:server, "sample:-2.1|c"}

    DogStat.decrement("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:-3|c|#foo:bar,baz"}
    DogStat.decrement("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])

    assert_receive {:server, "sample:-3|c|@1.0|#foo,bar"}

    DogStat.decrement("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "gauge/2,3" do
    DogStat.gauge(["sample"], 2)
    assert_receive {:server, "sample:2|g"}

    DogStat.gauge("sample", 2.1)
    assert_receive {:server, "sample:2.1|g"}

    DogStat.gauge("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|g|#foo:bar,baz"}

    DogStat.gauge("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|g|@1.0|#foo,bar"}

    DogStat.gauge("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "histogram/2,3" do
    DogStat.histogram("sample", 2)
    assert_receive {:server, "sample:2|h"}

    DogStat.histogram("sample", 2.1)
    assert_receive {:server, "sample:2.1|h"}

    DogStat.histogram("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|h|#foo:bar,baz"}

    DogStat.histogram("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|h|@1.0|#foo,bar"}

    DogStat.histogram("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "timing/2,3" do
    DogStat.timing(["sample"], 2)
    assert_receive {:server, "sample:2|ms"}

    DogStat.timing("sample", 2.1)
    assert_receive {:server, "sample:2.1|ms"}

    DogStat.timing("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|ms|#foo:bar,baz"}

    DogStat.timing("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|ms|@1.0|#foo,bar"}

    DogStat.timing("sample", 3, sample_rate: 0.0)

    refute_received _any
  end

  test "measure/2,3" do
    expected = "the stuff"
    result = DogStat.measure(["sample"], fn ->
      :timer.sleep(100)
      expected
    end)
    assert_receive {:server, <<"sample:10", _, "|ms">>}
    assert result == expected

    DogStat.measure("sample", [sample_rate: 1.0, tags: ["foo", "bar"]], fn ->
      :timer.sleep(100)
    end)
    assert_receive {:server, <<"sample:10", _, "|ms|@1.0|#foo,bar">>}

    refute_received _any
  end

  test "set/2,3" do
    DogStat.set(["sample"], 2)
    assert_receive {:server, "sample:2|s"}

    DogStat.set("sample", 2.1)
    assert_receive {:server, "sample:2.1|s"}

    DogStat.set("sample", 3, tags: ["foo:bar", "baz"])
    assert_receive {:server, "sample:3|s|#foo:bar,baz"}

    DogStat.set("sample", 3, sample_rate: 1.0, tags: ["foo", "bar"])
    assert_receive {:server, "sample:3|s|@1.0|#foo,bar"}

    DogStat.set("sample", 3, sample_rate: 0.0)

    refute_received _any
  end
end
