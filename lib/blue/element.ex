defmodule Blue.Element do
  alias NimbleCSV.RFC4180, as: CSV

  defstruct [:id, :name]

  @csv_path Path.join([:code.priv_dir(:blue), "data", "elements.csv"])
  @external_resource @csv_path

  @raw_data @csv_path
            |> File.stream!()
            |> CSV.parse_stream()
            |> Enum.map(fn [name, id] ->
              %{__struct__: __MODULE__, name: name, id: String.to_integer(id)}
            end)

  Enum.each(@raw_data, fn element ->
    %{name: name, id: id} = element

    def find(unquote(name)), do: find(unquote(id))
    def find(unquote(id)), do: {:ok, unquote(Macro.escape(element))}
  end)

  def find(what), do: {:error, {:unknown_element, what}}

  def id_of!(what) do
    {:ok, %{id: id}} = find(what)
    id
  end
end
