#!/usr/bin/env elixir
# SPDX-FileCopyrightText: 2022 Masatoshi Nishiguchi
# SPDX-FileCopyrightText: 2023 Jon Carstens
# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
#
# Write the Nerves System compatibility information to local `tmp` directory.
# The information is gathered from Nerves Project's Github repos.
#
# ## Usage
#
#   # Generate markdown (default)
#   scripts/nerves_system_compatibility.exs
#
#   # Generate HTML
#   scripts/nerves_system_compatibility.exs --format html
#
#   # Generate HTML and update the charts in the documentation
#   scripts/nerves_system_compatibility.exs --format html --doc
#

Mix.install([:earmark])

defmodule NervesSystemCompatibility do
  alias NervesSystemCompatibility.Chart
  alias NervesSystemCompatibility.Database
  alias NervesSystemCompatibility.Repo

  @nerves_targets [:bbb, :rpi, :rpi0, :rpi0_2, :rpi2, :rpi3, :rpi3a, :rpi4, :rpi5, :osd32mp1, :x86_64, :grisp2, :mangopi_mq_pro]
  @systems_doc_divider "\n<!-- COMPATIBILITY -->\n"
  @systems_doc_path "./guides/advanced/systems.md"

  def nerves_targets, do: @nerves_targets

  def run do
    {parsed_opts, _} =
      OptionParser.parse!(System.argv(), strict: [format: :string, doc: :boolean])

    IO.puts(["options: ", inspect(parsed_opts)])

    format =
      case parsed_opts[:format] do
        nil -> :md
        format -> String.to_existing_atom(format)
      end

    should_update_doc = Keyword.get(parsed_opts, :doc, false)

    IO.puts("===> Downloading repos")
    Repo.download_nerves_system_repos()

    IO.puts("===> Building database")
    Database.init()
    Database.build()

    IO.puts("===> Building chart")
    {:ok, chart} = Chart.build(format: format)
    Repo.cleanup!()

    if should_update_doc do
      update_doc(chart.content)
      IO.puts("updated doc #{@systems_doc_path}")
    end

    IO.puts("done")
  end

  def update_doc(chart_content) do
    [keep_before, _replace, keep_after] =
      File.read!(@systems_doc_path)
      |> String.split(@systems_doc_divider)

    [keep_before, chart_content, keep_after]
    |> Enum.join(@systems_doc_divider)
    |> then(&File.write(@systems_doc_path, &1))
  end

  defmodule Chart do
    alias NervesSystemCompatibility.Database

    @chart_dir Path.join(System.tmp_dir!(), "nerves_system_compatibility")

    def build(opts \\ []) do
      chart_dir = opts[:chart_dir] || @chart_dir
      chart_format = opts[:format] || :md

      chart =
        for target <- NervesSystemCompatibility.nerves_targets() do
          build_chart_for_target(target, opts)
        end
        |> Enum.join("\n\n")

      File.mkdir_p(chart_dir)
      file = "#{chart_dir}/nerves_system_compatibility_#{System.os_time(:second)}.#{chart_format}"
      IO.puts(file)
      File.write!(file, chart)
      {:ok, %{file: file, content: chart}}
    end

    defp build_chart_for_target(target, opts) do
      column_labels = [target, "Erlang/OTP", "Nerves", "Nerves System BR", "Buildroot", "Linux"]
      header_rows = [table_row(column_labels), divider_row(length(column_labels))]

      data_rows =
        for version <- Database.get({target, :versions}) do
          data = get_data_for_target(target, version)

          values = [
            version,
            data.otp_version,
            data.nerves_version,
            data.nerves_system_br_version,
            data.buildroot_version,
            data.linux_version
          ]

          table_row(values)
        end

      markdown_chart = (header_rows ++ data_rows) |> Enum.join("\n")

      case opts[:format] do
        :html ->
          "<details><summary>nerves_system_#{target}</summary>#{markdown_chart_to_html(markdown_chart)}</details>"

        _ ->
          markdown_chart
      end
    end

    defp markdown_chart_to_html(markdown_chart) do
      markdown_chart
      |> Earmark.as_html!()
      |> String.replace(~r/ style="text-align: left;"/, "")
      |> String.replace(~r/>\s+/, ">")
      |> String.replace(~r/\s+</, "<")
    end

    defp get_data_for_target(target, version) do
      nerves_system_br_version = Database.get({target, version, :nerves_system_br_version})

      %{
        target: target,
        version: version,
        nerves_version: Database.get({target, version, :nerves_version}),
        nerves_system_br_version: nerves_system_br_version,
        linux_version: Database.get({target, version, :linux_version}),
        buildroot_version: Database.get({:br, nerves_system_br_version, :buildroot_version}),
        otp_version: Database.get({target, version, :otp_version})
      }
    end

    defp table_row(values) when is_list(values) do
      ["|", Enum.map(values, &pad_table_cell/1) |> Enum.intersperse("|"), "|"]
      |> Enum.join()
    end

    defp divider_row(cell_count) when is_integer(cell_count) do
      ["|", List.duplicate(pad_table_cell("---"), cell_count) |> Enum.intersperse("|"), "|"]
      |> Enum.join()
    end

    defp pad_table_cell(value), do: " #{value} "
  end

  defmodule Database do
    alias NervesSystemCompatibility.Repo

    def init, do: :ets.new(__MODULE__, [:set, :named_table])

    def get(key, default \\ nil) do
      case :ets.lookup(__MODULE__, key) do
        [] -> default
        [{_, value} | _rest] -> value
      end
    end

    def put(key, value), do: :ets.insert(__MODULE__, [{key, value}])

    def build do
      nerves_system_br_versions = Repo.get_nerves_system_br_versions()
      put({:br, :versions}, nerves_system_br_versions)

      for target <- NervesSystemCompatibility.nerves_targets() do
        versions = Repo.get_nerves_system_versions(target)
        put({target, :versions}, versions)

        for version <- versions do
          nerves_system_br_version = Repo.get_nerves_system_br_version_for_target(target, version)

          put(
            {target, version, :nerves_system_br_version},
            nerves_system_br_version
          )

          put(
            {target, version, :nerves_version},
            Repo.get_nerves_version_for_target(target, version)
          )

          put(
            {target, version, :linux_version},
            Repo.get_linux_version_for_target(target, version)
          )

          put(
            {target, version, :otp_version},
            Repo.get_otp_version_for_target(target, version, nerves_system_br_version)
          )

          IO.write(".")
        end
      end

      for nerves_system_br_version <- nerves_system_br_versions do
        put(
          {:br, nerves_system_br_version, :buildroot_version},
          Repo.get_buildroot_version(nerves_system_br_version)
        )

        put(
          {:br, nerves_system_br_version, :otp_version},
          Repo.get_otp_version(nerves_system_br_version)
        )

        IO.write(".")
      end

      IO.write("\n")
    end
  end

  defmodule Repo do
    @download_dir Path.join(System.tmp_dir!(), "nerves_system_compatibility/repos")
    @br_version_count 150
    @target_version_count 50

    def cleanup!(), do: File.rm_rf!(@download_dir)

    def download_nerves_system_repos do
      for target_or_br <- [:br | NervesSystemCompatibility.nerves_targets()] do
        Task.async(fn -> download_nerves_system_repo(target_or_br) end)
      end
      |> Task.await_many(:infinity)

      IO.write("\n")
    end

    def download_nerves_system_repo(target_or_br) do
      project_name = "nerves_system_#{target_or_br}"
      repo_dir = "#{@download_dir}/#{project_name}"

      if File.exists?(repo_dir) do
        System.shell("cd #{repo_dir} && git fetch origin")
      else
        File.mkdir_p(@download_dir)
        remote_repo_url = "https://github.com/nerves-project/#{project_name}.git"
        cmd = "cd #{@download_dir} && git clone #{remote_repo_url} > /dev/null 2>&1"
        IO.puts(cmd)
        {_, 0} = System.shell(cmd)
      end

      IO.write(".")
    end

    def get_nerves_system_br_versions do
      get_nerves_system_versions(:br, version_count: @br_version_count)
    end

    def get_nerves_system_target_versions(targets) when is_list(targets) do
      Enum.map(targets, &{&1, get_nerves_system_versions(&1)}) |> Enum.into(%{})
    end

    def get_nerves_system_versions(target_or_br, opts \\ []) when is_atom(target_or_br) do
      cd = "#{@download_dir}/nerves_system_#{target_or_br}"
      version_count = opts[:version_count] || @target_version_count

      case System.cmd("git", ["tag"], cd: cd) do
        {result, 0} ->
          result
          |> String.split("\n")
          |> Enum.filter(&String.match?(&1, ~r/\d*\.\d*\.\d*$/))
          |> Enum.map(&String.replace_leading(&1, "v", ""))
          |> Enum.sort({:desc, Version})
          |> Enum.take(version_count)

        _ ->
          nil
      end
    end

    def get_nerves_system_br_version_for_target(target, version) do
      cd = "#{@download_dir}/nerves_system_#{target}"

      cmd =
        "cd #{cd} && git checkout v#{version} > /dev/null 2>&1 && cat mix.lock"

      case System.shell(cmd) do
        {result, 0} ->
          captures =
            Regex.named_captures(
              ~r/"nerves_system_br".*:nerves_system_br, "(?<nerves_system_br_version>[0-9.]+)"/,
              result
            )

          if captures, do: captures["nerves_system_br_version"]

        _ ->
          nil
      end
    end

    def get_nerves_version_for_target(target, version) do
      cd = "#{@download_dir}/nerves_system_#{target}"
      cmd = "cd #{cd} && git checkout v#{version} > /dev/null 2>&1 && grep :nerves, mix.exs"

      case System.shell(cmd) do
        {result, 0} ->
          captures =
            Regex.named_captures(
              ~r/:nerves, "(?<nerves_version>.*)"/i,
              result
            )

          captures["nerves_version"]

        _ ->
          nil
      end
    end

    def get_buildroot_version(nerves_system_br_version)
        when is_binary(nerves_system_br_version) do
      cd = "#{@download_dir}/nerves_system_br"

      cmd =
        "cd #{cd} && git checkout v#{nerves_system_br_version} > /dev/null 2>&1 && grep NERVES_BR_VERSION create-build.sh 2>/dev/null"

      case System.shell(cmd) do
        {result, 0} ->
          captures =
            Regex.named_captures(
              ~r/NERVES_BR_VERSION=(?<buildroot_version>[0-9.]*)/,
              result
            )

          captures["buildroot_version"]

        _ ->
          nil
      end
    end

    def get_otp_version(nerves_system_br_version) do
      # Get the default OTP version from the patch file (the else clause)
      get_otp_version_from_patch_file(nerves_system_br_version)
    end

    def get_otp_version_from_patch_file(nerves_system_br_version) do
      cd = "#{@download_dir}/nerves_system_br"

      patch_cmd =
        "cd #{cd} && git checkout v#{nerves_system_br_version} > /dev/null 2>&1 && find patches/buildroot -name '*erlang-support-OTP*.patch' -exec cat {} \\; 2>/dev/null"

      case System.shell(patch_cmd) do
        {patch_content, 0} when patch_content != "" ->
          version_map = parse_erlang_versions_from_patch(patch_content)
          Map.get(version_map, :default)

        _ ->
          # Fallback to old method for older versions
          get_otp_version_from_patch_filename(nerves_system_br_version)
      end
    end

    defp parse_erlang_versions_from_patch(patch_content) do
      lines = String.split(patch_content, "\n")

      {version_map, _current_condition} =
        Enum.reduce(lines, {%{}, nil}, fn line, {map, current_condition} ->
          cond do
            # Match ifeq condition for specific OTP major version
            String.contains?(line, "ifeq") && String.contains?(line, "BR2_PACKAGE_ERLANG_") ->
              case Regex.named_captures(~r/BR2_PACKAGE_ERLANG_(?<major>\d+)/, line) do
                %{"major" => major} -> {map, String.to_integer(major)}
                _ -> {map, current_condition}
              end

            # Match ERLANG_VERSION line with a current condition (specific major version)
            String.contains?(line, "ERLANG_VERSION = ") && current_condition != nil ->
              case Regex.named_captures(~r/ERLANG_VERSION = (?<version>[\d.]+)/, line) do
                %{"version" => version} ->
                  {Map.put(map, current_condition, version), current_condition}

                _ ->
                  {map, current_condition}
              end

            # Match ERLANG_VERSION in else clause (no condition = default)
            String.contains?(line, "ERLANG_VERSION = ") && current_condition == nil ->
              case Regex.named_captures(~r/ERLANG_VERSION = (?<version>[\d.]+)/, line) do
                %{"version" => version} ->
                  {Map.put(map, :default, version), current_condition}

                _ ->
                  {map, current_condition}
              end

            # Reset condition on else
            String.contains?(line, "+else") ->
              {map, nil}

            true ->
              {map, current_condition}
          end
        end)

      version_map
    end

    def get_otp_version_for_target(target, version, nerves_system_br_version) do
      cd = "#{@download_dir}/nerves_system_#{target}"

      defconfig_cmd =
        "cd #{cd} && git checkout v#{version} > /dev/null 2>&1 && cat nerves_defconfig"

      case System.shell(defconfig_cmd) do
        {defconfig_content, 0} ->
          # Look for BR2_PACKAGE_ERLANG_XX=y in nerves_defconfig
          case Regex.named_captures(~r/BR2_PACKAGE_ERLANG_(?<major>\d+)=y/, defconfig_content) do
            %{"major" => major} ->
              # Get the version from the patch file for this major version
              get_otp_version_for_major(nerves_system_br_version, String.to_integer(major))

            _ ->
              # No specific version specified, use the default from patch file
              get_otp_version(nerves_system_br_version)
          end

        _ ->
          nil
      end
    end

    defp get_otp_version_for_major(nerves_system_br_version, major_version) do
      cd = "#{@download_dir}/nerves_system_br"

      patch_cmd =
        "cd #{cd} && git checkout v#{nerves_system_br_version} > /dev/null 2>&1 && find patches/buildroot -name '*erlang-support-OTP*.patch' -exec cat {} \\; 2>/dev/null"

      case System.shell(patch_cmd) do
        {patch_content, 0} when patch_content != "" ->
          version_map = parse_erlang_versions_from_patch(patch_content)
          Map.get(version_map, major_version) || Map.get(version_map, :default)

        _ ->
          nil
      end
    end

    def get_otp_version_from_patch_filename(nerves_system_br_version) do
      cd = "#{@download_dir}/nerves_system_br"

      cmd =
        "cd #{cd} && git checkout v#{nerves_system_br_version} > /dev/null 2>&1 && find . -name *.patch"

      case System.shell(cmd) do
        {result, 0} ->
          captures =
            Regex.named_captures(
              ~r/(erlang|otp).*-(?<otp_version>(\d+\.)?(\d+\.)?(\d+)).patch/i,
              result
            )

          captures["otp_version"]

        _ ->
          nil
      end
    end

    def get_linux_version_for_target(target, version) do
      cd = "#{@download_dir}/nerves_system_#{target}"
      cmd = "cd #{cd} && git checkout v#{version} > /dev/null 2>&1 && cat nerves_defconfig"

      case System.shell(cmd) do
        {result, 0} ->
          [
            Regex.named_captures(
              ~r/BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="(?<linux_version>(\d+\.)?(\d+\.)?(\*|\d+))"/i,
              result
            ),
            Regex.named_captures(
              ~r/linux-(?<linux_version>(\d+\.)?(\d+\.)?(\*|\d+))\.defconfig/i,
              result
            )
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.map(&Map.fetch!(&1, "linux_version"))
          |> Enum.sort_by(&normalize_version/1, {:desc, Version})
          |> List.first()

        _ ->
          nil
      end
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
end

NervesSystemCompatibility.run()
