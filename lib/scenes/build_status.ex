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
    %CircleCI{
      repo_name: "ignite",
      project_name: "Ignite"
    },
    %CircleCI{
      repo_name: "eyetime_core",
      project_name: "Eyetime Core"
    },
    %CircleCI{
      repo_name: "higuruManagementPortal",
      project_name: "Higuru Management Portal"
    },
    %CircleCI{
      repo_name: "higuruServiceContainer",
      project_name: "Higuru Service Container"
    },
    %CircleCI{
      repo_name: "higuruAgentPortal",
      project_name: "Higuru Agent Portal"
    },
    %CircleCI{
      repo_name: "higuruAPI",
      project_name: "Higuru API"
    }
  ]

  @theme_color :dark
  @text_color :white

  # ============================================================================

  def init(_, opts) do
    # Get the viewport width
    {:ok, %ViewPort.Status{size: {width, _}}} =
      opts[:viewport]
      |> ViewPort.info()

    projects_with_index = Enum.with_index(@projects)
    project_scene_groups = Enum.map(projects_with_index, &create_project_scene_group(&1))

    initial_graph =
      Graph.build(font: :roboto, font_size: 24, theme: @theme_color)
      |> group(
        fn g ->
          g
          |> text("Build Status",
            font_size: 32,
            translate: {width / 2 - 60, 20},
            fill: @text_color
          )
          |> group(fn g ->
            g
            |> text("Repo", translate: {15, 60}, id: :event, fill: @text_color)
            # this button will cause the scene to crash.            
            |> text("Last build",
              translate: {310, 60},
              id: :event,
              fill: @text_color
            )
            |> text("Build duration",
              translate: {650, 60},
              id: :event,
              fill: @text_color
            )
            |> text("Committed by",
              translate: {850, 60},
              id: :event,
              fill: @text_color
            )
          end)
        end,
        translate: {0, @body_offset + 20}
      )

    graph =
      Enum.reduce(project_scene_groups, initial_graph, fn psg, acc ->
        apply(psg, [acc])
      end)

    # # Nav and Notes are added last so that they draw on top
    # |> Nav.add_to_graph(__MODULE__)
    # |> Notes.add_to_graph(@notes)

    push_graph(graph)
    Process.send_after(self(), :check_build_status, 1 * 1000)
    schedule_navigation_to_splash_screen()
    {:ok, %{graph: graph, viewport: opts[:viewport]}}
  end

  def create_project_scene_group({project_definition, index}) do
    &group(
      &1,
      fn g ->
        g
        |> text(project_definition.project_name,
          translate: {15, 60},
          id: :ignite_header,
          fill: @text_color
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
          fill: @text_color
        )
        |> text("",
          translate: {650, 60},
          id: :"#{project_definition.repo_name}_build_duration",
          fill: @text_color
        )
        |> text("",
          translate: {850, 60},
          id: :"#{project_definition.repo_name}_last_committer",
          fill: @text_color
        )
      end,
      translate: {0, @body_offset + 30 + 40 * (index + 1)}
    )
  end

  defp schedule_build_status_check() do
    Process.send_after(self(), :check_build_status, 10 * 1000)
  end

  def schedule_navigation_to_splash_screen() do
    Process.send_after(self(), :go_to_splash, 100_000)
  end

  def handle_info(:go_to_splash, %{viewport: vp} = state) do
    ViewPort.set_root(vp, {ScenicExampleApp.Scene.Splash, ScenicExampleApp.Scene.BuildStatus})
    {:noreply, state}
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
    ci_status = %{
      CI.get_build_status(project_definition)
      | project_definition: project_definition
    }
  end

  def filter_event({:update_project_status, ci_status}, _, %{graph: graph} = state) do
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
        :"#{ci_status.project_definition.repo_name}_build_duration",
        &text(&1, ci_status.last_build_duration)
      )
      |> Graph.modify(
        :"#{ci_status.project_definition.repo_name}_last_committer",
        &text(&1, ci_status.last_committer)
      )
      |> push_graph()

    {:stop, %{state | graph: graph}}
  end

  def status_to_color(status) do
    if status.status == :passing do
      :green
    else
      :red
    end
  end
end
