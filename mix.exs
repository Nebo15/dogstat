defmodule DogStat.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [app: :dogstat,
     description: "Runtime-configurable Elixir client for StatsD servers.",
     package: package(),
     version: @version,
     elixir: "~> 1.4 or ~> 1.3.2",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: [coveralls: :test],
     docs: [source_ref: "v#\{@version\}", main: "readme", extras: ["README.md"]]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: []]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:ex_doc, ">= 0.15.0", only: [:dev, :test]},
     {:excoveralls, ">= 0.5.0", only: [:dev, :test]},
     {:dogma, ">= 0.1.12", only: [:dev, :test]},
     {:credo, ">= 0.5.1", only: [:dev, :test]}]
  end

  # Settings for publishing in Hex package manager:
  defp package do
    [contributors: ["Nebo #15"],
     maintainers: ["Nebo #15"],
     licenses: ["MIT"],
     links: %{github: "https://github.com/Nebo15/dogstat"},
     files: ~w(lib LICENSE.md mix.exs README.md)]
  end
end
