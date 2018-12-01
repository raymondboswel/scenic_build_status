defmodule ScenicExampleApp.Scene.BuildStatus do
  @moduledoc """
  Scene showing the build status of a predefined project
  """

  use Scenic.Scene
  alias Scenic.Graph
  alias Scenic.ViewPort
  import Scenic.Primitives
  import Scenic.Components

  alias ScenicExampleApp.Component.Nav
  alias ScenicExampleApp.Component.Notes

  @body_offset 60

  @notes """
    \"Components\" shows the basic components available in Scenic.
    Messages sent by the component are displayed live.
    The crash button raises an error, demonstrating how recovery works.
  """

  @event_str "Event received: "

  @projects [
    %ProjectDefinition{
      repo_name: "ignite",
      project_name: "Ignite",
      ci_server: :circle_ci
    },
    %ProjectDefinition{
      repo_name: "amnesia_api",
      project_name: "Amnesia api",
      ci_server: :travis_ci
    }
  ]

  # ============================================================================

  def init(_, opts) do
    # Get the viewport width
    {:ok, %ViewPort.Status{size: {width, _}}} =
      opts[:viewport]
      |> ViewPort.info()

    projects_with_index = Enum.with_index(@projects)
    project_scene_groups = Enum.map(projects_with_index, &create_project_scene_group(&1))

    initial_graph =
      Graph.build(font: :roboto, font_size: 24, theme: :light)
      |> group(
        fn g ->
          g
          |> text("Build Status", font_size: 32, translate: {width / 2 - 60, 20}, fill: :black)
          |> group(fn g ->
            g
            |> text("Repo", translate: {15, 60}, id: :event, fill: :black)
            # this button will cause the scene to crash.            
            |> text("Last build",
              translate: {310, 60},
              id: :event,
              fill: :black
            )
            |> text("Committed by",
              translate: {650, 60},
              id: :event,
              fill: :black
            )
          end)
        end,
        translate: {0, @body_offset + 20}
      )

    graph =
      Enum.reduce(project_scene_groups, initial_graph, fn psg, acc ->
        apply(psg, [acc])
      end)

      # Nav and Notes are added last so that they draw on top
      |> Nav.add_to_graph(__MODULE__)
      |> Notes.add_to_graph(@notes)

    push_graph(graph)
    schedule_build_status_check()
    {:ok, graph}
  end

  def create_project_scene_group({project_definition, index}) do
    &group(
      &1,
      fn g ->
        g
        |> text(project_definition.project_name,
          translate: {15, 60},
          id: :ignite_header,
          fill: :black
        )
        # this button will cause the scene to crash.
        |> circle(10,
          fill: :yellow,
          t: {280, 55},
          id: :"#{project_definition.repo_name}_status_led"
        )
        |> text("-",
          translate: {310, 60},
          id: :"#{project_definition.repo_name}_last_build_timestamp",
          fill: :black
        )
        |> text("",
          translate: {650, 60},
          id: :"#{project_definition.repo_name}_last_committer",
          fill: :black
        )
      end,
      translate: {0, @body_offset + 30 + 40 * (index + 1)}
    )
  end

  defp schedule_build_status_check() do
    # In 20 seconds
    Process.send_after(self(), :check_build_status, 10 * 1000)
  end

  def handle_info(:check_build_status, state) do
    Enum.each(@projects, fn project_definition ->
      s = get_project_status(project_definition)
      IO.inspect(s)
      Scenic.Scene.send_event(self, {:update_project_status, s})
    end)

    schedule_build_status_check()
    {:noreply, state}
  end

  def get_project_status(project_definition) do
    ci_definition =
      case project_definition.ci_server do
        :circle_ci ->
          access_token =
            Application.get_env(:scenic_example_app, :ci_config).circle_ci_access_token

          %CircleCI{
            repo_url:
              "https://circleci.com/api/v1.1/project/github/Fastcomm/#{
                project_definition.repo_name
              }/tree/master?circle-token=#{access_token}&limit=1"
          }

        :travis_ci ->
          %TravisCI{
            repo_url: "https://api.travis-ci.org/repos/raymondboswel/amnesia_api/builds"
          }
      end

    ci_status = %{CI.get_build_status(ci_definition) | project_definition: project_definition}
  end

  def get_ignite_status() do
    access_token = Application.get_env(:scenic_example_app, :ci_config).circle_ci_access_token

    CI.get_build_status(%CircleCI{
      repo_url:
        "https://circleci.com/api/v1.1/project/github/Fastcomm/ignite/tree/master?circle-token=#{
          access_token
        }&limit=1"
    })
  end

  def filter_event({:update_project_status, ci_status}, _, graph) do
    led_color = status_to_color(ci_status)

    graph =
      graph
      |> Graph.modify(
        :"#{ci_status.project_definition.repo_name}_status_led",
        &circle(&1, 10, fill: led_color)
      )
      |> Graph.modify(
        :"#{ci_status.project_definition.repo_name}_last_build_timestamp",
        &text(&1, ci_status.last_build_timestamp)
      )
      |> Graph.modify(
        :"#{ci_status.project_definition.repo_name}_last_committer",
        &text(&1, ci_status.last_committer)
      )
      |> push_graph()

    {:stop, graph}
  end

  def status_to_color(status) do
    if status.status == :passing do
      :green
    else
      :red
    end
  end

  # display the received message
  def filter_event(event, _, graph) do
    IO.inspect("Filter event: #{event}")

    graph =
      graph
      |> Graph.modify(:event, &text(&1, @event_str <> inspect(event)))
      |> push_graph()

    {:continue, event, graph}
  end
end
