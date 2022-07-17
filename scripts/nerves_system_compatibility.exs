#!/usr/bin/env elixir

#
# Write the Nerves System compatibility information to local `tmp` directory.
# The information is gathered from Nerves Project's Github repos.
# By default, the Github API only allows us 60 requests per hour.
# With an API token, we could get our rate limit bumped to 5000 requests an hour.
# See https://docs.github.com/en/rest/guides/getting-started-with-the-rest-api#authentication
#
# ## Usage
#
#   scripts/nerves_system_compatibility.exs
#
#   GITHUB_API_TOKEN=xxxxxx nerves_system_compatibility.exs
#

Mix.install([:req, :earmark])

defmodule NervesSystemCompatibility do
  @targets [:bbb, :rpi, :rpi0, :rpi2, :rpi3, :rpi3a, :rpi4, :osd32mp1, :x86_64, :grisp2]
  def targets, do: @targets

  def run do
    compatibility_data = NervesSystemCompatibility.Data.get()
    data_by_target = NervesSystemCompatibility.Data.group_data_by_target(compatibility_data)

    html =
      for target <- @targets do
        table_html =
          NervesSystemCompatibility.Table.build(
            target,
            Access.fetch!(data_by_target, target),
            NervesSystemCompatibility.Data.list_target_system_versions(compatibility_data, target)
          )
          |> to_string()
          |> Earmark.as_html!()

        "<details><summary>#{target}</summary>#{table_html}</details>"
        |> String.replace(~r/\s+/, " ")
        |> String.replace(~r/> </, "><")
        |> String.replace(~r/ style="text-align: left;"/, "")
      end
      |> Enum.join("\n")

    File.mkdir("tmp")
    file = "tmp/nerves_system_compatibility_#{DateTime.to_unix(DateTime.utc_now())}.html"
    IO.puts("writing the Nerves System compatibility information to #{file}")
    File.write!(file, html)
  end
end

defmodule NervesSystemCompatibility.API do
  @spec fetch_nerves_br_versions! :: [binary]
  def fetch_nerves_br_versions! do
    fetch_package_versions!("nerves_system_br", requirement: ">= 1.14.0")
  end

  @spec fetch_nerves_system_versions! :: keyword([binary])
  def fetch_nerves_system_versions! do
    NervesSystemCompatibility.targets()
    |> Task.async_stream(&{&1, fetch_nerves_system_versions!(&1)}, timeout: 10_000)
    |> Enum.reduce([], fn {:ok, kv}, acc -> [kv | acc] end)
  end

  @spec fetch_nerves_system_versions!(binary | atom) :: [binary]
  def fetch_nerves_system_versions!(target) do
    fetch_package_versions!("nerves_system_#{target}")
  end

  defp fetch_package_versions!(project_name, opts \\ []) do
    per_page = opts[:per_page] || 50
    requirement = opts[:requirement] || ">= 0.1.0"
    url = "https://api.github.com/repos/nerves-project/#{project_name}/tags?per_page=#{per_page}"

    %{status: 200, body: body} =
      if token = System.get_env("GITHUB_API_TOKEN") do
        Req.get!(url, headers: [Authorization: "token #{token}"], cache: true)
      else
        Req.get!(url, cache: true)
      end

    for %{"name" => "v" <> version} <- body, Version.match?(version, requirement) do
      version
    end
    |> Enum.sort(Version)
  end

  @spec fetch_buildroot_version!(binary) :: %{binary => binary}
  def fetch_buildroot_version!(nerves_br_version) do
    %{status: 200, body: body} =
      Req.get!(
        "https://raw.githubusercontent.com/nerves-project/nerves_system_br/v#{nerves_br_version}/create-build.sh",
        cache: true
      )

    Regex.named_captures(
      ~r/NERVES_BR_VERSION=(?<buildroot_version>[0-9.]*)/,
      body,
      include_captures: true
    )
    |> Enum.into(%{"nerves_br_version" => nerves_br_version})
  end

  @spec fetch_otp_version!(binary) :: %{binary => binary}
  def fetch_otp_version!(nerves_br_version) do
    %{status: 200, body: body} =
      Req.get!(
        "https://raw.githubusercontent.com/nerves-project/nerves_system_br/v#{nerves_br_version}/.tool-versions",
        cache: true
      )

    Regex.named_captures(
      ~r/erlang (?<otp_version>[0-9.]*)/,
      body,
      include_captures: true
    )
    |> Enum.into(%{"nerves_br_version" => nerves_br_version})
  end

  @spec fetch_nerves_br_version_for_target!(binary | atom, binary) :: %{binary => binary}
  def fetch_nerves_br_version_for_target!(target, target_version) do
    %{status: 200, body: body} =
      Req.get!(
        "https://raw.githubusercontent.com/nerves-project/nerves_system_#{target}/v#{target_version}/mix.lock",
        cache: true
      )

    Regex.named_captures(
      ~r/:hex, :nerves_system_br, "(?<nerves_br_version>[0-9.]*)"/,
      body,
      include_captures: true
    )
    |> Enum.into(%{"target" => target, "target_version" => target_version})
  end
