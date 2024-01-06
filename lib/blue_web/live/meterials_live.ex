defmodule BlueWeb.MaterialsLive do
  alias Blue.Blueprint
  alias Blue.Building
  alias Blue.Element
  alias Blue.Original
  require Logger
  use BlueWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex gap-4">
      <div>
        <h1><%= @blueprint["friendlyname"] %></h1>
        <%= for mat <- @materials do %>
          <.material_picker build_mat={mat} replacements={@replacements} />
        <% end %>
      </div>
      <div>
        <h2>Replacements</h2>
        <h3>New name</h3>
        <form phx-change="change_name">
          <.input type="text" name="new_name" value={@new_name} phx-debounce={300} />
        </form>

        <pre><%= inspect(@replacements, pretty: true) %></pre>
      </div>
    </div>
    """
  end

  @element_options Enum.map(Element.list_all(), fn %{hash: hash, name: name} -> {name, hash} end)

  defp element_options, do: @element_options

  defp material_picker(assigns) do
    ~H"""
    <div class="border border-blue-200 rounded my-2 p-2">
      <h2><%= @build_mat.building_name %></h2>

      <%= for hash <- @build_mat.selected_elements do %>
        <% chosen_hash =
          get_replacement(@replacements, @build_mat.buildingdef, @build_mat.selected_elements, hash) %>

        <div class={["flex gap-2 p-2 items-center", changed_mat_class(chosen_hash != hash)]}>
          <span>Replace</span>
          <strong><%= Element.find!(hash).name %></strong>
          <span>with</span>
          <form
            phx-change="select_replacement"
            phx-value-replaced_hash={hash}
            phx-value-original_elements={Jason.encode!(@build_mat.selected_elements)}
            phx-value-buildingdef={@build_mat.buildingdef}
          >
            <.input
              type="select"
              name="replacement_hash"
              options={element_options()}
              value={chosen_hash}
            />
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  defp changed_mat_class(true), do: "bg-yellow-100"
  defp changed_mat_class(_), do: nil

  def mount(_params, _session, socket) do
    {:ok, blueprint} = Original.by_name("terrasieve")
    materials = prepare_mats(blueprint)

    replacements = %{
      {"Door", [-1_736_594_426], -1_736_594_426} => 1_608_833_498
    }

    new_name = blueprint["friendlyname"]

    {:ok,
     assign(socket,
       blueprint: blueprint,
       materials: materials,
       replacements: replacements,
       new_name: new_name
     )}
  end

  def handle_event("select_replacement", params, socket) do
    case select_replacement(socket.assigns.replacements, params) do
      {:ok, replacements} ->
        socket = assign(socket, replacements: replacements)
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Invalid replacement")}
    end
  end

  def handle_event("change_name", %{"new_name" => new_name}, socket) do
    {:noreply, assign(socket, new_name: new_name)}
  end

  defp select_replacement(replacements, params) do
    with %{
           "buildingdef" => buildingdef,
           "original_elements" => selected_elements_json,
           "replaced_hash" => replaced_hash_str,
           "replacement_hash" => replacement_hash_str
         } <- params,
         {:ok, selected_elements_hashs} <- Jason.decode(selected_elements_json),
         true <- Enum.all?(selected_elements_hashs, &is_integer/1),
         true <- Enum.all?(selected_elements_hashs, &match?({:ok, _}, Element.find(&1))),
         {:ok, _} <- Building.by_id(buildingdef),
         {replacement_hash, ""} <- Integer.parse(replacement_hash_str),
         {replaced_hash, ""} <- Integer.parse(replaced_hash_str),
         {:ok, _} <- Building.by_id(buildingdef) do
      binding() |> IO.inspect(label: ~S/binding()/)

      {:ok,
       put_replacement(
         replacements,
         buildingdef,
         selected_elements_hashs,
         replaced_hash,
         replacement_hash
       )}
    else
      other ->
        Logger.error("Invalid replacement params #{inspect(other)}, params: #{inspect(params)}")
        {:error, :invalid_params}
    end
  end

  defp prepare_mats(blueprint) do
    Blueprint.distinct_materials(blueprint)
    |> Enum.map(fn %{"buildingdef" => bid, "selected_elements" => hashs} ->
      %{
        building_name: Building.name_of!(bid),
        buildingdef: bid,
        selected_elements: hashs
      }
    end)
  end

  defp get_replacement(replacements, buildingdef, selected_elements, element_hash) do
    key = {buildingdef, selected_elements, element_hash}

    case Map.fetch(replacements, key) do
      {:ok, replacement} -> replacement
      :error -> element_hash
    end
  end

  defp put_replacement(replacements, buildingdef, selected_elements, element_hash, replace_by) do
    key = {buildingdef, selected_elements, element_hash}
    Map.put(replacements, key, replace_by)
  end
end
