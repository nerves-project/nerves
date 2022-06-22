#!/usr/bin/env elixir

#
# Print the Nerves System compatibility information based on Nerves Project's
# Github repos. By default, the Github API only allows us 60 requests per hour.
# With an API token, we could get our rate limit bumped to 5000 requests an hour.
# See https://docs.github.com/en/rest/guides/getting-started-with-the-rest-api#authentication
#
# ## Usage
#
#   nerves_system_compatibility.exs
#
#   GITHUB_API_TOKEN=xxxxxx nerves_system_compatibility.exs
#

Mix.install([:req])

defmodule NervesSystemCompatibility do
  @doc """
  OTP versions that will be table rows.
  """
  @spec otp_versions :: [binary]
  def otp_versions do
    ~w[
      23.2.4
      23.2.7
      23.3.1
      24.0.2
      24.0.5
      24.1
      24.1.2
      24.1.4
      24.1.7
      24.2
      24.2.2
      24.3.2
      25.0
    ]
  end

  @doc """
  The Nerves System targets that are officially supported.
  """
  @spec target_systems :: [atom]
  def target_systems do
    ~w[
      bbb
      rpi
      rpi0
      rpi2
      rpi3
      rpi3a
      rpi4
      osd32mp1
      x86_64
      grisp2
    ]a
  end

  def run do
    NervesSystemCompatibility.Data.get()
    |> NervesSystemCompatibility.Table.build()
    |> IO.puts()
  end
end

defmodule NervesSystemCompatibility.API do
  @spec fetch_nerves_br_versions! :: [binary]
  def fetch_nerves_br_versions! do
    fetch_package_versions!("nerves_system_br", requirement: ">= 1.14.0")
  end

  @spec fetch_nerves_system_versions! :: keyword([binary])
  def fetch_nerves_system_versions! do
    NervesSystemCompatibility.target_systems()
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
  alias NervesSystemCompatibility.API

  @doc """
  Returns compatibility information for Nerves Systems.
  """
  @spec get :: [%{binary => any}]
  def get do
    nerves_br_version_to_metadata_map =
      API.fetch_nerves_br_versions!()
      |> Task.async_stream(&{&1, nerves_br_version_to_metadata(&1)}, timeout: 10_000)
      |> Enum.reduce(%{}, fn {:ok, {nerves_br_version, nerves_br_metadata}}, acc ->
        Map.put(acc, nerves_br_version, nerves_br_metadata)
      end)

    API.fetch_nerves_system_versions!()
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
        API.fetch_nerves_br_version_for_target!(target, target_version)
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
      Task.async(API, :fetch_buildroot_version!, [nerves_br_version]),
      Task.async(API, :fetch_otp_version!, [nerves_br_version])
    ]
    |> Task.await_many(:timer.seconds(10))
    |> Enum.reduce(%{"nerves_br_version" => nerves_br_version}, fn %{} = data, acc ->
      Map.merge(acc, data)
    end)
  end

  @doc """
  Groups the compatibility data by otp version and target.
  """
  @spec group_data_by_otp_and_target([%{binary => any}]) :: %{binary => %{atom => any}}
  def group_data_by_otp_and_target(compatibility_data) do
    compatibility_data
    |> Enum.group_by(&get_in(&1, ["otp_version"]))
    |> Map.new(fn {otp, otp_entries} ->
      {
        otp,
        otp_entries
        |> Enum.group_by(&get_in(&1, ["target"]))
        |> Map.new(fn {target, target_entries} ->
          {
            target,
            # Pick the latest available nerves system version.
            # Sometimes there are more than one available versions for the same OTP version.
            target_entries
            |> Enum.reject(fn %{"target_version" => target_version} ->
              String.match?(target_version, ~r/-rc/)
            end)
            |> Enum.max_by(
              fn %{"target_version" => target_version} ->
                normalize_version(target_version)
              end,
              Version
            )
          }
        end)
      }
    end)
  end

  @doc """
  Supplements missing minor and patch values so that the version can be compared.
  """
  def normalize_version(version) do
    case version |> String.split(".") |> Enum.count(&String.to_integer/1) do
      1 -> version <> ".0.0"
      2 -> version <> ".0"
      3 -> version
      _ -> raise("invalid version #{inspect(version)}")
    end
  end
end

defmodule NervesSystemCompatibility.Table do
  alias NervesSystemCompatibility.Data

  @doc """
  Converts the compatibility data to a markdown table.
  """
  @spec build([%{binary => any}]) :: binary
  def build(compatibility_data) do
    targets = NervesSystemCompatibility.target_systems()
    otp_versions = NervesSystemCompatibility.otp_versions()

    [
      header_row(targets),
      divider_row(targets),
      data_rows(targets, otp_versions, compatibility_data)
    ]
    |> Enum.join("\n")
  end

  defp header_row(targets) when is_list(targets) do
    [
      "|",
      [cell("", 12) | Enum.map(targets, &cell/1)] |> Enum.intersperse("|"),
      "|"
    ]
    |> Enum.join()
  end

  defp divider_row(targets) when is_list(targets) do
    [
      "|",
      [cell("---", 12) | List.duplicate(cell("---"), length(targets))] |> Enum.intersperse("|"),
      "|"
    ]
    |> Enum.join()
  end

  defp data_rows(targets, otp_versions, compatibility_data) do
    grouped_by_otp_and_target = compatibility_data |> Data.group_data_by_otp_and_target()

    for otp_version <- otp_versions, reduce: [] do
      acc ->
        target_versions =
          for target <- targets do
            get_in(grouped_by_otp_and_target, [otp_version, target, "target_version"])
          end

        [data_row(otp_version, target_versions) | acc]
    end
    |> Enum.join("\n")
  end

  defp data_row(otp_version, row_values) when is_list(row_values) do
    [
      "|",
      [cell("OTP #{otp_version}", 12) | Enum.map(row_values, &cell/1)] |> Enum.intersperse("|"),
      "|"
    ]
    |> Enum.join()
  end

  defp cell(value, count \\ 10) do
    (" " <> to_string(value)) |> String.pad_trailing(count)
  end
end

NervesSystemCompatibility.run()