end

defmodule NervesSystemCompatibility.Data do
  @type compatibility_data :: [%{binary => any}]

  @spec get :: compatibility_data
  def get do
    nerves_br_version_to_metadata_map =
      NervesSystemCompatibility.API.fetch_nerves_br_versions!()
      |> Task.async_stream(&{&1, nerves_br_version_to_metadata(&1)}, timeout: 10_000)
      |> Enum.reduce(%{}, fn {:ok, {nerves_br_version, nerves_br_metadata}}, acc ->
        Map.put(acc, nerves_br_version, nerves_br_metadata)
      end)

    NervesSystemCompatibility.API.fetch_nerves_system_versions!()
    |> Task.async_stream(
      fn {target, versions} ->
        build_target_metadata(target, versions, nerves_br_version_to_metadata_map)
      end,
      timeout: 10_000
    )
    |> Enum.reduce([], fn {:ok, target_metadata}, acc -> target_metadata ++ acc end)
  end

  defp build_target_metadata(target, target_versions, %{} = nerves_br_version_to_metadata_map) do
    for target_version <- target_versions, into: [] do
      nerves_br_version =
        NervesSystemCompatibility.API.fetch_nerves_br_version_for_target!(target, target_version)
        |> Access.fetch!("nerves_br_version")

      if metadata_map = nerves_br_version_to_metadata_map[nerves_br_version] do
        metadata_map
        |> Map.put("target", target)
        |> Map.put("target_version", target_version)
      else
        nil
      end
    end
    |> Enum.reject(&is_nil/1)
  end

  defp nerves_br_version_to_metadata(nerves_br_version) do
    [
      Task.async(NervesSystemCompatibility.API, :fetch_buildroot_version!, [nerves_br_version]),
      Task.async(NervesSystemCompatibility.API, :fetch_otp_version!, [nerves_br_version])
    ]
    |> Task.await_many(:timer.seconds(10))
    |> Enum.reduce(%{"nerves_br_version" => nerves_br_version}, fn %{} = data, acc ->
      Map.merge(acc, data)
    end)
  end

  @spec group_data_by_target(compatibility_data) :: %{binary => %{atom => any}}
  def group_data_by_target(compatibility_data) do
    compatibility_data
    |> Enum.group_by(&Map.fetch!(&1, "target"))
    |> Map.new(fn {target, target_entries} ->
      {
        target,
        target_entries
        |> Enum.reject(&String.match?(&1["target_version"], ~r/-rc/))
        |> Enum.group_by(&Map.fetch!(&1, "target_version"))
        |> Map.new(fn {target_version, target_version_entries} ->
          {
            target_version,
            target_version_entries
            |> Enum.max_by(&normalize_version(&1["target_version"]), Version)
          }
        end)
      }
    end)
  end

  @spec filter_by(compatibility_data, any, any) :: compatibility_data
  def filter_by(compatibility_data, key, value) do
    compatibility_data |> Enum.filter(&Kernel.==(&1[key], value))
  end

  @spec list_target_system_versions(compatibility_data, atom) :: [binary]
  def list_target_system_versions(compatibility_data, target) do
    compatibility_data
    |> filter_by("target", target)
    |> Enum.map(&Access.fetch!(&1, "target_version"))
    |> Enum.reject(&String.match?(&1, ~r/-rc/))
    |> Enum.uniq()
    |> Enum.sort({:desc, Version})
  end

  defp normalize_version(version) do
    case version |> String.split(".") |> Enum.count(&String.to_integer/1) do
      1 -> version <> ".0.0"
      2 -> version <> ".0"
      3 -> version
      _ -> raise("invalid version #{inspect(version)}")
    end
  end
end

defmodule NervesSystemCompatibility.Table do
  @spec build(atom, [%{binary => any}], [binary]) :: binary
  def build(target, data_by_system_version, system_versions) do
    column_names = build_column_names(target)

    [
      table_row(column_names),
      divider_row(length(column_names)),
      data_rows(data_by_system_version, system_versions)
    ]
    |> Enum.join("\n")
  end

  defp build_column_names(target) do
    ["nerves_system_#{target}", "Erlang/OTP", "nerves_system_br", "Buildroot"]
  end

  defp data_rows(data_by_system_version, system_versions) do
    for system_version <- system_versions do
      data_entry = Access.fetch!(data_by_system_version, system_version)

      [
        system_version,
        Access.fetch!(data_entry, "otp_version"),
        Access.fetch!(data_entry, "nerves_br_version"),
        Access.fetch!(data_entry, "buildroot_version")
      ]
      |> table_row()
    end
    |> Enum.join("\n")
  end

  defp table_row(values) when is_list(values) do
    ["|", Enum.intersperse(values, "|"), "|"] |> Enum.join()
  end

  defp divider_row(cell_count) when is_integer(cell_count) do
    ["|", List.duplicate("---", cell_count) |> Enum.intersperse("|"), "|"] |> Enum.join()
  end
end

NervesSystemCompatibility.run()
