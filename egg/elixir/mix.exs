defmodule EggRunner.MixProject do
  use Mix.Project

  def project do
    [
      app: :egg_runner,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [extra_applications: [:logger, :crypto], mod: {Egg.Application, []}]
  end
end
