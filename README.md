# DogStat

[![Deps Status](https://beta.hexfaktor.org/badge/all/github/Nebo15/dogstat.svg)](https://beta.hexfaktor.org/github/Nebo15/dogstat) [![Hex.pm Downloads](https://img.shields.io/hexpm/dw/dogstat.svg?maxAge=3600)](https://hex.pm/packages/dogstat) [![Latest Version](https://img.shields.io/hexpm/v/dogstat.svg?maxAge=3600)](https://hex.pm/packages/dogstat) [![License](https://img.shields.io/hexpm/l/dogstat.svg?maxAge=3600)](https://hex.pm/packages/dogstat) [![Build Status](https://travis-ci.org/Nebo15/dogstat.svg?branch=master)](https://travis-ci.org/Nebo15/dogstat) [![Coverage Status](https://coveralls.io/repos/github/Nebo15/dogstat/badge.svg?branch=master)](https://coveralls.io/github/Nebo15/dogstat?branch=master) [![Ebert](https://ebertapp.io/github/Nebo15/dogstat.svg)](https://ebertapp.io/github/Nebo15/dogstat)

This package is based on [Statix](https://github.com/lexmag/statix) with one major difference - it receives settings when on GenServer init, allowing to use packages like [Confex](https://github.com/Nebo15/confex) to resolve configuration from environment at start-time.

## Installation

The package can be installed as:

  1. Add `dogstat` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:dogstat, "~> 0.1.0"}]
  end
  ```

  2. Ensure `dogstat` is started before your application:

  ```elixir
  def application do
    [applications: [:dogstat]]
  end
  ```

  3. Add it to your supervision tree:

  ```elixir
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    config = [
      host: "localhost",
      port: 8125
    ]

    children = [
      ...
      worker(Annon.Monitoring.MetricsCollector, [config]),
      ...
    ]

    opts = [strategy: :one_for_one, name: Annon.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```

## Docs

The docs can be found at [https://hexdocs.pm/dogstat](https://hexdocs.pm/dogstat)

## License

See [LICENSE.md](LICENSE.md).
