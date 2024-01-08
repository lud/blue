defmodule Blue.Building do
  alias NimbleCSV.RFC4180, as: CSV

  defstruct [:id, :name]

  @csv_path Path.join([:code.priv_dir(:blue), "data", "buildings.csv"])
  @external_resource @csv_path

  @raw_data @csv_path
            |> File.stream!()
            |> CSV.parse_stream(skip_headers: false)
            |> Enum.map(fn [name, id, _dlc] ->
              %{__struct__: __MODULE__, name: name, id: id}
            end)

  Enum.each(@raw_data, fn building ->
    %{id: id} = building

    def by_id(unquote(id)), do: {:ok, unquote(Macro.escape(building))}
  end)

  def by_id(id), do: {:ok, %__MODULE__{name: id, id: id}}

  def name_of!(id) do
    {:ok, %{name: name}} = by_id(id)
    name
  end
end
