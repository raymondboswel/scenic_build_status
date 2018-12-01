# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Configure the main viewport for the Scenic application
config :scenic_example_app, :viewport, %{
  name: :main_viewport,
  size: {1200, 1000},
  default_scene: {ScenicExampleApp.Scene.Splash, ScenicExampleApp.Scene.BuildStatus},
  drivers: [
    %{
      module: Scenic.Driver.Glfw,
      name: :glfw,
      opts: [resizeable: false, title: "scenic_example_app"]
    }
  ]
}

config :scenic_example_app, :ci_config, %{
  circle_ci_access_token: System.get_env("CIRCLE_CI_ACCESS_TOKEN")
}

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "prod.exs"
